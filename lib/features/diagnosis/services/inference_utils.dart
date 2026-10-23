import 'dart:math' as math;

import '../../../core/constants/chili_classes.dart';
import '../../../core/errors/app_errors.dart';
import '../domain/estado_resultado.dart';

/// Lógica pura de inferencia (sin plugins ni E/S) para poder probarla de forma
/// unitaria.

const double umbralConfianzaMinima = 0.70; // 70% mínimo de certeza
const double umbralVegetacionMinima = 0.15; // Al menos 15% de píxeles foliares (calibrado en Fase 5)

/// Verifica mediante espacio de color HSV si un píxel corresponde a tonos de
/// hoja verde, hoja amarillenta (clorosis) o tejido foliar con manchas.
bool esPixelFoliar(double r, double g, double b) {
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
List<double> normalizarProbabilidades(List<double> scores) {
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

/// Decisión final sobre una predicción ya normalizada.
class EvaluacionPrediccion {
  final int indiceGanador;
  final double confianza;
  final EstadoResultado estado;
  final String? mensajeAdvertencia;

  const EvaluacionPrediccion({
    required this.indiceGanador,
    required this.confianza,
    required this.estado,
    this.mensajeAdvertencia,
  });
}

/// Elige la clase ganadora y valida las defensas (proporción vegetal y umbral
/// de confianza). Lanza [SalidaModeloInvalidaError] si la salida del modelo no
/// coincide con las clases conocidas: nunca se asume una clase por defecto.
EvaluacionPrediccion evaluarPrediccion(
  List<double> probs,
  double proporcionVegetal,
) {
  if (probs.length != ChiliClasses.todas.length) {
    throw SalidaModeloInvalidaError(
      detalle:
          'El modelo devolvió ${probs.length} valores y la app espera ${ChiliClasses.todas.length}.',
    );
  }
  if (probs.any((p) => !p.isFinite)) {
    throw const SalidaModeloInvalidaError(
      detalle: 'La salida del modelo contiene valores no numéricos.',
    );
  }

  int bestIdx = 0;
  double bestProb = probs[0];
  for (int i = 1; i < probs.length; i++) {
    if (probs[i] > bestProb) {
      bestProb = probs[i];
      bestIdx = i;
    }
  }

  EstadoResultado estado = EstadoResultado.concluyente;
  String? advertencia;

  if (proporcionVegetal < umbralVegetacionMinima) {
    estado = EstadoResultado.noEsHoja;
    advertencia =
        'La imagen no parece contener una hoja de chile (baja presencia de tonos foliares). Por favor acerque la cámara a la hoja.';
  } else if (bestProb < umbralConfianzaMinima) {
    estado = EstadoResultado.pocaConfianza;
    advertencia =
        'El nivel de certeza (${(bestProb * 100).toStringAsFixed(1)}%) es bajo. Intente tomar la fotografía con mejor iluminación y enfocando una sola hoja.';
  }

  return EvaluacionPrediccion(
    indiceGanador: bestIdx,
    confianza: bestProb,
    estado: estado,
    mensajeAdvertencia: advertencia,
  );
}
