import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../state/settings_store.dart';
import 'settings_screen.dart';
import 'top_picks_screen.dart';
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
        return 'Top Picks';
      case 1:
        return 'Fixtures';
      case 2:
        return 'Leagues';
      case 3:
        return 'Favorites';
      default:
        return 'Sure Predict';
    }
  }

  @override
  void initState() {
    super.initState();
    widget.favoritesStore.load();
    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TopPicksScreen(
        service: widget.service,
        favoritesStore: widget.favoritesStore,
      ),
      FixturesTab(
        service: widget.service,
        leaguesStore: widget.leaguesStore,
        favoritesStore: widget.favoritesStore,
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
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Top'),
          NavigationDestination(icon: Icon(Icons.sports_soccer), label: 'Fixtures'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Leagues'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Favorites'),
        ],
      ),
    );
  }
}
