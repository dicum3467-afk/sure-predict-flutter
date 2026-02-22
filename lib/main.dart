import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'services/sure_predict_service.dart';
import 'state/leagues_store.dart';
import 'ui/leagues_screen.dart';

void main() {
  runApp(const SurePredictApp());
}

class SurePredictApp extends StatelessWidget {
  const SurePredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api =
        ApiClient(baseUrl: 'https://sure-predict-backend.onrender.com');
    final service = SurePredictService(api);
    final leaguesStore = LeaguesStore(service);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sure Predict',

      // ✅ THEME COMPLET
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),

        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      home: LeaguesScreen(store: leaguesStore),
    );
  }
}
