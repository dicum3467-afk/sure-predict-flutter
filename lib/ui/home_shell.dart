import 'package:flutter/material.dart';

import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../state/fixtures_store.dart';
import 'leagues_screen.dart';
import 'favorites_screen.dart';

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
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      LeaguesScreen(
        store: widget.leaguesStore,
        favorites: widget.favoritesStore,
      ),
      FavoritesScreen(
        fixturesStore: widget.fixturesStore,
        favoritesStore: widget.favoritesStore,
      ),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
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
    );
  }
}
