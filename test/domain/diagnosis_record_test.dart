import 'package:doctor_chile_app/features/diagnosis/domain/diagnosis_record.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/estado_resultado.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosisRecord _base({
  String imagePath = '/foto.jpg',
  String key = 'Spot',
  String nombre = 'Mancha Foliar',
  double confianza = 0.85,
  EstadoResultado estado = EstadoResultado.concluyente,
}) {
  return DiagnosisRecord(
    imagePath: imagePath,
    diseaseKey: key,
    diseaseName: nombre,
    confidence: confianza,
    createdAt: DateTime(2026, 3, 10, 12, 30),
    estado: estado,
  );
}

void main() {
  group('esValido (BR-02)', () {
    test('acepta un registro completo', () {
      expect(_base().esValido, isTrue);
    });

    test('rechaza campos obligatorios vacíos o en blanco', () {
      expect(_base(imagePath: '').esValido, isFalse);
      expect(_base(key: '  ').esValido, isFalse);
      expect(_base(nombre: '').esValido, isFalse);
    });

    test('rechaza confianza fuera de [0, 1]', () {
      expect(_base(confianza: -0.01).esValido, isFalse);
      expect(_base(confianza: 1.01).esValido, isFalse);
      expect(_base(confianza: 0).esValido, isTrue);
      expect(_base(confianza: 1).esValido, isTrue);
    });
  });

  group('toMap / fromMap', () {
    test('ida y vuelta conserva todos los campos', () {
      final original = DiagnosisRecord(
        id: 7,
        imagePath: '/foto.jpg',
        diseaseKey: 'Curl',
        diseaseName: 'Hoja Rizada',
        confidence: 0.55,
        createdAt: DateTime(2026, 1, 2, 3, 4, 5),
        notes: 'Parcela Norte',
        estado: EstadoResultado.pocaConfianza,
        modelVersion: 'best.onnx',
      );
      final copia = DiagnosisRecord.fromMap(original.toMap());

      expect(copia.id, 7);
      expect(copia.imagePath, '/foto.jpg');
      expect(copia.diseaseKey, 'Curl');
      expect(copia.diseaseName, 'Hoja Rizada');
      expect(copia.confidence, 0.55);
      expect(copia.createdAt, DateTime(2026, 1, 2, 3, 4, 5));
      expect(copia.notes, 'Parcela Norte');
      expect(copia.estado, EstadoResultado.pocaConfianza);
      expect(copia.modelVersion, 'best.onnx');
    });

    test('toMap omite id nulo', () {
      expect(_base().toMap().containsKey('id'), isFalse);
    });

    test('un registro anterior a la v2 (sin estado) se lee como concluyente', () {
      final map = _base().toMap()
        ..remove('estado')
        ..remove('model_version');
      final r = DiagnosisRecord.fromMap(map);
      expect(r.estado, EstadoResultado.concluyente);
      expect(r.modelVersion, isNull);
    });
  });

  group('EstadoResultado.desdeClave', () {
    test('reconoce cada clave', () {
      for (final e in EstadoResultado.values) {
        expect(EstadoResultado.desdeClave(e.clave), e);
      }
    });

    test('nulo = concluyente (registros antiguos)', () {
      expect(EstadoResultado.desdeClave(null), EstadoResultado.concluyente);
    });

    test('valor desconocido se trata con cautela como poca confianza', () {
      expect(EstadoResultado.desdeClave('???'), EstadoResultado.pocaConfianza);
    });
  });

  group('tituloVisible', () {
    test('concluyente muestra el nombre', () {
      expect(_base().tituloVisible, 'Mancha Foliar');
    });

    test('poca confianza antepone "Posible"', () {
      expect(
        _base(estado: EstadoResultado.pocaConfianza).tituloVisible,
        'Posible: Mancha Foliar',
      );
    });

    test('no es hoja nunca muestra una enfermedad', () {
      expect(
        _base(estado: EstadoResultado.noEsHoja).tituloVisible,
        'Sin diagnóstico fiable',
      );
    });
  });
}
