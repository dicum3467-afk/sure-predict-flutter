import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'api/api_client.dart';
import 'services/sure_predict_service.dart';
import 'state/leagues_store.dart';
import 'ui/leagues_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const SurePredictApp());
}

class SurePredictApp extends StatelessWidget {
  const SurePredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(baseUrl: 'https://sure-predict-backend.onrender.com');
    final service = SurePredictService(api);
    final leaguesStore = LeaguesStore(service);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sure Predict',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: LeaguesScreen(store: leaguesStore),
    );
  }
}
