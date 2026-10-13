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

  const DiagnosisRecord({
    this.id,
    required this.imagePath,
    required this.diseaseKey,
    required this.diseaseName,
    required this.confidence,
    required this.createdAt,
    this.notes,
  });

  /// Regla de negocio BR-02 y RNF-04: Verifica que ningún campo obligatorio esté vacío.
  bool get esValido =>
      imagePath.trim().isNotEmpty &&
      diseaseKey.trim().isNotEmpty &&
      diseaseName.trim().isNotEmpty &&
      confidence >= 0.0 &&
      confidence <= 1.0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'image_path': imagePath,
      'disease_key': diseaseKey,
      'disease_name': diseaseName,
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
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
    );
  }
}
