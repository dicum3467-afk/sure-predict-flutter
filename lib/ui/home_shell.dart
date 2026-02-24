import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';

import 'fixtures_tab.dart';
import 'leagues_screen.dart';
import 'favorites_screen.dart';

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

  String get _title {
    switch (_index) {
      case 0:
        return 'Fixtures';
      case 1:
        return 'Leagues';
      case 2:
        return 'Favorites';
      default:
        return 'Sure Predict';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      FixturesTab(
        service: widget.service,
        leaguesStore: widget.leaguesStore,
      ),
      LeaguesScreen(
        service: widget.service,
        leaguesStore: widget.leaguesStore,
      ),
      FavoritesScreen(
        service: widget.service,
        favoritesStore: widget.favoritesStore,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await widget.leaguesStore.refresh();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer),
            label: 'Fixtures',
          ),
          NavigationDestination(
            icon: Icon(Icons.public),
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
