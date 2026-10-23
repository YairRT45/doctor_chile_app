import 'package:doctor_chile_app/core/constants/chili_classes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChiliClasses (M-01)', () {
    test('hay 5 clases con índices 0..4 consecutivos', () {
      expect(ChiliClasses.todas.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(ChiliClasses.todas[i].index, i);
      }
    });

    test('porIndice devuelve la clase correcta', () {
      expect(ChiliClasses.porIndice(0)!.key, 'Curl');
      expect(ChiliClasses.porIndice(1)!.key, 'Healthy');
      expect(ChiliClasses.porIndice(4)!.key, 'Yellowish');
    });

    test('porIndice fuera de rango devuelve null (nunca "sana")', () {
      expect(ChiliClasses.porIndice(99), isNull);
      expect(ChiliClasses.porIndice(-1), isNull);
    });

    test('porClave ignora mayúsculas y devuelve null si no existe', () {
      expect(ChiliClasses.porClave('whitefly')!.key, 'Whitefly');
      expect(ChiliClasses.porClave('xyz'), isNull);
    });

    test('porClaveODesconocida nunca devuelve una clase sana', () {
      final info = ChiliClasses.porClaveODesconocida('xyz');
      expect(info, same(ChiliClasses.desconocida));
      expect(info.esSana, isFalse);
    });

    test('solo la clase Healthy está marcada como sana', () {
      final sanas = ChiliClasses.todas.where((c) => c.esSana).map((c) => c.key);
      expect(sanas, ['Healthy']);
    });
  });
}
