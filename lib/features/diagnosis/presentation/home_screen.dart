import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/chili_classes.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/widgets/descargo_responsabilidad.dart';
import '../domain/diagnosis_classifier.dart';
import '../services/yolo_service.dart';
import 'result_screen.dart';

/// Pantalla principal de la aplicación (CU-01: Hacer diagnóstico).
class HomeScreen extends StatefulWidget {
  final VoidCallback onAbrirHistorial;

  /// Clasificador de hojas. Por defecto el modelo ONNX real; se puede
  /// inyectar un doble en pruebas.
  final DiagnosisClassifier? clasificador;

  const HomeScreen({
    super.key,
    required this.onAbrirHistorial,
    this.clasificador,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _analizando = false;

  DiagnosisClassifier get _clasificador =>
      widget.clasificador ?? YoloService.instance;

  @override
  void initState() {
    super.initState();
    // Pre-cargar el modelo ONNX en segundo plano al abrir la app
    _clasificador.inicializar().catchError((Object e, StackTrace st) {
      registrarError(e, st, 'Pre-carga del modelo');
    });

    // En Android el sistema puede destruir la app mientras la cámara está
    // abierta (poca memoria). Al reiniciar, se recupera la foto pendiente.
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flujoDiagnostico(_recuperarCapturaPerdida);
      });
    }
  }

  /// Devuelve la ruta de una foto tomada antes de que la app se reiniciara, o
  /// `null` si no hay ninguna pendiente.
  Future<String?> _recuperarCapturaPerdida() async {
    final respuesta = await _picker.retrieveLostData();
    if (respuesta.isEmpty) return null;
    if (respuesta.exception != null) {
      registrarError(respuesta.exception!, null, 'Recuperación de captura perdida');
      return null;
    }
    final archivo = respuesta.files?.isNotEmpty == true
        ? respuesta.files!.first
        : respuesta.file;
    return archivo?.path;
  }

  /// Ejecuta el flujo normal (FN: Cámara) o alternativo (FA.1: Galería) de CU-01.
  Future<void> _capturarYAnalizar(ImageSource fuente) {
    return _flujoDiagnostico(() async {
      final XFile? archivo = await _picker.pickImage(
        source: fuente,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 92,
      );
      return archivo?.path; // null si el agricultor canceló la captura
    });
  }

  /// Obtiene una foto con [obtenerRuta], la analiza y muestra el resultado.
  Future<void> _flujoDiagnostico(Future<String?> Function() obtenerRuta) async {
    if (_analizando) return;

    try {
      final ruta = await obtenerRuta();
      if (ruta == null) return;
      if (!mounted) return;

      setState(() => _analizando = true);

      // FN.4: El sistema analiza la imagen con YOLO11 On-Device
      final resultado = await _clasificador.analizarImagen(ruta);

      if (!mounted) return;
      setState(() => _analizando = false);

      // FN.5: El sistema regresa un diagnóstico
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath: ruta,
            resultado: resultado,
            onVerHistorial: widget.onAbrirHistorial,
          ),
        ),
      );
    } catch (e, st) {
      // FE.1: Error interno durante el análisis de la imagen. El detalle
      // técnico va al log; al usuario se le muestra un mensaje comprensible.
      registrarError(e, st, 'Error al analizar la imagen');
      if (!mounted) return;
      setState(() => _analizando = false);

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 10),
              Expanded(child: Text('No se pudo analizar la imagen')),
            ],
          ),
          content: Text(
            mensajeAmigable(
              e,
              porDefecto:
                  'Ocurrió un problema al analizar la fotografía. Intente de nuevo con otra imagen.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Chile • Diagnóstico'),
        actions: [
          IconButton(
            tooltip: 'Revisar diagnósticos anteriores',
            onPressed: widget.onAbrirHistorial,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado informativo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF15803D), Color(0xFF166534)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.eco_rounded, color: Colors.white, size: 32),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Detección de Plagas y Enfermedades',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Cultivos de Chile Guajillo / Mirasol (Capsicum annuum).',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón Principal: Tomar Fotografía (CU-01 Flujo Normal)
                FilledButton.icon(
                  onPressed: _analizando
                      ? null
                      : () => _capturarYAnalizar(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 28),
                  label: const Text(
                    'Hacer Diagnóstico (Cámara)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Botón Secundario: Galería (CU-01 Flujo Alternativo FA.1)
                OutlinedButton.icon(
                  onPressed: _analizando
                      ? null
                      : () => _capturarYAnalizar(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 24),
                  label: const Text(
                    'Subir Foto desde Galería',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Botón de Historial (CU-02: Revisar diagnóstico)
                Card(
                  elevation: 0,
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade700,
                      child: const Icon(Icons.manage_search_rounded, color: Colors.white),
                    ),
                    title: const Text(
                      'Revisar Diagnósticos Anteriores',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Filtrar historial por afección o rango de fechas',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onAbrirHistorial,
                  ),
                ),
                const SizedBox(height: 24),

                // Guía rápida de captura y catálogo de clases soportadas
                const Text(
                  'Afecciones que puede identificar la aplicación:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                for (final clase in ChiliClasses.todas)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(clase.icono, color: clase.colorIndicador),
                      title: Text(
                        clase.nombreEspanol,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(clase.nombreCientificoOComun),
                    ),
                  ),
                const SizedBox(height: 8),
                const DescargoResponsabilidad(),
              ],
            ),
          ),

          // Indicador de carga durante el análisis (FN.4)
          if (_analizando)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Analizando la hoja...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
