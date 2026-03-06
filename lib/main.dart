import 'package:flutter/material.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const SurePredictApp());
}

class SurePredictApp extends StatelessWidget {
  const SurePredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sure Predict',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}
