import 'dart:async';

import 'package:doctor_chile_app/core/utils/carga_unica.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CargaUnica (M-06)', () {
    test('llamadas simultáneas comparten una única carga', () async {
      var creaciones = 0;
      final completer = Completer<String>();
      final carga = CargaUnica<String>(() {
        creaciones++;
        return completer.future;
      });

      final a = carga.obtener();
      final b = carga.obtener();
      final c = carga.obtener();
      completer.complete('sesion');

      expect(await Future.wait([a, b, c]), ['sesion', 'sesion', 'sesion']);
      expect(creaciones, 1);
    });

    test('tras cargar, no vuelve a crear el recurso', () async {
      var creaciones = 0;
      final carga = CargaUnica<int>(() async => ++creaciones);

      expect(await carga.obtener(), 1);
      expect(await carga.obtener(), 1);
      expect(creaciones, 1);
      expect(carga.estaLista, isTrue);
      expect(carga.valor, 1);
    });

    test('un fallo se propaga a todos los que esperaban y permite reintentar', () async {
      var intentos = 0;
      final carga = CargaUnica<String>(() async {
        intentos++;
        if (intentos == 1) throw StateError('falló la carga');
        return 'ok';
      });

      final a = carga.obtener();
      final b = carga.obtener();
      await expectLater(a, throwsStateError);
      await expectLater(b, throwsStateError);
      expect(carga.estaLista, isFalse);
      expect(carga.valor, isNull);

      expect(await carga.obtener(), 'ok'); // reintento exitoso
      expect(intentos, 2);
    });

    test('reiniciar fuerza una nueva carga', () async {
      var creaciones = 0;
      final carga = CargaUnica<int>(() async => ++creaciones);

      await carga.obtener();
      carga.reiniciar();
      expect(carga.estaLista, isFalse);
      expect(await carga.obtener(), 2);
    });
  });
}
