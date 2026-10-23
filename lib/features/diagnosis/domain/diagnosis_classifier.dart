import 'prediction_result.dart';

/// Contrato del clasificador de hojas. Permite sustituir el modelo ONNX real
/// por un doble de prueba en las pruebas de widgets.
abstract class DiagnosisClassifier {
  Future<void> inicializar();
  Future<YoloPredictionResult> analizarImagen(String imagePath);
}
