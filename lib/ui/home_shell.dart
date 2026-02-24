import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';
import '../state/leagues_store.dart';

import 'favorites_screen.dart';
import 'leagues_screen.dart';
import 'fixtures_tab.dart';

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

  @override
  void initState() {
    super.initState();
    widget.favoritesStore.load();
    _warmUpBackend();
  }

  Future<void> _warmUpBackend() async {
    try {
      await widget.service.health();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      LeaguesScreen(store: widget.leaguesStore, service: widget.service),
      FixturesTab(service: widget.service, leaguesStore: widget.leaguesStore),
      FavoritesScreen(store: widget.favoritesStore),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_soccer), label: 'Leagues'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Fixtures'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Favorites'),
        ],
      ),
    );
  }
}
