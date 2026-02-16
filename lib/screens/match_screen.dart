import 'package:flutter/material.dart';
import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';

class MatchScreen extends StatefulWidget {
  final ApiFootball api;
  final FixtureLite fixture;

  const MatchScreen({
    super.key,
    required this.api,
    required this.fixture,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? pred;
  List<Map<String, dynamic>> homeLast = [];
  List<Map<String, dynamic>> awayLast = [];
  List<Map<String, dynamic>> h2h = [];

  static const _tz = 'Europe/Bucharest';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    final p = await widget.api.getPredictions(widget.fixture.id);
    final h = await widget.api.lastFixturesForTeam(
        teamId: widget.fixture.homeId, last: 5, timezone: _tz);
    final a = await widget.api.lastFixturesForTeam(
        teamId: widget.fixture.awayId, last: 5, timezone: _tz);
    final x = await widget.api.headToHead(
        homeTeamId: widget.fixture.homeId,
        awayTeamId: widget.fixture.awayId,
        last: 5);

    if (!mounted) return;

    setState(() {
      pred = p.data;
      homeLast = h.data ?? [];
      awayLast = a.data ?? [];
      h2h = x.data ?? [];
      error = p.error ?? h.error ?? a.error ?? x.error;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.fixture.home} - ${widget.fixture.away}'),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (pred == null)
              _infoCard(error ?? "Predictions not available")
            else
              ..._expertBlocks(pred!),
          ],
        ),
      ),
    );
  }

  // ================= UI =================

  Widget _infoCard(String text) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _probRow(String name, double p) {
    final pct = p.isNaN ? "N/A" : "${p.toStringAsFixed(0)}%";
    return Row(
      children: [
        Expanded(child: Text(name)),
        Expanded(
          flex: 2,
          child: LinearProgressIndicator(
            value: p.isNaN ? 0 : p / 100,
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 8),
        Text(pct),
      ],
    );
  }

  Widget _bigScore(int score) {
    return Row(
      children: [
        Text("$score/100",
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        Expanded(
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  // ================= EXPERT BLOCKS =================

  List<Widget> _expertBlocks(Map<String, dynamic> root) {
    final predictions = (root['predictions'] ?? {}) as Map<String, dynamic>;
    final percent = (root['percent'] ?? {}) as Map<String, dynamic>;
    final winner = (predictions['winner'] ?? {}) as Map<String, dynamic>;

    final winnerName = _s(winner['name']);
    final advice = _s(predictions['advice']);

    final pHome = _parsePercent(_s(percent['home']));
    final pDraw = _parsePercent(_s(percent['draw']));
    final pAway = _parsePercent(_s(percent['away']));

    final homeForm = _formSummary(homeLast, widget.fixture.homeId);
    final awayForm = _formSummary(awayLast, widget.fixture.awayId);
    final h2hSum = _h2hSummary(h2h, widget.fixture.homeId, widget.fixture.awayId);

    final confidence = _confidenceScore(
      pHome: pHome,
      pDraw: pDraw,
      pAway: pAway,
      winnerName: winnerName,
      homeFormPoints: homeForm.points,
      awayFormPoints: awayForm.points,
      h2hDelta: h2hSum.delta,
    );

    return [
      _sectionCard(
        title: "Expert Score",
        child: _bigScore(confidence),
      ),
      const SizedBox(height: 12),
      _sectionCard(
        title: "Probabilități 1X2",
        child: Column(
          children: [
            _probRow(widget.fixture.home, pHome),
            const SizedBox(height: 8),
            _probRow("Egal", pDraw),
            const SizedBox(height: 8),
            _probRow(widget.fixture.away, pAway),
          ],
        ),
      ),
      if (advice.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionCard(title: "Advice", child: Text(advice)),
      ],
    ];
  }

  // ================= EXPERT LOGIC =================

  _FormSummary _formSummary(
      List<Map<String, dynamic>> fixtures, int teamId) {
    int w = 0, d = 0, l = 0;

    for (final item in fixtures.take(5)) {
      final teams = item['teams'];
      final goals = item['goals'];

      final hid = teams['home']['id'];
      final aid = teams['away']['id'];

      final gh = goals['home'] ?? 0;
      final ga = goals['away'] ?? 0;

      final isHome = hid == teamId;
      final my = isHome ? gh : ga;
      final op = isHome ? ga : gh;

      if (my > op) {
        w++;
      } else if (my == op) {
        d++;
      } else {
        l++;
      }
    }

    final points = w * 3 + d;
    return _FormSummary(w: w, d: d, l: l, points: points);
  }

  _H2HSummary _h2hSummary(
      List<Map<String, dynamic>> fixtures, int homeId, int awayId) {
    int homeWins = 0, awayWins = 0;

    for (final item in fixtures.take(5)) {
      final teams = item['teams'];
      final goals = item['goals'];

      final hid = teams['home']['id'];
      final aid = teams['away']['id'];

      final gh = goals['home'] ?? 0;
      final ga = goals['away'] ?? 0;

      if (hid == homeId && aid == awayId) {
        if (gh > ga) homeWins++;
        if (gh < ga) awayWins++;
      } else if (hid == awayId && aid == homeId) {
        if (ga > gh) homeWins++;
        if (ga < gh) awayWins++;
      }
    }

    return _H2HSummary(
        homeWins: homeWins,
        awayWins: awayWins,
        delta: homeWins - awayWins);
  }

  int _confidenceScore({
    required double pHome,
    required double pDraw,
    required double pAway,
    required String winnerName,
    required int homeFormPoints,
    required int awayFormPoints,
    required int h2hDelta,
  }) {
    final base = _safeMax(pHome, pDraw, pAway);
    final formBoost = ((homeFormPoints - awayFormPoints) * 1.5);
    final h2hBoost = h2hDelta * 3;
    final winnerBoost = winnerName.isNotEmpty ? 5 : 0;

    return ((base + formBoost + h2hBoost + winnerBoost)
            .clamp(0, 100))
        .round();
  }

  double _safeMax(double a, double b, double c) {
    double best = 0;
    for (final v in [a, b, c]) {
      if (!v.isNaN && v > best) best = v;
    }
    return best;
  }

  String _s(dynamic v) => v == null ? '' : v.toString();

  double _parsePercent(String s) {
    final cleaned = s.replaceAll('%', '');
    return double.tryParse(cleaned) ?? double.nan;
  }
}

class _FormSummary {
  final int w, d, l;
  final int points;
  _FormSummary(
      {required this.w, required this.d, required this.l, required this.points});
}

class _H2HSummary {
  final int homeWins, awayWins, delta;
  _H2HSummary(
      {required this.homeWins,
      required this.awayWins,
      required this.delta});
}
