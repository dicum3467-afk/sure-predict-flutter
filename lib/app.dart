import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'screens/home_screen.dart';

class SurePredictApp extends StatelessWidget {
  const SurePredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sure Predict',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF070A12),
        colorScheme: base.colorScheme.copyWith(
          primary: const Color(0xFFB7A6FF),
          secondary: const Color(0xFF6EE7FF),
          surface: const Color(0xFF0D1220),
        ),
        textTheme: base.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: const HomeScreen(),
    );
  }
}
