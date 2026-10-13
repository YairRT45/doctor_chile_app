import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/chili_classes.dart';
import '../services/yolo_service.dart';
import 'result_screen.dart';

/// Pantalla principal de la aplicación (CU-01: Hacer diagnóstico).
class HomeScreen extends StatefulWidget {
  final VoidCallback onAbrirHistorial;

  const HomeScreen({
    super.key,
    required this.onAbrirHistorial,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _analizando = false;

  @override
  void initState() {
    super.initState();
    // Pre-cargar el modelo ONNX en segundo plano al abrir la app
    YoloService.instance.inicializar().catchError((_) {});
  }

  /// Ejecuta el flujo normal (FN: Cámara) o alternativo (FA.1: Galería) de CU-01.
  Future<void> _capturarYAnalizar(ImageSource fuente) async {
    if (_analizando) return;

    try {
      final XFile? archivo = await _picker.pickImage(
        source: fuente,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 92,
      );

      if (archivo == null) return; // El agricultor canceló la captura

      setState(() => _analizando = true);

      // FN.4: El sistema analiza la imagen con YOLO11 On-Device
      final resultado = await YoloService.instance.analizarImagen(archivo.path);

      if (!mounted) return;
      setState(() => _analizando = false);

      // FN.5: El sistema regresa un diagnóstico
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath: archivo.path,
            resultado: resultado,
          ),
        ),
      );
    } catch (e) {
      // FE.1: Error interno durante el análisis de la imagen
      if (!mounted) return;
      setState(() => _analizando = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 10),
              Expanded(child: Text('Error al procesar la imagen')),
            ],
          ),
          content: Text(
            'Ocurrió un error al analizar la fotografía con el modelo local.\n\nDetalle: $e',
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
                        'Cultivos de Chile Guajillo / Mirasol (Capsicum annuum).\nFunciona 100% sin conexión a internet.',
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
                  'Afecciones que detecta el modelo (YOLO11):',
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
                          'Analizando hoja con YOLO11...',
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
