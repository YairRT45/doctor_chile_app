import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/constants/chili_classes.dart';
import '../../../core/database/local_database.dart';
import '../domain/diagnosis_record.dart';
import '../services/yolo_service.dart';

/// Pantalla de resultados de un diagnóstico recién analizado (CU-01 FN.5).
class ResultScreen extends StatefulWidget {
  final String imagePath;
  final YoloPredictionResult resultado;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.resultado,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TextEditingController _notasController = TextEditingController();
  bool _guardando = false;
  bool _yaGuardado = false;

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _guardarDiagnostico() async {
    if (_guardando || _yaGuardado) return;

    setState(() => _guardando = true);

    try {
      // 1. Copiar la foto a la carpeta permanente de la app
      final rutaPermanente = await LocalDatabase.instance.guardarImagenPermanente(
        widget.imagePath,
      );

      final clase = widget.resultado.claseGanadora;
      final registro = DiagnosisRecord(
        imagePath: rutaPermanente,
        diseaseKey: clase.key,
        diseaseName: clase.nombreEspanol,
        confidence: widget.resultado.confianza,
        createdAt: DateTime.now(),
        notes: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
      );

      // 2. Insertar en SQLite local validando BR-01 y BR-02
      final idGenerado = await LocalDatabase.instance.insertarDiagnostico(registro);

      if (!mounted) return;
      setState(() {
        _guardando = false;
        _yaGuardado = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF15803D),
          content: Text('Diagnóstico #$idGenerado guardado correctamente (Modo Offline).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Error al guardar el diagnóstico: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.resultado;
    final ganadora = res.claseGanadora;
    final porcentaje = (res.confianza * 100).toStringAsFixed(1);

    // Ordenar las 5 clases de mayor a menor probabilidad
    final desgloseOrdenado = res.probabilidadesPorClase.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del Diagnóstico'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Fotografía analizada
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Alerta si la imagen no parece hoja o tiene baja confianza
            if (!res.esConcluyente && res.mensajeAdvertencia != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade700, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        res.mensajeAdvertencia!,
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Tarjeta principal con el diagnóstico detectado
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ganadora.colorIndicador.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: ganadora.colorIndicador.withValues(alpha: 0.15),
                          child: Icon(
                            ganadora.icono,
                            color: ganadora.colorIndicador,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ganadora.esSana ? 'ESTADO SALUDABLE' : 'AFECCIÓN DETECTADA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: ganadora.colorIndicador,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ganadora.nombreEspanol,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ganadora.nombreCientificoOComun,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ChipMetrica(
                          etiqueta: 'Certeza del modelo',
                          valor: '$porcentaje%',
                          color: ganadora.colorIndicador,
                        ),
                        _ChipMetrica(
                          etiqueta: 'Tiempo de análisis',
                          valor: '${res.tiempoInferenciaMs} ms',
                          color: Colors.blueGrey.shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Síntomas identificados:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ganadora.descripcionSintomas,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Desglose de probabilidades de las 5 clases
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distribución de probabilidades (YOLO11-cls)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    for (final item in desgloseOrdenado) ...[
                      _BarraProbabilidadClase(
                        info: item.key,
                        probabilidad: item.value,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Notas opcionales y botón de guardado
            TextField(
              controller: _notasController,
              enabled: !_yaGuardado,
              decoration: InputDecoration(
                labelText: 'Nota o ubicación (opcional)',
                hintText: 'Ej. Parcela Norte, Surco 4...',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: _yaGuardado || _guardando ? null : _guardarDiagnostico,
              icon: Icon(_yaGuardado ? Icons.check_rounded : Icons.save_rounded),
              label: Text(
                _yaGuardado
                    ? 'Diagnóstico guardado en el historial'
                    : (_guardando ? 'Guardando...' : 'Guardar Diagnóstico'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Realizar otro diagnóstico'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipMetrica extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color color;

  const _ChipMetrica({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraProbabilidadClase extends StatelessWidget {
  final ChiliClassInfo info;
  final double probabilidad;

  const _BarraProbabilidadClase({
    required this.info,
    required this.probabilidad,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (probabilidad * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(info.nombreEspanol, style: const TextStyle(fontSize: 13)),
            Text(
              '$pct%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: probabilidad.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: info.colorIndicador,
          ),
        ),
      ],
    );
  }
}
