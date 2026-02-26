import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../screens/fixtures_screen.dart';

class FixturesTab extends StatelessWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;

  const FixturesTab({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
  });

  @override
  Widget build(BuildContext context) {
    final ids = leaguesStore.selectedIds.toList();

    return FixturesScreen(
      service: service,
      favoritesStore: favoritesStore,
      leagueIds: ids, // ✅ fix: există acum în FixturesScreen
    );
  }
}
