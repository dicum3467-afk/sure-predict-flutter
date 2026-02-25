import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads/ad_service.dart';
import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../state/settings_store.dart';

import 'top_picks_screen.dart';
import 'fixtures_tab.dart';
import 'leagues_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;
  final SettingsStore settingsStore;

  const HomeShell({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
    required this.settingsStore,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  BannerAd? _banner;

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
      case 4:
        return 'Settings';
      default:
        return 'Sure Predict';
    }
  }

  @override
  void initState() {
    super.initState();

    widget.favoritesStore.load();
    widget.settingsStore.load();

    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load();
    }

    // ✅ Banner Ad
    _banner = AdService.instance.createBanner()..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TopPicksScreen(
        service: widget.service,
        favoritesStore: widget.favoritesStore,
        settingsStore: widget.settingsStore,
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
      SettingsScreen(
        settings: widget.settingsStore,
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

      // ✅ Banner + NavigationBar
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_banner != null)
            SizedBox(
              height: 50,
              child: AdWidget(ad: _banner!),
            ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.trending_up), label: 'Top'),
              NavigationDestination(icon: Icon(Icons.sports_soccer), label: 'Fixtures'),
              NavigationDestination(icon: Icon(Icons.public), label: 'Leagues'),
              NavigationDestination(icon: Icon(Icons.star), label: 'Favorites'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}
