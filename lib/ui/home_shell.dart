// lib/ui/home_shell.dart
import 'package:flutter/material.dart';

import '../state/leagues_store.dart';
import '../state/fixtures_store.dart';
import '../state/favorites_store.dart';

import 'leagues_screen.dart';
import 'favorites_screen.dart';

// ✅ banner widget (cu Ad Unit ID-ul tău în el)
import '../core/ads/banner_ad_widget.dart';

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
      LeaguesScreen(
        store: widget.leaguesStore,
        favorites: widget.favoritesStore,
      ),
      FavoritesScreen(
        fixturesStore: widget.fixturesStore,
        favoritesStore: widget.favoritesStore,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: _pages[_index],
      ),

      // ✅ Navbar + Banner fix jos
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
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

            // 💰 Banner AdMob
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
```0
