import 'dart:io';

import 'package:doctor_chile_app/core/errors/app_errors.dart';
import 'package:doctor_chile_app/features/diagnosis/services/image_preprocessing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('doctor_chile_prep_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Guarda una imagen PNG (sin pérdida) y devuelve su ruta.
  String guardar(img.Image imagen, [String nombre = 'foto.png']) {
    final ruta = p.join(tmp.path, nombre);
    File(ruta).writeAsBytesSync(img.encodePng(imagen));
    return ruta;
  }

  img.Image lisa(int ancho, int alto, int r, int g, int b) {
    final imagen = img.Image(width: ancho, height: alto);
    img.fill(imagen, color: img.ColorRgb8(r, g, b));
    return imagen;
  }

  const lado = tamanoEntradaModelo;
  const plano = lado * lado;

  group('preprocesarImagen', () {
    test('produce un tensor NCHW de 3×224×224 con valores entre 0 y 1', () {
      final r = preprocesarImagen(guardar(lisa(300, 200, 0, 200, 0)));

      expect(r.tensor.length, 3 * plano);
      expect(r.tensor.every((v) => v >= 0.0 && v <= 1.0), isTrue);
    });

    test('una hoja verde se considera 100 % foliar y llena el canal G', () {
      final r = preprocesarImagen(guardar(lisa(300, 200, 0, 200, 0)));

      expect(r.proporcionVegetal, closeTo(1.0, 1e-9));
      expect(r.tensor[0], closeTo(0.0, 1e-6)); // plano R
      expect(r.tensor[plano], closeTo(200 / 255, 1e-2)); // plano G
      expect(r.tensor[2 * plano], closeTo(0.0, 1e-6)); // plano B
    });

    test('una imagen gris no tiene píxeles foliares', () {
      final r = preprocesarImagen(guardar(lisa(224, 224, 128, 128, 128)));
      expect(r.proporcionVegetal, 0.0);
    });

    test('respeta el orden de canales y la posición de los píxeles', () {
      // Mitad izquierda roja, mitad derecha azul.
      final imagen = lisa(200, 200, 0, 0, 255);
      img.fillRect(imagen,
          x1: 0, y1: 0, x2: 99, y2: 199, color: img.ColorRgb8(255, 0, 0));
      final r = preprocesarImagen(guardar(imagen));

      int idx(int x, int y) => y * lado + x;
      // Izquierda (x=10): rojo.
      expect(r.tensor[idx(10, 10)], closeTo(1.0, 1e-2)); // R
      expect(r.tensor[plano + idx(10, 10)], closeTo(0.0, 1e-2)); // G
      expect(r.tensor[2 * plano + idx(10, 10)], closeTo(0.0, 1e-2)); // B
      // Derecha (x=210): azul.
      expect(r.tensor[idx(210, 10)], closeTo(0.0, 1e-2));
      expect(r.tensor[2 * plano + idx(210, 10)], closeTo(1.0, 1e-2));
    });

    test('un archivo que no es imagen lanza ImagenInvalidaError', () {
      final ruta = p.join(tmp.path, 'texto.jpg');
      File(ruta).writeAsStringSync('esto no es una imagen');

      expect(() => preprocesarImagen(ruta), throwsA(isA<ImagenInvalidaError>()));
    });

    test('un archivo inexistente lanza ImagenInvalidaError', () {
      expect(
        () => preprocesarImagen(p.join(tmp.path, 'no_existe.jpg')),
        throwsA(isA<ImagenInvalidaError>()),
      );
    });
  });

  group('preprocesarEnSegundoPlano (M-05)', () {
    test('da el mismo resultado que la versión síncrona', () async {
      final ruta = guardar(lisa(320, 240, 20, 160, 40));

      final sincrono = preprocesarImagen(ruta);
      final aislado = await preprocesarEnSegundoPlano(ruta);

      expect(aislado.proporcionVegetal, sincrono.proporcionVegetal);
      expect(aislado.tensor.length, sincrono.tensor.length);
      expect(aislado.tensor, orderedEquals(sincrono.tensor));
    });

    test('los errores del Isolate llegan al llamador con su tipo', () async {
      await expectLater(
        preprocesarEnSegundoPlano(p.join(tmp.path, 'no_existe.jpg')),
        throwsA(isA<ImagenInvalidaError>()),
      );
    });
  });
}
