import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';

class SurePredictApp extends StatefulWidget {
  const SurePredictApp({super.key});
  @override
  State<SurePredictApp> createState() => _SurePredictAppState();
}

class _SurePredictAppState extends State<SurePredictApp> {
  Locale? _locale;
  void _setLocale(Locale? locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sure Predict',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('ro'), Locale('en')],
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00FF9C),
      ),
      home: HomeScreen(onChangeLanguage: _setLocale),
    );
  }
}
