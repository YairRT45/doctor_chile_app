import 'estado_resultado.dart';

/// Modelo de datos de un diagnóstico realizado en campo.
/// Cumple con las reglas de negocio:
/// - BR-01: Identificación única de diagnósticos (campo [id]).
/// - BR-02: Validación de campos obligatorios antes del almacenamiento.
class DiagnosisRecord {
  final int? id;
  final String imagePath;
  final String diseaseKey;
  final String diseaseName;
  final double confidence;
  final DateTime createdAt;
  final String? notes;

  /// Fiabilidad del resultado en el momento del análisis.
  final EstadoResultado estado;

  /// Identificador del modelo que produjo el diagnóstico (puede ser nulo en
  /// registros anteriores a la versión 2 de la base de datos).
  final String? modelVersion;

  const DiagnosisRecord({
    this.id,
    required this.imagePath,
    required this.diseaseKey,
    required this.diseaseName,
    required this.confidence,
    required this.createdAt,
    this.notes,
    this.estado = EstadoResultado.concluyente,
    this.modelVersion,
  });

  /// Regla de negocio BR-02 y RNF-04: Verifica que ningún campo obligatorio esté vacío.
  bool get esValido =>
      imagePath.trim().isNotEmpty &&
      diseaseKey.trim().isNotEmpty &&
      diseaseName.trim().isNotEmpty &&
      confidence >= 0.0 &&
      confidence <= 1.0;

  /// Título para listas y detalle: un resultado dudoso nunca se presenta como
  /// un diagnóstico firme.
  String get tituloVisible {
    switch (estado) {
      case EstadoResultado.concluyente:
        return diseaseName;
      case EstadoResultado.pocaConfianza:
        return 'Posible: $diseaseName';
      case EstadoResultado.noEsHoja:
        return 'Sin diagnóstico fiable';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'image_path': imagePath,
      'disease_key': diseaseKey,
      'disease_name': diseaseName,
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'estado': estado.clave,
      'model_version': modelVersion,
    };
  }

  factory DiagnosisRecord.fromMap(Map<String, dynamic> map) {
    return DiagnosisRecord(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      diseaseKey: map['disease_key'] as String,
      diseaseName: map['disease_name'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      notes: map['notes'] as String?,
      estado: EstadoResultado.desdeClave(map['estado'] as String?),
      modelVersion: map['model_version'] as String?,
    );
  }

  /// Igual que [DiagnosisRecord.fromMap], pero devuelve `null` si la fila está
  /// corrupta (campo ausente, tipo incorrecto o fecha inválida) en vez de lanzar.
  static DiagnosisRecord? tryFromMap(Map<String, dynamic> map) {
    try {
      return DiagnosisRecord.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Copia del registro con otra ruta de imagen (p. ej. ya resuelta a absoluta).
  DiagnosisRecord conRutaImagen(String nuevaRuta) {
    return DiagnosisRecord(
      id: id,
      imagePath: nuevaRuta,
      diseaseKey: diseaseKey,
      diseaseName: diseaseName,
      confidence: confidence,
      createdAt: createdAt,
      notes: notes,
      estado: estado,
      modelVersion: modelVersion,
    );
  }
}
