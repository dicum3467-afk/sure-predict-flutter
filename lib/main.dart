import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'services/sure_predict_service.dart';
import 'state/favorites_store.dart';
import 'state/leagues_store.dart';
import 'ui/home_shell.dart';

void main() {
  runApp(const SurePredictApp());
}

class SurePredictApp extends StatelessWidget {
  const SurePredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(baseUrl: 'https://sure-predict-backend.onrender.com');
    final service = SurePredictService(api);

    final leaguesStore = LeaguesStore(service);
    final favoritesStore = FavoritesStore();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sure Predict',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: HomeShell(
        service: service,
        leaguesStore: leaguesStore,
        favoritesStore: favoritesStore,
      ),
    );
  }
}
