import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/fixture_card.dart';
import '../widgets/league_filter_chip.dart';
import '../widgets/section_title.dart';

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key});

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String? error;
  String selectedLeague = 'All';
  String search = '';
  List<FixtureUiModel> fixtures = [];

  final Map<String, String> leagueMap = const {
    'All': 'All',
    'Premier League': '39',
    'LaLiga': '140',
    'Serie A': '135',
    'Bundesliga': '78',
    'Ligue 1': '61',
  };

  @override
  void initState() {
    super.initState();
    _loadFixtures();
  }

  Future<void> _loadFixtures() async {
    try {
      final providerLeagueId = leagueMap[selectedLeague];
      final data = await _apiService.getFixtures(
        page: 1,
        perPage: 100,
        providerLeagueId: providerLeagueId == 'All' ? null : providerLeagueId,
        search: search,
      );

      if (!mounted) return;
      setState(() {
        fixtures = data;
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
    final leagues = leagueMap.keys.toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                const SectionTitle(
                  title: 'Fixtures',
                  subtitle: 'Browse all upcoming matches',
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search teams or leagues',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    search = value;
                    _loadFixtures();
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: leagues.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final league = leagues[index];
                return LeagueFilterChip(
                  label: league,
                  selected: selectedLeague == league,
                  onTap: () {
                    setState(() {
                      selectedLeague = league;
                      isLoading = true;
                    });
                    _loadFixtures();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFixtures,
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
                      : fixtures.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text('No fixtures found.'),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: fixtures.length,
                              itemBuilder: (_, index) {
                                final fixture = fixtures[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: FixtureCard(fixture: fixture),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
