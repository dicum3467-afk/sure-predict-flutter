import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';

import '../ui/fixtures_tab.dart';
import '../screens/top_picks_screen.dart';
import '../screens/home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final ApiClient _api;
  late final SurePredictService _service;
  late final LeaguesStore _leaguesStore;

  int _index = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _api = ApiClient(
      baseUrl: 'https://sure-predict-backend.onrender.com',
    );

    _service = SurePredictService(_api);
    _leaguesStore = LeaguesStore(_service);

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _leaguesStore.load();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<String> _allLeagueIds() {
    return _leaguesStore.items
        .map((e) => (e['id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<String, String> _leagueNamesById() {
    final Map<String, String> out = {};
    for (final l in _leaguesStore.items) {
      final id = (l['id'] ?? '').toString();
      final name = (l['name'] ?? '').toString();
      if (id.isNotEmpty && name.isNotEmpty) out[id] = name;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sure Predict')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Eroare la încărcarea ligilor:\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _bootstrap,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = <Widget>[
      const HomeScreen(),
      FixturesTab(
        service: _service,
        leaguesStore: _leaguesStore,
      ),
      TopPicksScreen(
        service: _service,
        leagueIds: _allLeagueIds(), // ✅ TOATE ligile
        leagueNamesById: _leagueNamesById(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Fixtures',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Top',
          ),
        ],
      ),
    );
  }
}
