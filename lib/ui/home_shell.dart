import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';

import 'fixtures_tab.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'top_picks_tab.dart';

import '../state/settings_store.dart';
import '../state/vip_store.dart';

class HomeShell extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;

  const HomeShell({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final SettingsStore _settingsStore;
  late final VipStore _vipStore;

  @override
  void initState() {
    super.initState();
    _settingsStore = SettingsStore();
    _vipStore = VipStore();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // 0️⃣ Fixtures
      FixturesTab(
        service: widget.service,
        leaguesStore: widget.leaguesStore,
        favoritesStore: widget.favoritesStore,
      ),

      // 1️⃣ ⭐ Top Picks PRO (NOU)
      TopPicksTab(
        service: widget.service,
        leaguesStore: widget.leaguesStore,
        favoritesStore: widget.favoritesStore,
        settings: _settingsStore,
      ),

      // 2️⃣ Favorites
      FavoritesScreen(
        service: widget.service,
        favoritesStore: widget.favoritesStore,
      ),

      // 3️⃣ Settings
      SettingsScreen(
        settings: _settingsStore,
        vipStore: _vipStore,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer),
            label: 'Fixtures',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up),
            label: 'Top Picks',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
