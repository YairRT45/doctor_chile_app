import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/chili_classes.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/utils/carga_unica.dart';
import '../domain/diagnosis_classifier.dart';
import '../domain/prediction_result.dart';
import 'image_preprocessing.dart';
import 'inference_utils.dart';

export '../domain/prediction_result.dart';

/// Servicio encargado de cargar `assets/models/best.onnx` y ejecutar la
/// inferencia local (100% offline) sobre fotografías de hojas de chile.
class YoloService implements DiagnosisClassifier {
  static final YoloService instance = YoloService._();
  YoloService._() {
    _sesion = CargaUnica<OrtSession>(_crearSesion);
  }

  static const String _assetPath = 'assets/models/best.onnx';
  static const String _cachedFileName = 'best_chili_v4.onnx';
  static const String _versionModelo = 'best.onnx';

  final OnnxRuntime _ort = OnnxRuntime();

  /// La sesión se carga una sola vez aunque la pre-carga de Home y el primer
  /// análisis coincidan (M-06).
  late final CargaUnica<OrtSession> _sesion;

  Future<OrtSession> _crearSesion() async {
    try {
      // Nota crítica: `createSessionFromAsset` de `flutter_onnxruntime` guarda
      // `best.onnx` en `getTemporaryDirectory()` y NO lo sobrescribe al
      // actualizar el APK (`if (!wasCached)`), dejando en caché modelos viejos
      // (v1/v2/v3). Extraemos a un archivo con nombre de versión y limpiamos
      // el `best.onnx` antiguo de la caché.
      final tempDir = await getTemporaryDirectory();
      final legacyCached = File(
        '${tempDir.path}${Platform.pathSeparator}best.onnx',
      );
      if (await legacyCached.exists()) {
        try {
          await legacyCached.delete();
        } catch (_) {}
      }

      final modelFile = File(
        '${tempDir.path}${Platform.pathSeparator}$_cachedFileName',
      );
      if (!await modelFile.exists()) {
        final data = await rootBundle.load(_assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final tmpFile = File('${modelFile.path}.tmp');
        await tmpFile.writeAsBytes(bytes, flush: true);
        if (await modelFile.exists()) {
          await modelFile.delete();
        }
        await tmpFile.rename(modelFile.path);
      }

      return await _ort.createSession(modelFile.path);
    } catch (e) {
      throw ModeloNoDisponibleError(detalle: e.toString());
    }
  }

  /// Inicializa la sesión de ONNX Runtime cargando el archivo desde assets.
  @override
  Future<void> inicializar() async {
    await _sesion.obtener();
  }

  /// Analiza una fotografía local y devuelve el diagnóstico de YOLO11.
  @override
  Future<YoloPredictionResult> analizarImagen(String imagePath) async {
    final stopwatch = Stopwatch()..start();

    final session = await _sesion.obtener();

    // 1-3. Decodificar, orientar, recortar, redimensionar y construir el tensor
    // NCHW [1, 3, 224, 224] (más la defensa vegetal). Es trabajo pesado en Dart
    // puro: se ejecuta en un Isolate para no congelar la interfaz (M-05).
    final preprocesada = await preprocesarEnSegundoPlano(imagePath);
    final inputData = preprocesada.tensor;
    final proporcionVegetal = preprocesada.proporcionVegetal;

    // 4. Ejecutar inferencia en ONNX Runtime
    final inputName = session.inputNames.first;
    final inputTensor = await OrtValue.fromList(
      inputData,
      [1, 3, tamanoEntradaModelo, tamanoEntradaModelo],
    );

    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({inputName: inputTensor});
      final outputName = session.outputNames.first;
      final outputTensor = outputs[outputName]!;
      final rawList = await outputTensor.asFlattenedList();

      final rawScores = rawList.map((e) => (e as num).toDouble()).toList();
      final probs = normalizarProbabilidades(rawScores);

      // 5. Identificar la clase ganadora y validar defensas (proporción
      // vegetal y umbral de confianza). Lanza SalidaModeloInvalidaError si la
      // salida no coincide con las clases conocidas.
      final evaluacion = evaluarPrediccion(probs, proporcionVegetal);

      final mapaProbabilidades = <ChiliClassInfo, double>{
        for (int i = 0; i < ChiliClasses.todas.length; i++)
          ChiliClasses.todas[i]: probs[i],
      };

      stopwatch.stop();
      final claseGanadora = ChiliClasses.porIndice(evaluacion.indiceGanador);
      if (claseGanadora == null) {
        throw SalidaModeloInvalidaError(
          detalle: 'Índice de clase inexistente: ${evaluacion.indiceGanador}.',
        );
      }

      return YoloPredictionResult(
        claseGanadora: claseGanadora,
        confianza: evaluacion.confianza,
        probabilidadesPorClase: mapaProbabilidades,
        tiempoInferenciaMs: stopwatch.elapsedMilliseconds,
        estado: evaluacion.estado,
        mensajeAdvertencia: evaluacion.mensajeAdvertencia,
        versionModelo: _versionModelo,
      );
    } finally {
      await inputTensor.dispose();
      if (outputs != null) {
        for (final val in outputs.values) {
          await val.dispose();
        }
      }
    }
  }

  Future<void> cerrar() async {
    await _sesion.valor?.close();
    _sesion.reiniciar();
  }
}
