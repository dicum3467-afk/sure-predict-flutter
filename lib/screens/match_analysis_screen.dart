import 'package:flutter/material.dart';

class MatchAnalysisScreen extends StatelessWidget {
  final Map<String, dynamic> match;

  const MatchAnalysisScreen({
    super.key,
    required this.match,
  });

  double _fakeConfidence(String home, String away) {
    final total = home.length + away.length;
    return 50 + (total % 21).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final home = match["home_team"]?["name"] ?? "Home";
    final away = match["away_team"]?["name"] ?? "Away";
    final league = match["league_name"] ?? "-";
    final kickoff = match["kickoff_at"] ?? "-";
    final status = match["status"] ?? "-";

    final homeWin = _fakeConfidence(home, away).clamp(45, 68);
    final draw = 24.0;
    final awayWin = (100 - homeWin - draw).clamp(10, 35);

    final ggYes = ((home.length * 3 + away.length * 2) % 35 + 45).toDouble();
    final over25 = ((home.length * 4 + away.length) % 30 + 48).toDouble();

    final topPick = homeWin >= ggYes && homeWin >= over25
        ? "1"
        : ggYes >= over25
            ? "GG"
            : "Over 2.5";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Match Analysis"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(
            league: league.toString(),
            kickoff: kickoff.toString(),
            status: status.toString(),
            home: home.toString(),
            away: away.toString(),
          ),
          const SizedBox(height: 16),
          _SectionTitle("Top prediction"),
          _TopPickCard(
            pick: topPick,
            confidence: topPick == "1"
                ? homeWin
                : topPick == "GG"
                    ? ggYes
                    : over25,
          ),
          const SizedBox(height: 16),
          _SectionTitle("1X2 probabilities"),
          _ProbabilityCard(
            title: "Home Win",
            value: homeWin,
          ),
          _ProbabilityCard(
            title: "Draw",
            value: draw,
          ),
          _ProbabilityCard(
            title: "Away Win",
            value: awayWin,
          ),
          const SizedBox(height: 16),
          _SectionTitle("Goals markets"),
          _ProbabilityCard(
            title: "GG",
            value: ggYes,
          ),
          _ProbabilityCard(
            title: "Over 2.5",
            value: over25,
          ),
          _ProbabilityCard(
            title: "Under 2.5",
            value: (100 - over25).clamp(5, 95),
          ),
          const SizedBox(height: 16),
          _SectionTitle("Quick analysis"),
          _InfoCard(
            title: "Form summary",
            text:
                "$home pare ușor favorit pe baza analizei demo. $away rămâne periculos și are șanse bune să marcheze.",
          ),
          _InfoCard(
            title: "Goals expectation",
            text:
                "Meciul are profil moderat spre ofensiv. GG și Over 2.5 sunt piețe bune pentru monitorizare.",
          ),
          _InfoCard(
            title: "Best use",
            text:
                "Folosește acest ecran ca bază UI. După aceea îl conectăm la endpoint real de predictions din backend.",
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String league;
  final String kickoff;
  final String status;
  final String home;
  final String away;

  const _HeaderCard({
    required this.league,
    required this.kickoff,
    required this.status,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              league,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    home,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "vs",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    away,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  kickoff,
                  style: const TextStyle(color: Colors.white70),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _TopPickCard extends StatelessWidget {
  final String pick;
  final double confidence;

  const _TopPickCard({
    required this.pick,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                pick,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Best Pick",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${confidence.toStringAsFixed(1)}% confidence",
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ProbabilityCard extends StatelessWidget {
  final String title;
  final double value;

  const _ProbabilityCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / 100).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  "${value.toStringAsFixed(1)}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;

  const _InfoCard({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
