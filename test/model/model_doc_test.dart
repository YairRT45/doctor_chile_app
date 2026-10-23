import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:doctor_chile_app/core/constants/chili_classes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mantiene sincronizados el modelo empaquetado, `docs/MODEL.md` y el catálogo
/// de clases (M-07). No ejecuta el modelo: solo detecta que se cambió el archivo
/// o el orden de clases sin actualizar la documentación.
void main() {
  final doc = File('docs/MODEL.md');
  final modelo = File('assets/models/best.onnx');

  test('existen el documento y el modelo', () {
    expect(doc.existsSync(), isTrue, reason: 'Falta docs/MODEL.md');
    expect(modelo.existsSync(), isTrue, reason: 'Falta assets/models/best.onnx');
  });

  test('el SHA-256 documentado coincide con el modelo empaquetado', () {
    final texto = doc.readAsStringSync();
    final m = RegExp(r'SHA-256\s*\|\s*`([0-9a-fA-F]{64})`').firstMatch(texto);
    expect(m, isNotNull, reason: 'MODEL.md no contiene la fila "SHA-256 | `…`"');

    final real = sha256.convert(modelo.readAsBytesSync()).toString();
    expect(
      real,
      m!.group(1)!.toLowerCase(),
      reason: 'El modelo cambió: actualiza el hash (y revisa el orden de clases) en docs/MODEL.md',
    );
  });

  test('el orden de clases documentado coincide con ChiliClasses', () {
    final texto = doc.readAsStringSync();
    final bloque = RegExp(
      r'<!-- CLASES:INICIO -->(.*?)<!-- CLASES:FIN -->',
      dotAll: true,
    ).firstMatch(texto);
    expect(bloque, isNotNull, reason: 'MODEL.md no contiene el bloque de clases');

    final documentadas = RegExp(r'^\s*(\d+):\s*(\w+)\s*$', multiLine: true)
        .allMatches(bloque!.group(1)!)
        .map((m) => MapEntry(int.parse(m.group(1)!), m.group(2)!))
        .toList();

    expect(documentadas.length, ChiliClasses.todas.length);
    for (final e in documentadas) {
      final clase = ChiliClasses.porIndice(e.key);
      expect(clase, isNotNull, reason: 'Índice ${e.key} no existe en ChiliClasses');
      expect(clase!.key, e.value, reason: 'Clase distinta en el índice ${e.key}');
    }
  });
}
