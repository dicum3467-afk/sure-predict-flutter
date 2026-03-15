import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/match_analysis_screen.dart';

class FixtureCard extends StatelessWidget {
  final FixtureUiModel fixture;

  const FixtureCard({super.key, required this.fixture});

  String _formatKickoff(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month ${hour}:$minute';
    } catch (_) {
      return raw;
    }
  }

  String _percent(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final model = fixture.model;
    final probs = model?.probs;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchAnalysisScreen({
                'fixture_id': fixture.fixtureId,
                'provider_fixture_id': fixture.providerFixtureId,
                'kickoff_at': fixture.kickoffAt,
                'status': fixture.status,
                'round': fixture.round,
                'league_id': fixture.leagueId,
                'season': fixture.season,
                'league_name': fixture.leagueName,
                'league_country': fixture.leagueCountry,
                'home_team': {
                  'id': fixture.homeTeam.id,
                  'name': fixture.homeTeam.name,
                  'short': fixture.homeTeam.short,
                },
                'away_team': {
                  'id': fixture.awayTeam.id,
                  'name': fixture.awayTeam.name,
                  'short': fixture.awayTeam.short,
                },
                'model': model == null
                    ? null
                    : {
                        'type': model.type,
                        'home_xg': model.homeExpected,
                        'away_xg': model.awayExpected,
                        'avg_goals_league': model.avgGoalsLeague,
                        'probs': {
                          '1x2': {
                            '1': probs?.home ?? 0.0,
                            'X': probs?.draw ?? 0.0,
                            '2': probs?.away ?? 0.0,
                          },
                          'gg': {
                            'GG': probs?.gg ?? 0.0,
                          },
                          'ou25': {
                            'O2.5': probs?.over25 ?? 0.0,
                          },
                        },
                      },
              }),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fixture.leagueName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatKickoff(fixture.kickoffAt),
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fixture.leagueCountry,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fixture.homeTeam.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'vs',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fixture.awayTeam.name,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (model != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        title: '1',
                        value: _percent(probs?.home ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatBox(
                        title: 'X',
                        value: _percent(probs?.draw ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatBox(
                        title: '2',
                        value: _percent(probs?.away ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        title: 'GG',
                        value: _percent(probs?.gg ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatBox(
                        title: 'Over 2.5',
                        value: _percent(probs?.over25 ?? 0),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.20)),
                  ),
                  child: const Text(
                    'Nu există încă predicție pentru acest meci.',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;

  const _StatBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
