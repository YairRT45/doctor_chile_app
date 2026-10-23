import 'package:doctor_chile_app/core/constants/chili_classes.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/diagnosis_classifier.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/diagnosis_record.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/diagnosis_repository.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/estado_resultado.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/prediction_result.dart';

/// Repositorio en memoria para pruebas de widgets.
class FakeRepository implements DiagnosisRepository {
  final List<DiagnosisRecord> guardados = [];
  List<DiagnosisRecord> datos;
  bool? ultimoFiltroConcluyentes;
  final List<int> eliminados = [];
  final List<String> imagenesDescartadas = [];

  /// Simula un fallo de la base de datos al insertar / eliminar.
  bool fallarAlInsertar = false;
  bool fallarAlEliminar = false;

  /// Cada consulta realizada (para verificar la paginación).
  final List<({int? limite, int offset})> consultas = [];

  /// Latencia artificial según el número de consulta (1, 2, …). Permite simular
  /// que la respuesta de una consulta vieja llega después de la de una nueva.
  Duration? Function(int numeroConsulta)? retardoPorConsulta;

  FakeRepository({this.datos = const []});

  @override
  Future<String> guardarImagenPermanente(String sourcePath) async =>
      'fotos_diagnosticos/foto.jpg';

  @override
  Future<void> descartarImagen(String rutaGuardada) async {
    imagenesDescartadas.add(rutaGuardada);
  }

  @override
  Future<int> insertarDiagnostico(DiagnosisRecord record) async {
    if (fallarAlInsertar) throw Exception('SQLITE_SECRETO: disk I/O error');
    guardados.add(record);
    return guardados.length;
  }

  @override
  Future<List<DiagnosisRecord>> obtenerDiagnosticos({
    String? diseaseKey,
    bool? soloConcluyentes,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? limite,
    int offset = 0,
  }) async {
    ultimoFiltroConcluyentes = soloConcluyentes;
    consultas.add((limite: limite, offset: offset));
    final retardo = retardoPorConsulta?.call(consultas.length);
    if (retardo != null) await Future<void>.delayed(retardo);
    final filtrados = datos.where((r) {
      if (soloConcluyentes == true) return r.estado == EstadoResultado.concluyente;
      if (soloConcluyentes == false) return r.estado != EstadoResultado.concluyente;
      return true;
    }).toList();
    if (limite == null) return filtrados;
    return filtrados.skip(offset).take(limite).toList();
  }

  @override
  Future<int> eliminarDiagnostico(int id, String imagePath) async {
    if (fallarAlEliminar) throw Exception('SQLITE_SECRETO: database is locked');
    eliminados.add(id);
    return 1;
  }
}

/// Clasificador falso que devuelve un resultado fijo (o lanza un error).
class FakeClassifier implements DiagnosisClassifier {
  Object? errorAlInicializar;
  int inicializaciones = 0;

  @override
  Future<void> inicializar() async {
    inicializaciones++;
    if (errorAlInicializar != null) throw errorAlInicializar!;
  }

  @override
  Future<YoloPredictionResult> analizarImagen(String imagePath) async =>
      resultadoFalso(EstadoResultado.concluyente);
}

/// Construye un resultado de predicción para pruebas (clase ganadora: Spot).
YoloPredictionResult resultadoFalso(
  EstadoResultado estado, {
  double confianza = 0.9,
}) {
  final ganadora = ChiliClasses.todas[2];
  return YoloPredictionResult(
    claseGanadora: ganadora,
    confianza: confianza,
    probabilidadesPorClase: {
      for (final c in ChiliClasses.todas) c: c == ganadora ? confianza : 0.05,
    },
    tiempoInferenciaMs: 42,
    estado: estado,
    mensajeAdvertencia:
        estado == EstadoResultado.concluyente ? null : 'Advertencia de prueba',
    versionModelo: 'test-model',
  );
}

DiagnosisRecord registroFalso({
  int? id,
  String key = 'Spot',
  String nombre = 'Mancha Foliar',
  EstadoResultado estado = EstadoResultado.concluyente,
  DateTime? fecha,
  String? notas,
}) {
  return DiagnosisRecord(
    id: id,
    imagePath: '/no/existe.jpg',
    diseaseKey: key,
    diseaseName: nombre,
    confidence: 0.8,
    createdAt: fecha ?? DateTime(2026, 3, 10, 12),
    notes: notas,
    estado: estado,
    modelVersion: 'test-model',
  );
}
