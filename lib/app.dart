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
      theme: ThemeData.dark(useMaterial3: true),

      // IMPORTANT: delegate-ul nostru trebuie să fie primul
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
