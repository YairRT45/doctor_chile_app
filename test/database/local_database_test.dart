import 'dart:io';

import 'package:doctor_chile_app/core/database/local_database.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/diagnosis_record.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/estado_resultado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fakes.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory docs; // sustituye a la carpeta de documentos de la app
  late LocalDatabase db;

  Directory carpetaFotos() =>
      Directory(p.join(docs.path, LocalDatabase.carpetaImagenes));

  File crearFoto(String nombre, {Directory? en}) {
    final dir = en ?? carpetaFotos();
    dir.createSync(recursive: true);
    return File(p.join(dir.path, nombre))..writeAsStringSync('img');
  }

  setUp(() {
    docs = Directory.systemTemp.createTempSync('doctor_chile_docs_');
    db = LocalDatabase.conRuta(
      inMemoryDatabasePath,
      directorioDocumentos: () async => docs.path,
    );
  });

  tearDown(() async {
    await db.cerrar();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  group('insertar / obtener', () {
    test('inserta y recupera un registro con estado y versión de modelo', () async {
      final id = await db.insertarDiagnostico(
        registroFalso(estado: EstadoResultado.pocaConfianza, notas: 'Surco 4'),
      );
      expect(id, greaterThan(0));

      final lista = await db.obtenerDiagnosticos();
      expect(lista, hasLength(1));
      expect(lista.first.id, id);
      expect(lista.first.estado, EstadoResultado.pocaConfianza);
      expect(lista.first.modelVersion, 'test-model');
      expect(lista.first.notes, 'Surco 4');
    });

    test('BR-02: rechaza un registro inválido', () async {
      final invalido = DiagnosisRecord(
        imagePath: '',
        diseaseKey: 'Spot',
        diseaseName: 'Mancha',
        confidence: 0.5,
        createdAt: DateTime(2026),
      );
      expect(() => db.insertarDiagnostico(invalido), throwsArgumentError);
    });

    test('ordena del más reciente al más antiguo', () async {
      await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 1, 1)));
      await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 3, 1)));
      await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 2, 1)));

      final lista = await db.obtenerDiagnosticos();
      expect(
        lista.map((r) => r.createdAt.month).toList(),
        [3, 2, 1],
      );
    });
  });

  group('paginación (Fase 4)', () {
    setUp(() async {
      // 7 registros; los dos últimos comparten la misma fecha para probar el desempate.
      for (var d = 1; d <= 5; d++) {
        await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 1, d)));
      }
      await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 2, 1)));
      await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 2, 1)));
    });

    test('las páginas no se solapan y juntas equivalen a la lista completa', () async {
      final completa = await db.obtenerDiagnosticos();
      final p1 = await db.obtenerDiagnosticos(limite: 3);
      final p2 = await db.obtenerDiagnosticos(limite: 3, offset: 3);
      final p3 = await db.obtenerDiagnosticos(limite: 3, offset: 6);

      expect(p1, hasLength(3));
      expect(p2, hasLength(3));
      expect(p3, hasLength(1));
      expect(
        [...p1, ...p2, ...p3].map((r) => r.id).toList(),
        completa.map((r) => r.id).toList(),
      );
    });

    test('con la misma fecha el orden es estable (más reciente por id primero)', () async {
      final r = await db.obtenerDiagnosticos(limite: 2);
      expect(r.map((x) => x.createdAt), everyElement(DateTime(2026, 2, 1)));
      expect(r.first.id! > r.last.id!, isTrue);
    });

    test('un offset más allá del final devuelve una lista vacía', () async {
      expect(await db.obtenerDiagnosticos(limite: 5, offset: 50), isEmpty);
    });

    test('sin límite devuelve todos los registros', () async {
      expect(await db.obtenerDiagnosticos(), hasLength(7));
    });

    test('la paginación respeta los filtros', () async {
      await db.insertarDiagnostico(
        registroFalso(estado: EstadoResultado.noEsHoja, fecha: DateTime(2026, 3, 1)),
      );
      final r = await db.obtenerDiagnosticos(soloConcluyentes: false, limite: 3);
      expect(r, hasLength(1));
      expect(r.single.estado, EstadoResultado.noEsHoja);
    });
  });

  group('filtros', () {
    setUp(() async {
      await db.insertarDiagnostico(
        registroFalso(key: 'Spot', fecha: DateTime(2026, 3, 10, 8)),
      );
      await db.insertarDiagnostico(
        registroFalso(
          key: 'Curl',
          nombre: 'Hoja Rizada',
          estado: EstadoResultado.pocaConfianza,
          fecha: DateTime(2026, 3, 10, 23, 30),
        ),
      );
      await db.insertarDiagnostico(
        registroFalso(
          key: 'Spot',
          estado: EstadoResultado.noEsHoja,
          fecha: DateTime(2026, 3, 11, 0, 5),
        ),
      );
    });

    test('por afección', () async {
      final r = await db.obtenerDiagnosticos(diseaseKey: 'Curl');
      expect(r, hasLength(1));
      expect(r.first.diseaseKey, 'Curl');
    });

    test("'TODAS' no filtra", () async {
      final r = await db.obtenerDiagnosticos(diseaseKey: 'TODAS');
      expect(r, hasLength(3));
    });

    test('solo concluyentes', () async {
      final r = await db.obtenerDiagnosticos(soloConcluyentes: true);
      expect(r, hasLength(1));
      expect(r.first.estado, EstadoResultado.concluyente);
    });

    test('solo no concluyentes incluye poca confianza y no es hoja', () async {
      final r = await db.obtenerDiagnosticos(soloConcluyentes: false);
      expect(r, hasLength(2));
      expect(r.any((x) => x.estado == EstadoResultado.concluyente), isFalse);
    });

    test('rango de fechas incluye el día completo en ambos extremos', () async {
      final r = await db.obtenerDiagnosticos(
        fechaInicio: DateTime(2026, 3, 10, 15), // la hora se ignora
        fechaFin: DateTime(2026, 3, 10, 1), // hasta las 23:59 de ese día
      );
      expect(r, hasLength(2)); // 08:00 y 23:30 del día 10; excluye 00:05 del 11
    });

    test('combina afección y fiabilidad', () async {
      final r = await db.obtenerDiagnosticos(
        diseaseKey: 'Spot',
        soloConcluyentes: false,
      );
      expect(r, hasLength(1));
      expect(r.first.estado, EstadoResultado.noEsHoja);
    });
  });

  group('D-01: rutas de imagen relativas', () {
    test('guardarImagenPermanente copia la foto y devuelve ruta relativa', () async {
      final origen = File(p.join(docs.path, 'camara_tmp.jpg'))..writeAsStringSync('x');

      final ruta = await db.guardarImagenPermanente(origen.path);

      expect(ruta, startsWith('${LocalDatabase.carpetaImagenes}/chile_'));
      expect(ruta, endsWith('.jpg'));
      expect(p.isAbsolute(ruta), isFalse);
      expect(File(p.joinAll([docs.path, ...ruta.split('/')])).existsSync(), isTrue);
    });

    test('la BD guarda la ruta relativa y al leer se resuelve a absoluta', () async {
      await db.insertarDiagnostico(
        registroFalso().conRutaImagen('fotos_diagnosticos/chile_1.jpg'),
      );

      final crudo = await (await db.database).query('diagnosticos');
      expect(crudo.single['image_path'], 'fotos_diagnosticos/chile_1.jpg');

      final lista = await db.obtenerDiagnosticos();
      expect(
        lista.single.imagePath,
        p.join(docs.path, 'fotos_diagnosticos', 'chile_1.jpg'),
      );
    });

    test('si cambia la carpeta de la app, las fotos se siguen encontrando', () async {
      crearFoto('chile_2.jpg');
      await db.insertarDiagnostico(
        registroFalso().conRutaImagen('fotos_diagnosticos/chile_2.jpg'),
      );
      await db.cerrar();

      // Simula que el sistema movió el contenedor de la app a otra ruta.
      final nuevaCarpeta = Directory.systemTemp.createTempSync('doctor_chile_nueva_');
      addTearDown(() => nuevaCarpeta.deleteSync(recursive: true));
      final destino = Directory(p.join(nuevaCarpeta.path, LocalDatabase.carpetaImagenes))
        ..createSync(recursive: true);
      File(p.join(docs.path, LocalDatabase.carpetaImagenes, 'chile_2.jpg'))
          .copySync(p.join(destino.path, 'chile_2.jpg'));

      final tras = LocalDatabase.conRuta(
        inMemoryDatabasePath,
        directorioDocumentos: () async => nuevaCarpeta.path,
      );
      addTearDown(tras.cerrar);
      // BD en memoria nueva: se reinserta con la misma ruta relativa.
      await tras.insertarDiagnostico(
        registroFalso().conRutaImagen('fotos_diagnosticos/chile_2.jpg'),
      );

      final lista = await tras.obtenerDiagnosticos();
      expect(File(lista.single.imagePath).existsSync(), isTrue);
    });
  });

  group('D-02: eliminar', () {
    test('borra la fila y también la imagen', () async {
      final foto = crearFoto('chile_3.jpg');
      final id = await db.insertarDiagnostico(
        registroFalso().conRutaImagen('fotos_diagnosticos/chile_3.jpg'),
      );

      final registro = (await db.obtenerDiagnosticos()).single;
      final n = await db.eliminarDiagnostico(id, registro.imagePath);

      expect(n, 1);
      expect(await db.obtenerDiagnosticos(), isEmpty);
      expect(foto.existsSync(), isFalse);
    });

    test('tolera que la imagen no exista', () async {
      final id = await db.insertarDiagnostico(registroFalso());
      final n = await db.eliminarDiagnostico(id, '/no/existe.jpg');
      expect(n, 1);
      expect(await db.obtenerDiagnosticos(), isEmpty);
    });

    test('si la fila no existe, no toca la imagen', () async {
      final foto = crearFoto('chile_4.jpg');
      final n = await db.eliminarDiagnostico(999, 'fotos_diagnosticos/chile_4.jpg');
      expect(n, 0);
      expect(foto.existsSync(), isTrue);
    });

    test('si la BD falla, la excepción se propaga y la imagen se conserva', () async {
      final foto = crearFoto('chile_5.jpg');
      final id = await db.insertarDiagnostico(
        registroFalso().conRutaImagen('fotos_diagnosticos/chile_5.jpg'),
      );
      await (await db.database).execute('DROP TABLE diagnosticos'); // fuerza el fallo

      await expectLater(
        db.eliminarDiagnostico(id, 'fotos_diagnosticos/chile_5.jpg'),
        throwsA(isA<Exception>()),
      );
      expect(foto.existsSync(), isTrue);
    });
  });

  group('D-03: imágenes huérfanas', () {
    test('descartarImagen borra el archivo y no falla si no existe', () async {
      final foto = crearFoto('chile_6.jpg');
      await db.descartarImagen('fotos_diagnosticos/chile_6.jpg');
      expect(foto.existsSync(), isFalse);

      await db.descartarImagen('fotos_diagnosticos/no_existe.jpg'); // no lanza
    });

    test('limpiarImagenesHuerfanas conserva solo las referenciadas', () async {
      final usada = crearFoto('chile_usada.jpg');
      final huerfana = crearFoto('chile_huerfana.jpg');
      await db.insertarDiagnostico(
        registroFalso().conRutaImagen('fotos_diagnosticos/chile_usada.jpg'),
      );

      final borradas = await db.limpiarImagenesHuerfanas();

      expect(borradas, 1);
      expect(usada.existsSync(), isTrue);
      expect(huerfana.existsSync(), isFalse);
    });

    test('sin carpeta de fotos no hace nada', () async {
      expect(await db.limpiarImagenesHuerfanas(), 0);
    });
  });

  group('D-06: apertura concurrente', () {
    test('dos accesos simultáneos comparten la misma conexión', () async {
      final r = await Future.wait([db.database, db.database, db.database]);
      expect(identical(r[0], r[1]) && identical(r[1], r[2]), isTrue);
    });
  });

  group('D-07: lectura tolerante', () {
    test('una fila corrupta se omite y el resto del historial se conserva', () async {
      await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 3, 1)));
      await (await db.database).insert('diagnosticos', {
        'image_path': '/x.jpg',
        'disease_key': 'Spot',
        'disease_name': 'Mancha',
        'confidence': 0.5,
        'created_at': 'esto-no-es-una-fecha',
        'estado': 'concluyente',
      });
      await db.insertarDiagnostico(registroFalso(fecha: DateTime(2026, 2, 1)));

      final lista = await db.obtenerDiagnosticos();
      expect(lista, hasLength(2));
    });

    test('tryFromMap devuelve null con campos ausentes o de tipo erróneo', () {
      expect(DiagnosisRecord.tryFromMap({'id': 1}), isNull);
      expect(
        DiagnosisRecord.tryFromMap({
          'image_path': 1, // tipo erróneo
          'disease_key': 'Spot',
          'disease_name': 'M',
          'confidence': 0.5,
          'created_at': DateTime(2026).toIso8601String(),
        }),
        isNull,
      );
    });
  });

  group('migraciones', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('doctor_chile_mig_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    const esquemaV1 = '''
      CREATE TABLE diagnosticos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        disease_key TEXT NOT NULL,
        disease_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''';

    test('v1 → actual: conserva registros, los marca concluyentes y relativiza rutas',
        () async {
      final ruta = p.join(tmp.path, 'v1.db');

      final v1 = await databaseFactory.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) => d.execute(esquemaV1),
        ),
      );
      await v1.insert('diagnosticos', {
        'image_path': '/data/user/0/old/app_flutter/fotos_diagnosticos/vieja.jpg',
        'disease_key': 'Curl',
        'disease_name': 'Hoja Rizada',
        'confidence': 0.91,
        'created_at': DateTime(2025, 12, 1).toIso8601String(),
        'notes': 'antigua',
      });
      await v1.close();

      final migrada = LocalDatabase.conRuta(
        ruta,
        directorioDocumentos: () async => docs.path,
      );
      addTearDown(migrada.cerrar);

      final lista = await migrada.obtenerDiagnosticos();
      expect(lista, hasLength(1));
      expect(lista.first.notes, 'antigua');
      expect(lista.first.estado, EstadoResultado.concluyente);
      expect(lista.first.modelVersion, isNull);
      expect(
        lista.first.imagePath,
        p.join(docs.path, 'fotos_diagnosticos', 'vieja.jpg'),
      );

      // Y acepta registros nuevos con las columnas añadidas.
      await migrada.insertarDiagnostico(
        registroFalso(estado: EstadoResultado.noEsHoja),
      );
      final todos = await migrada.obtenerDiagnosticos(soloConcluyentes: false);
      expect(todos, hasLength(1));
    });

    test('v2 → actual: solo cambia las rutas absolutas y respeta las relativas',
        () async {
      final ruta = p.join(tmp.path, 'v2.db');

      final v2 = await databaseFactory.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (d, _) async {
            await d.execute('''
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
          },
        ),
      );
      Future<void> fila(String path, String fecha) => v2.insert('diagnosticos', {
            'image_path': path,
            'disease_key': 'Spot',
            'disease_name': 'Mancha',
            'confidence': 0.8,
            'created_at': fecha,
            'estado': 'pocaConfianza_no_valida',
          });
      await fila(r'C:\Users\x\fotos_diagnosticos\a.jpg', '2026-01-01T00:00:00');
      await fila('/var/mobile/Containers/UUID-VIEJO/Documents/fotos_diagnosticos/b.jpg',
          '2026-01-02T00:00:00');
      await fila('fotos_diagnosticos/c.jpg', '2026-01-03T00:00:00');
      await v2.close();

      final migrada = LocalDatabase.conRuta(
        ruta,
        directorioDocumentos: () async => docs.path,
      );
      addTearDown(migrada.cerrar);

      final crudo = await (await migrada.database)
          .query('diagnosticos', columns: ['image_path'], orderBy: 'created_at');
      expect(crudo.map((f) => f['image_path']).toList(), [
        'fotos_diagnosticos/a.jpg',
        'fotos_diagnosticos/b.jpg',
        'fotos_diagnosticos/c.jpg',
      ]);
      // Un estado desconocido en BD se trata con cautela, sin romper la lectura.
      final lista = await migrada.obtenerDiagnosticos();
      expect(lista, hasLength(3));
      expect(lista.every((r) => r.estado == EstadoResultado.pocaConfianza), isTrue);
    });
  });
}
