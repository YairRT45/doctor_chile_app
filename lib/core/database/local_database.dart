import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/diagnosis/domain/diagnosis_record.dart';

/// Base de datos local SQLite (100% offline, RN-03).
/// Implementa el almacenamiento y consulta de diagnósticos (CU-01 y CU-02).
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('doctor_chile.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
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
        notes TEXT
      )
    ''');
  }

  /// Copia la fotografía tomada a la carpeta permanente de la aplicación
  /// para que no se borre de la caché temporal del teléfono.
  Future<String> guardarImagenPermanente(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'fotos_diagnosticos'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = 'chile_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(imagesDir.path, fileName);

    final copiedFile = await File(sourcePath).copy(destPath);
    return copiedFile.path;
  }

  /// Guarda un diagnóstico validando primero la regla de negocio BR-02 / RNF-04.
  Future<int> insertarDiagnostico(DiagnosisRecord record) async {
    if (!record.esValido) {
      throw ArgumentError(
        'BR-02: No se permite almacenar el diagnóstico porque faltan campos obligatorios.',
      );
    }
    final db = await instance.database;
    return await db.insert('diagnosticos', record.toMap());
  }

  /// Consulta diagnósticos permitiendo filtrar por afección (CU-02 FN)
  /// y/o por rango de fechas (CU-02 FA.1).
  Future<List<DiagnosisRecord>> obtenerDiagnosticos({
    String? diseaseKey,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final db = await instance.database;

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (diseaseKey != null && diseaseKey.isNotEmpty && diseaseKey != 'TODAS') {
      whereClauses.add('disease_key = ?');
      whereArgs.add(diseaseKey);
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
      orderBy: 'created_at DESC',
    );

    return result.map((row) => DiagnosisRecord.fromMap(row)).toList();
  }

  /// Elimina un diagnóstico y su archivo de imagen asociado.
  Future<int> eliminarDiagnostico(int id, String imagePath) async {
    final db = await instance.database;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    return await db.delete('diagnosticos', where: 'id = ?', whereArgs: [id]);
  }
}
