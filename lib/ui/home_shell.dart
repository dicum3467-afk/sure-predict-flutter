import 'package:flutter/material.dart';

import '../state/leagues_store.dart';
import '../state/fixtures_store.dart';
import '../state/favorites_store.dart';
import '../ui/leagues_screen.dart';
import '../ui/favorites_screen.dart';
import '../ads/banner_ad_widget.dart';

class HomeShell extends StatefulWidget {
  final LeaguesStore leaguesStore;
  final FixturesStore fixturesStore;
  final FavoritesStore favoritesStore;

  const HomeShell({
    super.key,
    required this.leaguesStore,
    required this.fixturesStore,
    required this.favoritesStore,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      // 🟢 TAB 1 — LEAGUES
      LeaguesScreen(
        store: widget.leaguesStore,
        favorites: widget.favoritesStore,
      ),

      // ⭐ TAB 2 — FAVORITES
      FavoritesScreen(
        fixturesStore: widget.fixturesStore,
        favoritesStore: widget.favoritesStore,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],

      // 🔥 NAV + ADS
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.sports_soccer),
                label: 'Leagues',
              ),
              NavigationDestination(
                icon: Icon(Icons.star),
                label: 'Favorites',
              ),
            ],
          ),

          // 💰 ADMOB BANNER
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
