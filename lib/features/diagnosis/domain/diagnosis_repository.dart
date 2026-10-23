import 'diagnosis_record.dart';

/// Contrato de persistencia de diagnósticos. Permite sustituir SQLite por un
/// doble de prueba en las pruebas de widgets.
abstract class DiagnosisRepository {
  /// Copia la foto a la carpeta permanente y devuelve su **ruta relativa**
  /// (p. ej. `fotos_diagnosticos/chile_123.jpg`), que es lo que se guarda en BD.
  Future<String> guardarImagenPermanente(String sourcePath);

  /// Borra una imagen guardada (ruta relativa o absoluta). Nunca lanza: un
  /// fallo de borrado se registra en el log.
  Future<void> descartarImagen(String rutaGuardada);

  Future<int> insertarDiagnostico(DiagnosisRecord record);

  /// Los registros devueltos traen `imagePath` ya resuelta a una ruta absoluta
  /// utilizable con `File`.
  ///
  /// [soloConcluyentes]: `true` → solo resultados concluyentes; `false` → solo
  /// los no concluyentes (poca confianza o no es hoja); `null` → todos.
  ///
  /// [limite] / [offset] paginan el resultado (más reciente primero). Con
  /// `limite == null` se devuelven todos los registros.
  Future<List<DiagnosisRecord>> obtenerDiagnosticos({
    String? diseaseKey,
    bool? soloConcluyentes,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? limite,
    int offset = 0,
  });

  /// Elimina primero la fila y después la imagen asociada. Si la fila no se
  /// puede eliminar lanza la excepción y la imagen se conserva.
  Future<int> eliminarDiagnostico(int id, String imagePath);
}
