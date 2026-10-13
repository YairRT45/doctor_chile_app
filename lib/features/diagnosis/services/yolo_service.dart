import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants/chili_classes.dart';

/// Resultado devuelto por el servicio de inferencia YOLO11.
class YoloPredictionResult {
  final ChiliClassInfo claseGanadora;
  final double confianza;
  final Map<ChiliClassInfo, double> probabilidadesPorClase;
  final int tiempoInferenciaMs;
  final bool esConcluyente;
  final String? mensajeAdvertencia;

  const YoloPredictionResult({
    required this.claseGanadora,
    required this.confianza,
    required this.probabilidadesPorClase,
    required this.tiempoInferenciaMs,
    required this.esConcluyente,
    this.mensajeAdvertencia,
  });
}

/// Servicio encargado de cargar `assets/models/best.onnx` y ejecutar la
/// inferencia local (100% offline) sobre fotografías de hojas de chile.
class YoloService {
  static final YoloService instance = YoloService._();
  YoloService._();

  static const String _assetPath = 'assets/models/best.onnx';
  static const int _inputSize = 224;
  static const double _umbralConfianzaMinima = 0.70; // 70% mínimo de certeza
  static const double _umbralVegetacionMinima = 0.12; // Al menos 12% de píxeles foliares

  final OnnxRuntime _ort = OnnxRuntime();
  OrtSession? _session;

  /// Inicializa la sesión de ONNX Runtime cargando el archivo desde assets.
  Future<void> inicializar() async {
    if (_session != null) return;
    _session = await _ort.createSessionFromAsset(_assetPath);
  }

  /// Analiza una fotografía local y devuelve el diagnóstico de YOLO11.
  Future<YoloPredictionResult> analizarImagen(String imagePath) async {
    final stopwatch = Stopwatch()..start();

    await inicializar();
    final session = _session!;

    // 1. Leer y decodificar la imagen desde el almacenamiento del dispositivo
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('FE.1: No fue posible decodificar el archivo de imagen.');
    }

    // Corregir orientación EXIF si la foto fue tomada con la cámara rotada
    final oriented = img.bakeOrientation(decoded);

    // 2. Recorte cuadrado central y redimensionado a 224x224 (como hace YOLO-cls)
    final resized = img.copyResizeCropSquare(
      oriented,
      size: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // 3. Crear el tensor de entrada NCHW [1, 3, 224, 224] en formato RGB (0.0 a 1.0)
    // y al mismo tiempo verificar si la imagen contiene tonos foliares (Defensa Vegetal)
    final planeSize = _inputSize * _inputSize;
    final inputData = Float32List(3 * planeSize);
    int pixelesVegetales = 0;

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final idx = y * _inputSize + x;
        inputData[idx] = r; // Canal R
        inputData[planeSize + idx] = g; // Canal G
        inputData[2 * planeSize + idx] = b; // Canal B

        if (_esPixelFoliar(r, g, b)) {
          pixelesVegetales++;
        }
      }
    }

    final proporcionVegetal = pixelesVegetales / planeSize;

    // 4. Ejecutar inferencia en ONNX Runtime
    final inputName = session.inputNames.first;
    final inputTensor = await OrtValue.fromList(
      inputData,
      [1, 3, _inputSize, _inputSize],
    );

    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({inputName: inputTensor});
      final outputName = session.outputNames.first;
      final outputTensor = outputs[outputName]!;
      final rawList = await outputTensor.asFlattenedList();

      final rawScores = rawList.map((e) => (e as num).toDouble()).toList();
      final probs = _normalizarProbabilidades(rawScores);

      // 5. Identificar la clase ganadora y construir el mapa de resultados
      int bestIdx = 0;
      double bestProb = probs[0];
      final mapaProbabilidades = <ChiliClassInfo, double>{};

      for (int i = 0; i < ChiliClasses.todas.length && i < probs.length; i++) {
        final info = ChiliClasses.porIndice(i);
        mapaProbabilidades[info] = probs[i];
        if (probs[i] > bestProb) {
          bestProb = probs[i];
          bestIdx = i;
        }
      }

      stopwatch.stop();
      final claseGanadora = ChiliClasses.porIndice(bestIdx);

      // 6. Validar defensas (proporción vegetal y umbral de confianza)
      String? advertencia;
      bool esConcluyente = true;

      if (proporcionVegetal < _umbralVegetacionMinima) {
        esConcluyente = false;
        advertencia =
            'La imagen no parece contener una hoja de chile (baja presencia de tonos foliares). Por favor acerque la cámara a la hoja.';
      } else if (bestProb < _umbralConfianzaMinima) {
        esConcluyente = false;
        advertencia =
            'El nivel de certeza (${(bestProb * 100).toStringAsFixed(1)}%) es bajo. Intente tomar la fotografía con mejor iluminación y enfocando una sola hoja.';
      }

      return YoloPredictionResult(
        claseGanadora: claseGanadora,
        confianza: bestProb,
        probabilidadesPorClase: mapaProbabilidades,
        tiempoInferenciaMs: stopwatch.elapsedMilliseconds,
        esConcluyente: esConcluyente,
        mensajeAdvertencia: advertencia,
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

  /// Verifica mediante espacio de color HSV si un píxel corresponde a tonos de
  /// hoja verde, hoja amarillenta (clorosis) o tejido foliar con manchas.
  bool _esPixelFoliar(double r, double g, double b) {
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final delta = maxC - minC;

    // Descartar blancos puros, grises o negros puros de fondo
    if (maxC < 0.12 || delta < 0.06) return false;

    final s = delta / maxC;
    if (s < 0.15) return false;

    double h = 0.0;
    if (maxC == r) {
      h = 60.0 * (((g - b) / delta) % 6.0);
    } else if (maxC == g) {
      h = 60.0 * (((b - r) / delta) + 2.0);
    } else {
      h = 60.0 * (((r - g) / delta) + 4.0);
    }
    if (h < 0) h += 360.0;

    // Rango de matiz (Hue) entre 28° (amarillo/café foliar) y 165° (verde hoja)
    return h >= 28.0 && h <= 165.0;
  }

  /// Asegura que el vector de salida sume 1.0 (si el modelo ya aplicó Softmax
  /// lo conserva; si devuelve logits crudos le aplica Softmax).
  List<double> _normalizarProbabilidades(List<double> scores) {
    final sum = scores.fold(0.0, (a, b) => a + b);
    final allPositive = scores.every((s) => s >= 0.0 && s <= 1.0001);
    if (allPositive && (sum - 1.0).abs() < 0.02) {
      return scores;
    }
    final maxScore = scores.reduce(math.max);
    final exps = scores.map((s) => math.exp(s - maxScore)).toList();
    final expSum = exps.fold(0.0, (a, b) => a + b);
    return exps.map((e) => e / expSum).toList();
  }

  Future<void> cerrar() async {
    await _session?.close();
    _session = null;
  }
}
