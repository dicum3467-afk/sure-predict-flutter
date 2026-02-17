import 'package:flutter/material.dart';
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
      localizationsDelegates: const [
        AppL10n.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: const HomeScreen(),
    );
  }
}
