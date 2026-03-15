import 'package:flutter/material.dart';

class MatchAnalysisScreen extends StatelessWidget {
  final dynamic fixture;

  const MatchAnalysisScreen(this.fixture, {super.key});

  double _readProb(List<String> paths) {
    dynamic current = fixture;

    for (final key in paths) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return 0;
      }
    }

    if (current is num) return current.toDouble();
    return 0;
  }

  String _teamName(String side) {
    final team = fixture['${side}_team'];
    if (team is Map<String, dynamic>) {
      return (team['name'] ?? '').toString();
    }
    return side == 'home' ? 'Home' : 'Away';
  }

  String _leagueName() => (fixture['league_name'] ?? '').toString();

  String _kickoff() => (fixture['kickoff_at'] ?? '').toString();

  Widget _probBar(String label, double value, {Color? color}) {
    final safeValue = value.clamp(0, 100).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${safeValue.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: safeValue / 100,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? Colors.lightBlueAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
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
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeName = _teamName('home');
    final awayName = _teamName('away');

    final homeWin = (_readProb(['model', 'probs', '1x2', '1']) * 100).toDouble();
    final draw = (_readProb(['model', 'probs', '1x2', 'X']) * 100).toDouble();
    final awayWin = (_readProb(['model', 'probs', '1x2', '2']) * 100).toDouble();
    final gg = (_readProb(['model', 'probs', 'gg', 'GG']) * 100).toDouble();
    final over25 = (_readProb(['model', 'probs', 'ou25', 'O2.5']) * 100).toDouble();

    final homeXg = _readProb(['model', 'home_xg']);
    final awayXg = _readProb(['model', 'away_xg']);
    final avgGoalsLeague = _readProb(['model', 'avg_goals_league']);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1720),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1720),
        elevation: 0,
        title: const Text(
          'Match Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  _leagueName(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$homeName vs $awayName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _kickoff(),
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '1X2 Probabilities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _probBar('$homeName win', homeWin.toDouble(), color: Colors.greenAccent),
          const SizedBox(height: 14),
          _probBar('Draw', draw.toDouble(), color: Colors.orangeAccent),
          const SizedBox(height: 14),
          _probBar('$awayName win', awayWin.toDouble(), color: Colors.redAccent),
          const SizedBox(height: 22),
          const Text(
            'Goals Markets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _probBar('GG', gg.toDouble(), color: Colors.purpleAccent),
          const SizedBox(height: 14),
          _probBar('Over 2.5', over25.toDouble(), color: Colors.cyanAccent),
          const SizedBox(height: 14),
          _probBar('Under 2.5', (100 - over25).toDouble(), color: Colors.tealAccent),
          const SizedBox(height: 22),
          const Text(
            'Model Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  'Home xG',
                  homeXg.toStringAsFixed(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  'Away xG',
                  awayXg.toStringAsFixed(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoCard(
            'League Avg Goals',
            avgGoalsLeague.toStringAsFixed(2),
          ),
        ],
      ),
    );
  }
}
