import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/constants/chili_classes.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/widgets/descargo_responsabilidad.dart';
import '../domain/diagnosis_record.dart';
import '../domain/diagnosis_repository.dart';
import '../domain/estado_resultado.dart';
import '../services/yolo_service.dart';

/// Pantalla de resultados de un diagnóstico recién analizado (CU-01 FN.5).
class ResultScreen extends StatefulWidget {
  final String imagePath;
  final YoloPredictionResult resultado;

  /// Repositorio de persistencia. Por defecto SQLite; se puede inyectar un
  /// doble en pruebas.
  final DiagnosisRepository? repositorio;

  /// Abre el historial. Si se proporciona, tras guardar aparece "Ver historial".
  final VoidCallback? onVerHistorial;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.resultado,
    this.repositorio,
    this.onVerHistorial,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TextEditingController _notasController = TextEditingController();
  bool _guardando = false;
  bool _yaGuardado = false;

  DiagnosisRepository get _repo => widget.repositorio ?? LocalDatabase.instance;

  /// Pide confirmación antes de descartar un resultado que no se ha guardado.
  Future<bool> _confirmarSalirSinGuardar() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir sin guardar'),
        content: const Text(
          'Este resultado aún no está guardado en el historial. '
          'Si sale ahora, se perderá.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir aquí'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  /// Un resultado que no es una hoja pide confirmación antes de guardarse para
  /// no llenar el historial con fotografías sin sentido.
  Future<bool> _confirmarGuardadoNoHoja() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar de todos modos'),
        content: const Text(
          'La imagen no parece contener una hoja de chile. Si la guarda, '
          'quedará marcada como "No parece una hoja" en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    return confirmar == true;
  }

  Future<void> _guardarDiagnostico() async {
    if (_guardando || _yaGuardado) return;

    if (widget.resultado.estado == EstadoResultado.noEsHoja) {
      if (!await _confirmarGuardadoNoHoja()) return;
      if (!mounted) return;
    }

    setState(() => _guardando = true);

    String? rutaCopiada;
    try {
      // 1. Copiar la foto a la carpeta permanente de la app
      rutaCopiada = await _repo.guardarImagenPermanente(
        widget.imagePath,
      );

      final clase = widget.resultado.claseGanadora;
      final registro = DiagnosisRecord(
        imagePath: rutaCopiada,
        diseaseKey: clase.key,
        diseaseName: clase.nombreEspanol,
        confidence: widget.resultado.confianza,
        createdAt: DateTime.now(),
        notes: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        estado: widget.resultado.estado,
        modelVersion: widget.resultado.versionModelo,
      );

      // 2. Insertar en SQLite local validando BR-01 y BR-02
      final idGenerado = await _repo.insertarDiagnostico(registro);

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
    } catch (e, st) {
      registrarError(e, st, 'Error al guardar el diagnóstico');
      // Si la foto ya se copió pero el registro no se guardó, no dejar la copia huérfana.
      if (rutaCopiada != null) {
        await _repo.descartarImagen(rutaCopiada);
      }
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            mensajeAmigable(
              e,
              porDefecto: 'No se pudo guardar el diagnóstico. Intente de nuevo.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.resultado;
    final ganadora = res.claseGanadora;
    final porcentaje = (res.confianza * 100).toStringAsFixed(1);
    final concluyente = res.esConcluyente;
    final noEsHoja = res.estado == EstadoResultado.noEsHoja;

    // Un resultado dudoso usa un color neutro: no debe parecer un diagnóstico firme.
    final colorTarjeta = concluyente ? ganadora.colorIndicador : Colors.blueGrey.shade600;

    // Ordenar las 5 clases de mayor a menor probabilidad
    final desgloseOrdenado = res.probabilidadesPorClase.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final String etiquetaSuperior;
    final String tituloPrincipal;
    switch (res.estado) {
      case EstadoResultado.concluyente:
        etiquetaSuperior = ganadora.esSana ? 'ESTADO SALUDABLE' : 'AFECCIÓN DETECTADA';
        tituloPrincipal = ganadora.nombreEspanol;
      case EstadoResultado.pocaConfianza:
        etiquetaSuperior = 'RESULTADO NO CONCLUYENTE';
        tituloPrincipal = 'Posible: ${ganadora.nombreEspanol}';
      case EstadoResultado.noEsHoja:
        etiquetaSuperior = 'NO PARECE UNA HOJA DE CHILE';
        tituloPrincipal = 'Sin diagnóstico fiable';
    }

    return PopScope(
      // Si ya se guardó se puede salir libremente; si no, se pide confirmación.
      canPop: _yaGuardado,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await _confirmarSalirSinGuardar();
        if (salir && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
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
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 64),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Alerta si la imagen no parece hoja o tiene baja confianza
            if (!concluyente && res.mensajeAdvertencia != null) ...[
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
              elevation: concluyente ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorTarjeta.withValues(alpha: 0.5), width: 1.5),
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
                          backgroundColor: colorTarjeta.withValues(alpha: 0.15),
                          child: Icon(
                            concluyente ? ganadora.icono : Icons.help_outline_rounded,
                            color: colorTarjeta,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                etiquetaSuperior,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: colorTarjeta,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tituloPrincipal,
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: concluyente ? null : Colors.blueGrey.shade800,
                                ),
                              ),
                              if (!noEsHoja)
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
                          etiqueta: concluyente ? 'Certeza del modelo' : 'Certeza (baja)',
                          valor: '$porcentaje%',
                          color: colorTarjeta,
                        ),
                        _ChipMetrica(
                          etiqueta: 'Tiempo de análisis',
                          valor: '${res.tiempoInferenciaMs} ms',
                          color: Colors.blueGrey.shade700,
                        ),
                      ],
                    ),
                    if (!noEsHoja) ...[
                      const SizedBox(height: 16),
                      Text(
                        concluyente
                            ? 'Síntomas identificados:'
                            : 'Síntomas de la posible afección:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ganadora.descripcionSintomas,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Desglose de probabilidades de las 5 clases (no se muestra si
            // la imagen no parece una hoja: serían cifras sin sentido)
            if (!noEsHoja) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Probabilidad por afección',
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
            ],

            const DescargoResponsabilidad(),
            const SizedBox(height: 16),

            // 5. Notas opcionales y botones de acción
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

            // Si el resultado no es concluyente, la acción principal es repetir
            // la foto y guardar pasa a ser secundaria (queda marcado en el historial).
            if (concluyente) ...[
              _botonGuardar(principal: true),
              const SizedBox(height: 8),
              _botonOtroDiagnostico(principal: false),
            ] else ...[
              _botonOtroDiagnostico(principal: true),
              const SizedBox(height: 8),
              _botonGuardar(principal: false),
            ],

            // Tras guardar, acceso directo al historial.
            if (_yaGuardado && widget.onVerHistorial != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onVerHistorial,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Ver historial'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _botonGuardar({required bool principal}) {
    final String texto;
    if (_yaGuardado) {
      texto = 'Diagnóstico guardado en el historial';
    } else if (_guardando) {
      texto = 'Guardando...';
    } else {
      texto = principal ? 'Guardar Diagnóstico' : 'Guardar de todos modos (queda marcado)';
    }
    final onPressed = _yaGuardado || _guardando ? null : _guardarDiagnostico;
    final icono = Icon(_yaGuardado ? Icons.check_rounded : Icons.save_rounded);

    if (principal) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: icono,
        label: Text(
          texto,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icono,
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _botonOtroDiagnostico({required bool principal}) {
    if (principal) {
      return FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text(
          'Intentar con otra foto',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.camera_alt_outlined),
      label: const Text('Realizar otro diagnóstico'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
