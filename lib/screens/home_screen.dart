import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../widgets/fixture_card.dart';
import '../widgets/section_title.dart';
import '../widgets/top_pick_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final fixtures = MockData.fixtures.take(3).toList();
    final topPicks = MockData.topPicks;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _greeting(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
          ...topPicks.map((pick) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TopPickCard(pick: pick),
              )),
          const SizedBox(height: 12),
          const SectionTitle(
            title: 'Upcoming Matches',
            subtitle: 'Next fixtures to analyze',
          ),
          const SizedBox(height: 12),
          ...fixtures.map((fixture) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FixtureCard(fixture: fixture),
              )),
        ],
      ),
    );
  }
}
