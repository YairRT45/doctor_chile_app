import '../../../core/constants/chili_classes.dart';
import 'estado_resultado.dart';

/// Resultado devuelto por el servicio de inferencia YOLO11.
class YoloPredictionResult {
  final ChiliClassInfo claseGanadora;
  final double confianza;
  final Map<ChiliClassInfo, double> probabilidadesPorClase;
  final int tiempoInferenciaMs;
  final EstadoResultado estado;
  final String? mensajeAdvertencia;

  /// Identificador del modelo que produjo el resultado (trazabilidad).
  final String versionModelo;

  const YoloPredictionResult({
    required this.claseGanadora,
    required this.confianza,
    required this.probabilidadesPorClase,
    required this.tiempoInferenciaMs,
    required this.estado,
    required this.versionModelo,
    this.mensajeAdvertencia,
  });

  bool get esConcluyente => estado == EstadoResultado.concluyente;
}
