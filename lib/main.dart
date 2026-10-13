import 'package:flutter/material.dart';

import 'features/diagnosis/presentation/home_screen.dart';
import 'features/history/presentation/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DoctorChileApp());
}

class DoctorChileApp extends StatelessWidget {
  const DoctorChileApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colorSemilla = Color(0xFF15803D); // Verde agrícola principal

    return MaterialApp(
      title: 'Doctor Chile',
      debugShowCheckedModeBanner: false,
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
