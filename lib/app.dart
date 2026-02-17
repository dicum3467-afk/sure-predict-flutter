import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'screens/home_screen.dart';

class SurePredictApp extends StatelessWidget {
  const SurePredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sure Predict',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),

      // ✅ Delegates core + delegate-ul tău
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ✅ RO + EN (fără AppL10n.supportedLocales)
      supportedLocales: const [
        Locale('ro'),
        Locale('en'),
      ],

      home: const HomeScreen(),
    );
  }
}
