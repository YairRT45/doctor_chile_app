import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/diagnosis/domain/diagnosis_record.dart';
import '../../features/diagnosis/domain/diagnosis_repository.dart';
import '../../features/diagnosis/domain/estado_resultado.dart';
import '../errors/app_errors.dart';

/// Base de datos local SQLite (100% offline, RN-03).
/// Implementa el almacenamiento y consulta de diagnósticos (CU-01 y CU-02).
class LocalDatabase implements DiagnosisRepository {
  static final LocalDatabase instance = LocalDatabase._init();

  /// Versión actual del esquema.
  /// v1: tabla inicial. v2: columnas `estado` y `model_version`.
  /// v3: `image_path` pasa de ruta absoluta a ruta relativa
  /// (`fotos_diagnosticos/<archivo>`), inmune a cambios del directorio de la app.
  static const int versionEsquema = 3;

  /// Carpeta (dentro de documentos de la app) donde viven las fotos guardadas.
  static const String carpetaImagenes = 'fotos_diagnosticos';

  /// Se guarda el `Future` (no el resultado) para que dos llamadas simultáneas
  /// compartan una única apertura de la base de datos.
  Future<Database>? _dbFuture;

  /// Ruta fija del archivo (solo pruebas). Si es nula se usa la carpeta de
  /// bases de datos de la aplicación.
  final String? _rutaFija;

  final Future<String> Function() _directorioDocumentos;

  LocalDatabase._init()
      : _rutaFija = null,
        _directorioDocumentos = _documentosPorDefecto;

  /// Crea una instancia sobre una ruta concreta (p. ej. `inMemoryDatabasePath`
  /// o un archivo temporal) para pruebas automáticas. [directorioDocumentos]
  /// permite sustituir la carpeta de documentos de la aplicación.
  LocalDatabase.conRuta(
    String ruta, {
    Future<String> Function()? directorioDocumentos,
  })  : _rutaFija = ruta,
        _directorioDocumentos = directorioDocumentos ?? _documentosPorDefecto;

  static Future<String> _documentosPorDefecto() async =>
      (await getApplicationDocumentsDirectory()).path;

  Future<Database> get database {
    final existente = _dbFuture;
    if (existente != null) return existente;

    final apertura = _initDB('doctor_chile.db');
    _dbFuture = apertura;
    // Si la apertura falla, se permite reintentar en la siguiente llamada.
    unawaited(
      apertura.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_dbFuture, apertura)) _dbFuture = null;
        },
      ),
    );
    return apertura;
  }

  Future<Database> _initDB(String fileName) async {
    final path = _rutaFija ?? p.join(await getDatabasesPath(), fileName);

    return await openDatabase(
      path,
      version: versionEsquema,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE diagnosticos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        disease_key TEXT NOT NULL,
        disease_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT,
        estado TEXT NOT NULL DEFAULT 'concluyente',
        model_version TEXT
      )
    ''');
  }

  /// Migraciones incrementales. Los registros existentes se conservan; los
  /// anteriores a la v2 quedan como 'concluyente' (valor por defecto).
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE diagnosticos ADD COLUMN estado TEXT NOT NULL DEFAULT 'concluyente'",
      );
      await db.execute(
        'ALTER TABLE diagnosticos ADD COLUMN model_version TEXT',
      );
    }
    if (oldVersion < 3) {
      // Convierte las rutas absolutas guardadas a relativas conservando solo el
      // nombre del archivo (siempre vivió en la carpeta de fotos).
      final filas = await db.query('diagnosticos', columns: ['id', 'image_path']);
      for (final fila in filas) {
        final ruta = fila['image_path'] as String?;
        if (ruta == null || ruta.isEmpty || !_esRutaAbsoluta(ruta)) continue;
        await db.update(
          'diagnosticos',
          {'image_path': '$carpetaImagenes/${p.basename(ruta)}'},
          where: 'id = ?',
          whereArgs: [fila['id']],
        );
      }
    }
  }

  /// Cierra la conexión (útil en pruebas).
  Future<void> cerrar() async {
    final apertura = _dbFuture;
    _dbFuture = null;
    if (apertura == null) return;
    try {
      await (await apertura).close();
    } catch (_) {}
  }

  /// Detecta rutas absolutas tanto de Android/iOS (`/…`) como de Windows (`C:\…`).
  static bool _esRutaAbsoluta(String ruta) =>
      ruta.startsWith('/') ||
      ruta.startsWith(r'\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(ruta);

  /// Convierte la ruta guardada (relativa) en una absoluta bajo [documentos].
  /// Una ruta ya absoluta (registros heredados) se devuelve tal cual.
  static String _resolver(String documentos, String guardada) {
    if (_esRutaAbsoluta(guardada)) return guardada;
    return p.joinAll([documentos, ...guardada.split('/')]);
  }

  /// Copia la fotografía tomada a la carpeta permanente de la aplicación
  /// para que no se borre de la caché temporal del teléfono. Devuelve la ruta
  /// **relativa** (`fotos_diagnosticos/<archivo>`).
  @override
  Future<String> guardarImagenPermanente(String sourcePath) async {
    final documentos = await _directorioDocumentos();
    final imagesDir = Directory(p.join(documentos, carpetaImagenes));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = 'chile_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(imagesDir.path, fileName);

    await File(sourcePath).copy(destPath);
    return '$carpetaImagenes/$fileName';
  }

  @override
  Future<void> descartarImagen(String rutaGuardada) async {
    try {
      final documentos = await _directorioDocumentos();
      final file = File(_resolver(documentos, rutaGuardada));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      registrarError(e, st, 'No se pudo borrar la imagen $rutaGuardada');
    }
  }

  /// Guarda un diagnóstico validando primero la regla de negocio BR-02 / RNF-04.
  @override
  Future<int> insertarDiagnostico(DiagnosisRecord record) async {
    if (!record.esValido) {
      throw ArgumentError(
        'BR-02: No se permite almacenar el diagnóstico porque faltan campos obligatorios.',
      );
    }
    final db = await database;
    return await db.insert('diagnosticos', record.toMap());
  }

  /// Consulta diagnósticos permitiendo filtrar por afección (CU-02 FN),
  /// por fiabilidad del resultado y/o por rango de fechas (CU-02 FA.1).
  /// Las filas corruptas se omiten (y se registran) en vez de romper la lista.
  @override
  Future<List<DiagnosisRecord>> obtenerDiagnosticos({
    String? diseaseKey,
    bool? soloConcluyentes,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? limite,
    int offset = 0,
  }) async {
    final db = await database;

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (diseaseKey != null && diseaseKey.isNotEmpty && diseaseKey != 'TODAS') {
      whereClauses.add('disease_key = ?');
      whereArgs.add(diseaseKey);
    }

    if (soloConcluyentes != null) {
      whereClauses.add(soloConcluyentes ? 'estado = ?' : 'estado <> ?');
      whereArgs.add(EstadoResultado.concluyente.clave);
    }

    if (fechaInicio != null) {
      final startOfDay = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
      whereClauses.add('created_at >= ?');
      whereArgs.add(startOfDay.toIso8601String());
    }

    if (fechaFin != null) {
      final endOfDay = DateTime(
        fechaFin.year,
        fechaFin.month,
        fechaFin.day,
        23,
        59,
        59,
        999,
      );
      whereClauses.add('created_at <= ?');
      whereArgs.add(endOfDay.toIso8601String());
    }

    final result = await db.query(
      'diagnosticos',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      // El desempate por id mantiene un orden estable entre páginas.
      orderBy: 'created_at DESC, id DESC',
      limit: limite,
      offset: limite == null ? null : offset,
    );

    final documentos = await _directorioDocumentos();
    final registros = <DiagnosisRecord>[];
    for (final row in result) {
      final registro = DiagnosisRecord.tryFromMap(row);
      if (registro == null) {
        registrarError(
          StateError('Fila de diagnóstico corrupta (id=${row['id']}); se omite.'),
          null,
          'Lectura del historial',
        );
        continue;
      }
      registros.add(
        registro.conRutaImagen(_resolver(documentos, registro.imagePath)),
      );
    }
    return registros;
  }

  /// Elimina un diagnóstico y su archivo de imagen asociado. Primero se borra
  /// la fila: si eso falla, se lanza la excepción y la foto se conserva (no
  /// quedan registros sin imagen). Un fallo al borrar el archivo solo se
  /// registra: como máximo queda una foto huérfana que se limpia al iniciar.
  @override
  Future<int> eliminarDiagnostico(int id, String imagePath) async {
    final db = await database;
    final borradas = await db.delete('diagnosticos', where: 'id = ?', whereArgs: [id]);
    if (borradas > 0) {
      await descartarImagen(imagePath);
    }
    return borradas;
  }

  /// Borra de la carpeta de fotos los archivos que ningún registro referencia
  /// (p. ej. copiados justo antes de un fallo de inserción). Debe ejecutarse al
  /// iniciar la app, antes de que el usuario guarde nada. Si no se puede leer la
  /// base de datos no se borra nada. Devuelve cuántos archivos se eliminaron.
  Future<int> limpiarImagenesHuerfanas() async {
    final db = await database;
    final filas = await db.query('diagnosticos', columns: ['image_path']);
    final referenciadas = <String>{
      for (final f in filas)
        if (f['image_path'] is String) p.basename(f['image_path'] as String),
    };

    final documentos = await _directorioDocumentos();
    final dir = Directory(p.join(documentos, carpetaImagenes));
    if (!await dir.exists()) return 0;

    var borradas = 0;
    await for (final entidad in dir.list()) {
      if (entidad is! File) continue;
      if (referenciadas.contains(p.basename(entidad.path))) continue;
      try {
        await entidad.delete();
        borradas++;
      } catch (e, st) {
        registrarError(e, st, 'No se pudo borrar la imagen huérfana ${entidad.path}');
      }
    }
    return borradas;
  }
}
