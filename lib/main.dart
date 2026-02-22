import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'api/api_client.dart';
import 'services/sure_predict_service.dart';
import 'state/leagues_store.dart';
import 'state/fixtures_store.dart';
import 'state/favorites_store.dart';
import 'ui/home_shell.dart';

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
    final fixturesStore = FixturesStore(service);
    final favoritesStore = FavoritesStore();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sure Predict',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      ),
      home: HomeShell(
        leaguesStore: leaguesStore,
        fixturesStore: fixturesStore,
        favoritesStore: favoritesStore,
      ),
    );
  }
}
