import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../screens/match_analysis_screen.dart';

class FixtureCard extends StatelessWidget {
  final FixtureUiModel fixture;

  const FixtureCard({
    super.key,
    required this.fixture,
  });

  @override
  Widget build(BuildContext context) {
    final localKickoff = fixture.kickoffAt.toLocal();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchAnalysisScreen(fixture),
          ),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fixture.leagueName,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fixture.status,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fixture.homeTeam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('vs'),
                  ),
                  Expanded(
                    child: Text(
                      fixture.awayTeam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${localKickoff.day}.${localKickoff.month}.${localKickoff.year} '
                '${localKickoff.hour.toString().padLeft(2, '0')}:'
                '${localKickoff.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
