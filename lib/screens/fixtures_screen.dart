import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../widgets/fixture_card.dart';
import '../widgets/league_filter_chip.dart';
import '../widgets/section_title.dart';

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key});

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  String selectedLeague = 'All';
  String search = '';

  List<FixtureUiModel> get filteredFixtures {
    return MockData.fixtures.where((fixture) {
      final byLeague =
          selectedLeague == 'All' || fixture.leagueName == selectedLeague;

      final q = search.toLowerCase();
      final bySearch = q.isEmpty ||
          fixture.homeTeam.toLowerCase().contains(q) ||
          fixture.awayTeam.toLowerCase().contains(q) ||
          fixture.leagueName.toLowerCase().contains(q);

      return byLeague && bySearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fixtures = filteredFixtures;

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
                    setState(() {
                      search = value;
                    });
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
              itemBuilder: (_, index) {
                final league = MockData.leagues[index];
                return LeagueFilterChip(
                  label: league,
                  selected: selectedLeague == league,
                  onTap: () {
                    setState(() {
                      selectedLeague = league;
                    });
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: MockData.leagues.length,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
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
        ],
      ),
    );
  }
}
