import 'package:doctor_chile_app/core/constants/chili_classes.dart';
import 'package:doctor_chile_app/core/errors/app_errors.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/diagnosis_record.dart';
import 'package:doctor_chile_app/features/diagnosis/domain/estado_resultado.dart';
import 'package:doctor_chile_app/features/diagnosis/presentation/home_screen.dart';
import 'package:doctor_chile_app/features/diagnosis/presentation/result_screen.dart';
import 'package:doctor_chile_app/features/history/presentation/detail_screen.dart';
import 'package:doctor_chile_app/features/history/presentation/history_screen.dart';
import 'package:doctor_chile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

const _descargo = 'Resultado orientativo generado por un modelo automático.';

Future<void> _pantallaGrande(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  group('HomeScreen', () {
    testWidgets('muestra acciones principales y el descargo', (tester) async {
      await _pantallaGrande(tester);
      final clasificador = FakeClassifier();
      await tester.pumpWidget(
        _app(HomeScreen(onAbrirHistorial: () {}, clasificador: clasificador)),
      );

      expect(find.text('Hacer Diagnóstico (Cámara)'), findsOneWidget);
      expect(find.text('Subir Foto desde Galería'), findsOneWidget);
      expect(find.textContaining(_descargo), findsOneWidget);
      expect(clasificador.inicializaciones, 1);
    });

    testWidgets('un fallo al precargar el modelo no rompe la pantalla', (tester) async {
      await _pantallaGrande(tester);
      final clasificador = FakeClassifier()
        ..errorAlInicializar = const ModeloNoDisponibleError(detalle: 'x');
      await tester.pumpWidget(
        _app(HomeScreen(onAbrirHistorial: () {}, clasificador: clasificador)),
      );
      await tester.pump();

      expect(find.text('Hacer Diagnóstico (Cámara)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ResultScreen — presentación', () {
    testWidgets('concluyente: diagnóstico firme y guardar como acción principal',
        (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.concluyente),
        repositorio: FakeRepository(),
      )));

      expect(find.text('AFECCIÓN DETECTADA'), findsOneWidget);
      // Aparece en el título y también en la barra de probabilidades.
      expect(find.text('Mancha Foliar'), findsWidgets);
      expect(find.text('Guardar Diagnóstico'), findsOneWidget);
      expect(find.text('Intentar con otra foto'), findsNothing);
      expect(find.textContaining(_descargo), findsOneWidget);
    });

    testWidgets('poca confianza: se presenta como "no concluyente"', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.pocaConfianza, confianza: 0.4),
        repositorio: FakeRepository(),
      )));

      expect(find.text('RESULTADO NO CONCLUYENTE'), findsOneWidget);
      expect(find.text('Posible: Mancha Foliar'), findsOneWidget);
      expect(find.text('AFECCIÓN DETECTADA'), findsNothing);
      expect(find.text('Advertencia de prueba'), findsOneWidget);
      // La acción principal es repetir la foto; guardar es secundaria.
      expect(find.text('Intentar con otra foto'), findsOneWidget);
      expect(find.text('Guardar de todos modos (queda marcado)'), findsOneWidget);
      expect(find.text('Guardar Diagnóstico'), findsNothing);
    });

    testWidgets('no es hoja: no muestra enfermedad ni probabilidades', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.noEsHoja, confianza: 0.9),
        repositorio: FakeRepository(),
      )));

      expect(find.text('NO PARECE UNA HOJA DE CHILE'), findsOneWidget);
      expect(find.text('Sin diagnóstico fiable'), findsOneWidget);
      expect(find.text('AFECCIÓN DETECTADA'), findsNothing);
      expect(find.text('Mancha Foliar'), findsNothing);
      expect(find.textContaining('Probabilidad por afección'), findsNothing);
    });
  });

  group('ResultScreen — guardado con etiqueta', () {
    testWidgets('concluyente se guarda como concluyente con versión de modelo',
        (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository();
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.concluyente),
        repositorio: repo,
      )));

      await tester.tap(find.text('Guardar Diagnóstico'));
      await tester.pumpAndSettle();

      expect(repo.guardados, hasLength(1));
      expect(repo.guardados.first.estado, EstadoResultado.concluyente);
      expect(repo.guardados.first.modelVersion, 'test-model');
      expect(find.text('Diagnóstico guardado en el historial'), findsOneWidget);
    });

    testWidgets('poca confianza se guarda marcada como no concluyente', (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository();
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.pocaConfianza, confianza: 0.4),
        repositorio: repo,
      )));

      await tester.tap(find.text('Guardar de todos modos (queda marcado)'));
      await tester.pumpAndSettle();

      expect(repo.guardados, hasLength(1));
      expect(repo.guardados.first.estado, EstadoResultado.pocaConfianza);
    });

    testWidgets('no es hoja pide confirmación; cancelar no guarda', (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository();
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.noEsHoja),
        repositorio: repo,
      )));

      await tester.tap(find.text('Guardar de todos modos (queda marcado)'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar de todos modos'), findsOneWidget); // título del diálogo

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.guardados, isEmpty);
    });

    testWidgets('no es hoja: confirmar guarda con estado no_es_hoja', (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository();
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.noEsHoja),
        repositorio: repo,
      )));

      await tester.tap(find.text('Guardar de todos modos (queda marcado)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.guardados, hasLength(1));
      expect(repo.guardados.first.estado, EstadoResultado.noEsHoja);
    });

    testWidgets('D-03: si falla el insert se descarta la foto copiada y se avisa sin jerga',
        (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository()..fallarAlInsertar = true;
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.concluyente),
        repositorio: repo,
      )));

      await tester.tap(find.text('Guardar Diagnóstico'));
      await tester.pumpAndSettle();

      expect(repo.imagenesDescartadas, ['fotos_diagnosticos/foto.jpg']);
      expect(repo.guardados, isEmpty);
      expect(find.textContaining('No se pudo guardar el diagnóstico'), findsOneWidget);
      expect(find.textContaining('SQLITE_SECRETO'), findsNothing);
      // Se puede reintentar: el botón vuelve a estar activo.
      expect(find.text('Guardar Diagnóstico'), findsOneWidget);
    });
  });

  group('HistoryScreen', () {
    testWidgets('muestra insignia y título según la fiabilidad', (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository(datos: [
        registroFalso(id: 1),
        registroFalso(id: 2, estado: EstadoResultado.pocaConfianza),
        registroFalso(id: 3, estado: EstadoResultado.noEsHoja),
      ]);
      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Mancha Foliar'), findsOneWidget); // solo el concluyente
      expect(find.text('Posible: Mancha Foliar'), findsOneWidget);
      expect(find.text('Sin diagnóstico fiable'), findsOneWidget);
      expect(find.text('No concluyente'), findsOneWidget);
      expect(find.text('No parece una hoja'), findsOneWidget);
    });

    testWidgets('el filtro de fiabilidad consulta solo no concluyentes', (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository(datos: [
        registroFalso(id: 1),
        registroFalso(id: 2, estado: EstadoResultado.pocaConfianza),
      ]);
      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Todos los resultados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solo no concluyentes').last);
      await tester.pumpAndSettle();

      expect(repo.ultimoFiltroConcluyentes, isFalse);
      expect(find.text('Posible: Mancha Foliar'), findsOneWidget);
      expect(find.text('Mancha Foliar'), findsNothing);
    });

    testWidgets('un error de BD muestra mensaje amigable, no la excepción',
        (tester) async {
      await _pantallaGrande(tester);
      final repo = _RepoQueFalla();
      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
      expect(find.textContaining('SQLITE_SECRETO'), findsNothing);
    });
  });

  group('DetailScreen', () {
    testWidgets('clave desconocida no se muestra como "Hoja Sana"', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(_app(DetailScreen(
        registro: registroFalso(id: 5, key: 'Xyz', nombre: 'Clase vieja'),
        repositorio: FakeRepository(),
      )));

      expect(find.text('Hoja Sana'), findsNothing);
      expect(find.textContaining('no reconoce'), findsOneWidget);
      expect(find.textContaining(_descargo), findsOneWidget);
    });

    testWidgets('no es hoja: sin síntomas y con insignia', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(_app(DetailScreen(
        registro: registroFalso(id: 6, estado: EstadoResultado.noEsHoja),
        repositorio: FakeRepository(),
      )));

      expect(find.text('Sin diagnóstico fiable'), findsOneWidget);
      expect(find.text('No parece una hoja'), findsOneWidget);
      expect(find.textContaining('síntomas'), findsNothing);
    });

    testWidgets('D-02: un fallo al eliminar muestra mensaje amigable y no cierra la pantalla',
        (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository()..fallarAlEliminar = true;
      await tester.pumpWidget(_app(DetailScreen(
        registro: registroFalso(id: 7),
        repositorio: repo,
      )));

      await tester.tap(find.byTooltip('Eliminar diagnóstico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo eliminar'), findsOneWidget);
      expect(find.textContaining('SQLITE_SECRETO'), findsNothing);
      expect(find.text('Diagnóstico #7'), findsOneWidget); // sigue en el detalle
      expect(repo.eliminados, isEmpty);
    });
  });

  group('ResultScreen — salida sin guardar (U-06)', () {
    Widget lanzador(Widget Function() pantalla) => MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(builder: (_) => pantalla()),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        );

    Future<void> abrir(WidgetTester tester) async {
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('con el resultado sin guardar, atrás pide confirmación', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(lanzador(() => ResultScreen(
            imagePath: '/no/existe.jpg',
            resultado: resultadoFalso(EstadoResultado.concluyente),
            repositorio: FakeRepository(),
          )));
      await abrir(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('aún no está guardado'), findsOneWidget);

      // "Seguir aquí" se queda en el resultado.
      await tester.tap(find.text('Seguir aquí'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado del Diagnóstico'), findsOneWidget);

      // "Salir sin guardar" regresa a la pantalla anterior.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salir sin guardar'));
      await tester.pumpAndSettle();
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('"Realizar otro diagnóstico" también pide confirmación si no se guardó',
        (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(lanzador(() => ResultScreen(
            imagePath: '/no/existe.jpg',
            resultado: resultadoFalso(EstadoResultado.concluyente),
            repositorio: FakeRepository(),
          )));
      await abrir(tester);

      await tester.tap(find.text('Realizar otro diagnóstico'));
      await tester.pumpAndSettle();
      expect(find.textContaining('aún no está guardado'), findsOneWidget);
    });

    testWidgets('una vez guardado se sale sin preguntar', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(lanzador(() => ResultScreen(
            imagePath: '/no/existe.jpg',
            resultado: resultadoFalso(EstadoResultado.concluyente),
            repositorio: FakeRepository(),
          )));
      await abrir(tester);

      await tester.tap(find.text('Guardar Diagnóstico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Realizar otro diagnóstico'));
      await tester.pumpAndSettle();

      expect(find.textContaining('aún no está guardado'), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('"Intentar con otra foto" descarta un resultado dudoso sin preguntar',
        (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(lanzador(() => ResultScreen(
            imagePath: '/no/existe.jpg',
            resultado: resultadoFalso(EstadoResultado.pocaConfianza, confianza: 0.4),
            repositorio: FakeRepository(),
          )));
      await abrir(tester);

      await tester.tap(find.text('Intentar con otra foto'));
      await tester.pumpAndSettle();

      expect(find.textContaining('aún no está guardado'), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('"Ver historial" aparece solo después de guardar', (tester) async {
      await _pantallaGrande(tester);
      var aperturas = 0;
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.concluyente),
        repositorio: FakeRepository(),
        onVerHistorial: () => aperturas++,
      )));

      expect(find.text('Ver historial'), findsNothing);

      await tester.tap(find.text('Guardar Diagnóstico'));
      await tester.pumpAndSettle();
      expect(find.text('Ver historial'), findsOneWidget);

      await tester.tap(find.text('Ver historial'));
      expect(aperturas, 1);
    });
  });

  group('Textos de interfaz (U-03, U-09)', () {
    testWidgets('el desglose usa lenguaje llano, sin nombres del modelo', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(_app(ResultScreen(
        imagePath: '/no/existe.jpg',
        resultado: resultadoFalso(EstadoResultado.concluyente),
        repositorio: FakeRepository(),
      )));

      expect(find.text('Probabilidad por afección'), findsOneWidget);
      expect(find.textContaining('YOLO'), findsNothing);
    });

    testWidgets('Home no muestra jerga técnica', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(
        _app(HomeScreen(onAbrirHistorial: () {}, clasificador: FakeClassifier())),
      );

      expect(find.textContaining('YOLO'), findsNothing);
      expect(find.text('Afecciones que puede identificar la aplicación:'), findsOneWidget);
    });

    testWidgets('Historial y Detalle no muestran códigos del SRS', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(_app(HistoryScreen(repositorio: FakeRepository())));
      await tester.pumpAndSettle();
      expect(find.text('Filtrar por afección'), findsOneWidget);
      expect(find.text('Filtrar por rango de fechas'), findsOneWidget);
      expect(find.textContaining('FN.1'), findsNothing);
      expect(find.textContaining('FA.1'), findsNothing);

      await tester.pumpWidget(_app(DetailScreen(
        registro: registroFalso(id: 9),
        repositorio: FakeRepository(),
      )));
      expect(find.text('ID de registro: #9'), findsOneWidget);
      expect(find.textContaining('BR-01'), findsNothing);
    });
  });

  group('DoctorChileApp (U-04, U-07)', () {
    testWidgets('está en español y solo ofrece tema claro', (tester) async {
      await _pantallaGrande(tester);
      await tester.pumpWidget(const DoctorChileApp());
      await tester.pump();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      expect(app.locale, localeApp);

      final contexto = tester.element(find.byType(Scaffold).first);
      expect(Localizations.localeOf(contexto).languageCode, 'es');
      // El calendario y los botones del sistema salen en español.
      expect(MaterialLocalizations.of(contexto).cancelButtonLabel, 'Cancelar');
      expect(MaterialLocalizations.of(contexto).okButtonLabel, 'ACEPTAR');
    });
  });

  group('HistoryScreen — rendimiento (Fase 4)', () {
    List<DiagnosisRecord> muchos(int n) => [
          for (var i = 1; i <= n; i++)
            registroFalso(id: i, fecha: DateTime(2026, 1, 1).add(Duration(hours: n - i))),
        ];

    testWidgets('carga 30 al abrir y pide más páginas al desplazarse hasta el final',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeRepository(datos: muchos(70));
      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pumpAndSettle();

      expect(repo.consultas, [(limite: 30, offset: 0)]);

      final lista = find.byType(ListView);
      for (var i = 0; i < 12; i++) {
        await tester.drag(lista, const Offset(0, -1500));
        await tester.pumpAndSettle();
      }

      final offsets = repo.consultas.map((c) => c.offset).toList();
      expect(offsets, containsAllInOrder([0, 30, 60]));
      expect(offsets.toSet().length, offsets.length); // ninguna página repetida
      expect(find.textContaining('ID #70  •'), findsOneWidget); // llegó hasta el final

      // Agotados los datos, desplazarse más no vuelve a consultar.
      final total = repo.consultas.length;
      await tester.drag(lista, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(repo.consultas.length, total);
    });

    testWidgets('una lista corta no pide páginas adicionales', (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository(datos: muchos(5));
      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pumpAndSettle();

      expect(repo.consultas, hasLength(1));
      expect(find.textContaining('ID #5  •'), findsOneWidget);
    });

    testWidgets('U-12: una respuesta vieja no pisa a la consulta más reciente',
        (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository(datos: [
        registroFalso(id: 1), // concluyente
        registroFalso(id: 2, estado: EstadoResultado.pocaConfianza),
      ])
        // La primera consulta (sin filtro) tarda; la segunda responde al instante.
        ..retardoPorConsulta = (n) => n == 1 ? const Duration(milliseconds: 500) : null;

      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pump(const Duration(milliseconds: 50));

      // El usuario cambia el filtro mientras la primera consulta sigue en curso.
      await tester.tap(find.text('Todos los resultados'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Solo concluyentes').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mancha Foliar'), findsOneWidget);
      expect(find.text('Posible: Mancha Foliar'), findsNothing);

      // Llega tarde la respuesta de la consulta vieja (que incluía el dudoso):
      // debe ignorarse.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Mancha Foliar'), findsOneWidget);
      expect(find.text('Posible: Mancha Foliar'), findsNothing);
    });

    testWidgets('las miniaturas se decodifican al tamaño del avatar, no a la foto completa',
        (tester) async {
      await _pantallaGrande(tester); // devicePixelRatio = 1.0
      final repo = FakeRepository(datos: [registroFalso(id: 1)]);
      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pumpAndSettle();

      final imagen = tester.widget<Image>(find.byType(Image).first);
      expect(imagen.image, isA<ResizeImage>());
      expect((imagen.image as ResizeImage).width, 58);
    });

    testWidgets('si la foto falta o no se puede leer, el errorBuilder dibuja el marcador',
        (tester) async {
      await _pantallaGrande(tester);
      final repo = FakeRepository(datos: [registroFalso(id: 1)]);
      await tester.pumpWidget(_app(HistoryScreen(repositorio: repo)));
      await tester.pumpAndSettle();

      // Ya no se consulta el sistema de archivos al construir la fila (antes
      // existsSync): la miniatura delega el fallo en el errorBuilder de Image.
      final finderImagen = find.byType(Image).first;
      final imagen = tester.widget<Image>(finderImagen);
      expect(imagen.errorBuilder, isNotNull);

      // Se invoca el errorBuilder tal como lo haría Image ante una lectura fallida.
      final marcador = imagen.errorBuilder!(
        tester.element(finderImagen),
        Exception('no se pudo leer'),
        StackTrace.empty,
      );
      await tester.pumpWidget(_app(Scaffold(body: marcador)));

      expect(find.byIcon(ChiliClasses.todas[2].icono), findsOneWidget); // ícono de "Spot"
      expect(tester.takeException(), isNull);
    });
  });
}

class _RepoQueFalla extends FakeRepository {
  @override
  Future<List<DiagnosisRecord>> obtenerDiagnosticos({
    String? diseaseKey,
    bool? soloConcluyentes,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? limite,
    int offset = 0,
  }) async {
    throw Exception('SQLITE_SECRETO: database is locked');
  }
}
