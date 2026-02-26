import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../screens/fixtures_screen.dart';

class FixturesTab extends StatefulWidget {
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
  State<FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<FixturesTab> {
  @override
  void initState() {
    super.initState();
    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load();
    }
  }

  List<String> _allLeagueIds() {
    final ids = <String>[];
    for (final l in widget.leaguesStore.items) {
      final v = l['id'] ?? l['league_id'] ?? l['leagueId'];
      final id = (v ?? '').toString();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    // Așteptăm ligile
    if (widget.leaguesStore.isLoading && widget.leaguesStore.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final ids = _allLeagueIds(); // ✅ goal => all leagues

    if (ids.isEmpty) {
      return const Center(child: Text('No leagues loaded'));
    }

    return FixturesScreen(
      service: widget.service,
      favoritesStore: widget.favoritesStore,
      leagueIds: ids,
    );
  }
}
