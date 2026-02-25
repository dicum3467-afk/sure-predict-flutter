import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/ads/ad_service.dart';
import 'services/sure_predict_service.dart';

import 'state/leagues_store.dart';
import 'state/favorites_store.dart';
import 'state/settings_store.dart';
import 'state/vip_store.dart';

import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdService.instance.init();

  final apiClient = ApiClient(
    baseUrl: 'https://sure-predict-backend.onrender.com',
  );

  final service = SurePredictService(apiClient);

  final leaguesStore = LeaguesStore(service);
  final favoritesStore = FavoritesStore();
  final settingsStore = SettingsStore();
  final vipStore = VipStore();

  runApp(
    SurePredictApp(
      service: service,
      leaguesStore: leaguesStore,
      favoritesStore: favoritesStore,
      settingsStore: settingsStore,
      vipStore: vipStore,
    ),
  );
}

class SurePredictApp extends StatelessWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;
  final SettingsStore settingsStore;
  final VipStore vipStore;

  const SurePredictApp({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
    required this.settingsStore,
    required this.vipStore,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sure Predict',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: HomeShell(
        service: service,
        leaguesStore: leaguesStore,
        favoritesStore: favoritesStore,
        settingsStore: settingsStore,
        vipStore: vipStore,
      ),
    );
  }
}
