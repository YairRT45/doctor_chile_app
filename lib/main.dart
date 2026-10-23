import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/database/local_database.dart';
import 'core/errors/app_errors.dart';
import 'features/diagnosis/presentation/home_screen.dart';
import 'features/history/presentation/history_screen.dart';

/// Idioma único de la aplicación por ahora (español de México).
const Locale localeApp = Locale('es', 'MX');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Formatos de fecha/hora en español (calendario, historial).
  await initializeDateFormatting('es_MX');
  Intl.defaultLocale = 'es_MX';

  runApp(const DoctorChileApp());

  // Limpia fotos que ningún diagnóstico referencia (p. ej. copias de un guardado
  // que falló). Se hace al iniciar, antes de que el usuario pueda guardar algo.
  unawaited(
    LocalDatabase.instance.limpiarImagenesHuerfanas().then<void>(
      (_) {},
      onError: (Object e, StackTrace st) {
        registrarError(e, st, 'Limpieza de imágenes huérfanas');
      },
    ),
  );
}

class DoctorChileApp extends StatelessWidget {
  const DoctorChileApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colorSemilla = Color(0xFF15803D); // Verde agrícola principal

    return MaterialApp(
      title: 'Doctor Chile',
      debugShowCheckedModeBanner: false,
      // La app está solo en español: calendario, botones del sistema y
      // formatos salen en español sin depender del idioma del teléfono.
      locale: localeApp,
      supportedLocales: const [localeApp, Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorSemilla,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: colorSemilla,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      // Por ahora solo hay tema claro (los colores de las pantallas son fijos);
      // se mantiene aunque el teléfono esté en modo oscuro.
      themeMode: ThemeMode.light,
      home: const _MainNavigationWrapper(),
    );
  }
}

class _MainNavigationWrapper extends StatelessWidget {
  const _MainNavigationWrapper();

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      onAbrirHistorial: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const HistoryScreen(),
          ),
        );
      },
    );
  }
}
