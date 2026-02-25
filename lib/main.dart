import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/sure_predict_service.dart';

import 'state/leagues_store.dart';
import 'state/favorites_store.dart';

import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const baseUrl = 'https://sure-predict-backend.onrender.com';

  final api = ApiClient(baseUrl: baseUrl);
  final service = SurePredictService(api);

  final leaguesStore = LeaguesStore(service);
  final favoritesStore = FavoritesStore();

  runApp(SurePredictApp(
    service: service,
    leaguesStore: leaguesStore,
    favoritesStore: favoritesStore,
  ));
}

class SurePredictApp extends StatelessWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;

  const SurePredictApp({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sure Predict',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: HomeShell(
        service: service,
        leaguesStore: leaguesStore,
        favoritesStore: favoritesStore,
      ),
    );
  }
}
