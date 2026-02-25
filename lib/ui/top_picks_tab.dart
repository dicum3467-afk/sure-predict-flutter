import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../state/settings_store.dart';
import 'top_picks_screen.dart';

class TopPicksTab extends StatelessWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;
  final SettingsStore settings;

  const TopPicksTab({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return TopPicksScreen(
      service: service,
      leaguesStore: leaguesStore,
      favoritesStore: favoritesStore,
      settings: settings,
    );
  }
}
