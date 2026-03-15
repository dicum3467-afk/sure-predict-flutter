import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/fixture_card.dart';
import '../widgets/section_title.dart';
import '../widgets/top_pick_card.dart';
import 'fixtures_screen.dart';
import 'predictions_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _DashboardTab(),
    FixturesScreen(),
    PredictionsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Predictions',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String? error;
  List<TopPickUiModel> topPicks = [];
  List<FixtureUiModel> fixtures = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _loadData() async {
    try {
      final fixturesData = await _apiService.getFixtures(page: 1, perPage: 10);
      final topPicksData =
          await _apiService.getTopPicksFromPredictions(limit: 5);

      if (!mounted) return;

      setState(() {
        fixtures = fixturesData.take(5).toList();
        topPicks = topPicksData;
        isLoading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        _greeting(),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Find the best football predictions and match analysis.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle(
                        title: 'Top Picks',
                        subtitle: 'Highest confidence selections',
                      ),
                      const SizedBox(height: 12),
                      if (topPicks.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No top picks available yet.'),
                          ),
                        )
                      else
                        ...topPicks.map(
                          (pick) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TopPickCard(pick: pick),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const SectionTitle(
                        title: 'Upcoming Matches',
                        subtitle: 'Next fixtures to analyze',
                      ),
                      const SizedBox(height: 12),
                      if (fixtures.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No upcoming fixtures available.'),
                          ),
                        )
                      else
                        ...fixtures.map(
                          (fixture) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FixtureCard(fixture: fixture),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
