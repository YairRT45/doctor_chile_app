import 'package:doctor_chile_app/core/errors/app_errors.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/estado_resultado.dart';
import 'package:doctor_chile_app/features/diagnosis/services/inference_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('esPixelFoliar', () {
    test('verde, amarillo y café foliar son foliares', () {
      expect(esPixelFoliar(0.2, 0.7, 0.2), isTrue); // verde
      expect(esPixelFoliar(0.8, 0.8, 0.2), isTrue); // amarillo (≈60°)
      expect(esPixelFoliar(0.6, 0.4, 0.1), isTrue); // café/naranja (≈33°)
    });

    test('grises, negro y blanco no son foliares', () {
      expect(esPixelFoliar(0.5, 0.5, 0.5), isFalse);
      expect(esPixelFoliar(0.0, 0.0, 0.0), isFalse);
      expect(esPixelFoliar(1.0, 1.0, 1.0), isFalse);
    });

    test('azul y rojo puro quedan fuera del rango de matiz', () {
      expect(esPixelFoliar(0.1, 0.1, 0.9), isFalse);
      expect(esPixelFoliar(0.9, 0.1, 0.1), isFalse);
    });
  });

  group('normalizarProbabilidades', () {
    test('conserva un vector que ya es softmax', () {
      final v = [0.1, 0.2, 0.7];
      expect(normalizarProbabilidades(v), v);
    });

    test('aplica softmax a logits y suma 1 conservando el orden', () {
      final p = normalizarProbabilidades([2.0, 1.0, 0.0]);
      expect(p.fold<double>(0, (a, b) => a + b), closeTo(1.0, 1e-9));
      expect(p[0] > p[1] && p[1] > p[2], isTrue);
    });

    test('es estable con logits grandes', () {
      final p = normalizarProbabilidades([1000.0, 999.0, 0.0]);
      expect(p.every((x) => x.isFinite), isTrue);
      expect(p.fold<double>(0, (a, b) => a + b), closeTo(1.0, 1e-9));
    });
  });

  group('evaluarPrediccion', () {
    const alta = [0.05, 0.80, 0.05, 0.05, 0.05];
    const baja = [0.30, 0.25, 0.20, 0.15, 0.10];

    test('confianza alta con vegetación suficiente es concluyente', () {
      final e = evaluarPrediccion(alta, 0.5);
      expect(e.indiceGanador, 1);
      expect(e.estado, EstadoResultado.concluyente);
      expect(e.mensajeAdvertencia, isNull);
    });

    test('confianza baja es poca confianza e incluye el porcentaje', () {
      final e = evaluarPrediccion(baja, 0.5);
      expect(e.indiceGanador, 0);
      expect(e.estado, EstadoResultado.pocaConfianza);
      expect(e.mensajeAdvertencia, contains('30.0%'));
    });

    test('poca vegetación manda sobre la confianza (no es hoja)', () {
      final e = evaluarPrediccion(alta, 0.05);
      expect(e.estado, EstadoResultado.noEsHoja);
    });

    test('los umbrales son inclusivos hacia "concluyente"', () {
      final justo = [0.70, 0.075, 0.075, 0.075, 0.075];
      expect(
        evaluarPrediccion(justo, umbralVegetacionMinima).estado,
        EstadoResultado.concluyente,
      );
    });

    test('longitud distinta a las clases conocidas lanza error (no asume sana)', () {
      expect(
        () => evaluarPrediccion([0.5, 0.5, 0.0], 0.5),
        throwsA(isA<SalidaModeloInvalidaError>()),
      );
      expect(
        () => evaluarPrediccion([], 0.5),
        throwsA(isA<SalidaModeloInvalidaError>()),
      );
    });

    test('valores no numéricos lanzan error', () {
      expect(
        () => evaluarPrediccion([double.nan, 0.2, 0.2, 0.2, 0.2], 0.5),
        throwsA(isA<SalidaModeloInvalidaError>()),
      );
    });
  });

  group('mensajeAmigable (U-01)', () {
    test('usa el mensaje del usuario en errores propios, sin detalle técnico', () {
      const e = ImagenInvalidaError(detalle: 'Stack interno secreto');
      final msg = mensajeAmigable(e);
      expect(msg, e.mensajeUsuario);
      expect(msg, isNot(contains('secreto')));
    });

    test('excepciones desconocidas no exponen su texto', () {
      final msg = mensajeAmigable(Exception('PlatformException(boom)'));
      expect(msg, isNot(contains('boom')));
      expect(msg, isNotEmpty);
    });
  });
}
