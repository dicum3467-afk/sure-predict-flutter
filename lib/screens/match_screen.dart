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
    if (!p.isOk) {
      setState(() {
        loading = false;
        error = p.error;
        pred = null;
      });
      return;
    }

    final h = await widget.api.lastFixturesForTeam(teamId: widget.fixture.homeId, last: 5, timezone: _tz);
    final a = await widget.api.lastFixturesForTeam(teamId: widget.fixture.awayId, last: 5, timezone: _tz);
    final x = await widget.api.headToHead(homeTeamId: widget.fixture.homeId, awayTeamId: widget.fixture.awayId, last: 5);

    if (!mounted) return;

    setState(() {
      pred = p.data;
      homeLast = h.data ?? [];
      awayLast = a.data ?? [];
      h2h = x.data ?? [];
      error = p.error ?? h.error ?? a.error ?? x.error; // prima eroare disponibilă
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
            _headerCard(),
            const SizedBox(height: 12),
            if (loading)
              _loadingCard(t.t('loading'))
            else if (error != null && pred == null)
              _infoCard('Eroare API: $error')
            else if (pred == null)
              _infoCard('Predicții indisponibile.')
            else
              ..._expertBlocks(context, pred!),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fixture.league, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _team(widget.fixture.home)),
                const SizedBox(width: 8),
                const Text('VS', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Expanded(child: _team(widget.fixture.away, alignEnd: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _team(String name, {bool alignEnd = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all()),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _loadingCard(String msg) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text),
      ),
    );
  }

  List<Widget> _expertBlocks(BuildContext context, Map<String, dynamic> root) {
    final predictions = (root['predictions'] ?? {}) as Map<String, dynamic>;
    final percent = (root['percent'] ?? {}) as Map<String, dynamic>;

    final winner = (predictions['winner'] ?? {}) as Map<String, dynamic>;
    final winnerName = _s(winner['name']);
    final advice = _s(predictions['advice']);
    final underOver = _s(predictions['under_over']);
    final btts = _s(predictions['btts']);

    final pHome = _parsePercent(_s(percent['home']));
    final pDraw = _parsePercent(_s(percent['draw']));
    final pAway = _parsePercent(_s(percent['away']));

    final homeForm = _formSummary(homeLast, widget.fixture.homeId);
    final awayForm = _formSummary(awayLast, widget.fixture.awayId);
    final h2hForm = _h2hSummary(h2h, widget.fixture.homeId, widget.fixture.awayId);

    final confidence = _confidenceScore(
      pHome: pHome,
      pDraw: pDraw,
      pAway: pAway,
      winnerName: winnerName,
      homeFormPoints: homeForm.points,
      awayFormPoints: awayForm.points,
      h2hDelta: h2hForm.delta,
    );

    final topPick = winnerName.isNotEmpty
        ? winnerName
        : _maxPick(widget.fixture.home, widget.fixture.away, pHome, pDraw, pAway);

    return [
      _sectionCard(
        title: 'Expert score',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bigScore(confidence),
            const SizedBox(height: 10),
            _metric('Top pick', topPick),
            if (advice.isNotEmpty) _metric('Advice', advice),
            if (underOver.isNotEmpty) _metric('O/U 2.5', underOver),
            if (btts.isNotEmpty) _metric('BTTS', btts),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _sectionCard(
        title: 'Probabilități 1X2 (API)',
        child: Column(
          children: [
            _probRow(widget.fixture.home, pHome),
            const SizedBox(height: 8),
            _probRow('Egal', pDraw),
            const SizedBox(height: 8),
            _probRow(widget.fixture.away, pAway),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _sectionCard(
        title: 'Formă (ultimele 5)',
        child: Column(
          children: [
            _formRow(widget.fixture.home, homeForm),
            const SizedBox(height: 10),
            _formRow(widget.fixture.away, awayForm),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _sectionCard(
        title: 'Head-to-head (ultimele 5)',
        child: _h2hRow(h2hForm),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        _infoCard('Notă: $error'),
      ],
    ];
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bigScore(int score) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(),
          ),
          child: Text('$score/100', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Flexible(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _probRow(String name, double p) {
    final pctText = p.isNaN ? 'N/A' : '${p.toStringAsFixed(0)}%';
    return Row(
      children: [
        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p.isNaN ? 0 : (p / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 56, child: Text(pctText, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _formRow(String teamName, _FormSummary f) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(teamName, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('W-D-L: ${f.w}-${f.d}-${f.l} • Puncte: ${f.points}/15'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: f.last5.map(_chip).toList()),
        ],
      ),
    );
  }

  Widget _h2hRow(_H2HSummary h) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Home wins: ${h.homeWins} • Draws: ${h.draws} • Away wins: ${h.awayWins}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Delta (home-adv): ${h.delta}'),
        ],
      ),
    );
  }

  Widget _chip(String s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all()),
      child: Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  // ---------- EXPERT LOGIC ----------

  _FormSummary _formSummary(List<Map<String, dynamic>> fixtures, int teamId) {
    int w = 0, d = 0, l = 0;
    final last5 = <String>[];

    for (final item in fixtures.take(5)) {
      final teams = (item['teams'] ?? {}) as Map<String, dynamic>;
      final goals = (item['goals'] ?? {}) as Map<String, dynamic>;
      final status = ((item['fixture'] ?? {})['status'] ?? {}) as Map<String, dynamic>;
      final short = _s(status['short']);

      final home = (teams['home'] ?? {}) as Map<String, dynamic>;
      final away = (teams['away'] ?? {}) as Map<String, dynamic>;
      final homeId = home['id'];
      final awayId = away['id'];

      // only finished considered for form
      if (!(short == 'FT' || short == 'AET' || short == 'PEN')) continue;

      final gh = goals['home'] is int ? goals['home'] as int : int.tryParse('${goals['home']}') ?? 0;
      final ga = goals['away'] is int ? goals['away'] as int : int.tryParse('${goals['away']}') ?? 0;

      final isHome = homeId == teamId;
      final my = isHome ? gh : ga;
      final op = isHome ? ga : gh;

      if (my > op) {
        w++;
        last5.add('W $my-$op');
      } else if (my == op) {
        d++;
        last5.add('D $my-$op');
      } else {
        l++;
        last5.add('L $my-$op');
      }
    }

    final points = w * 3 + d;
    return _FormSummary(w: w, d: d, l: l, points: points, last5: last5);
  }

  _H2HSummary _h2hSummary(List<Map<String, dynamic>> fixtures, int homeId, int awayId) {
    int homeWins = 0, awayWins = 0, draws = 0;

    for (final item in fixtures.take(5)) {
      final teams = (item['teams'] ?? {}) as Map<String, dynamic>;
      final goals = (item['goals'] ?? {}) as Map<String, dynamic>;
      final status = ((item['fixture'] ?? {})['status'] ?? {}) as Map<String, dynamic>;
      final short = _s(status['short']);

      if (!(short == 'FT' || short == 'AET' || short == 'PEN')) continue;

      final th = (teams['home'] ?? {}) as Map<String, dynamic>;
      final ta = (teams['away'] ?? {}) as Map<String, dynamic>;
      final hid = th['id'];
      final aid = ta['id'];

      final gh = goals['home'] is int ? goals['home'] as int : int.tryParse('${goals['home']}') ?? 0;
      final ga = goals['away'] is int ? goals['away'] as int : int.tryParse('${goals['away']}') ?? 0;

      // Determine which side is "our home team" for delta
      int myHomeGoals, myAwayGoals;
      if (hid == homeId && aid == awayId) {
        myHomeGoals = gh;
        myAwayGoals = ga;
      } else if (hid == awayId && aid == homeId) {
        // reversed
        myHomeGoals = ga;
        myAwayGoals = gh;
      } else {
        continue;
      }

      if (myHomeGoals > myAwayGoals) homeWins++;
      else if (myHomeGoals < myAwayGoals) awayWins++;
      else draws++;
    }

    final delta = (homeWins - awayWins); // simple advantage
    return _H2HSummary(homeWins: homeWins, awayWins: awayWins, draws: draws, delta: delta);
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
    // Base: top probability (API)
    final base = _safeMax(pHome, pDraw, pAway); // 0..100
    // Form delta: each point difference -> 1.5 score (cap)
    final formDelta = (homeFormPoints - awayFormPoints).clamp(-15, 15);
    final formBoost = (formDelta * 1.5).round();
    // H2H delta: each win advantage -> 3 score (cap)
    final h2hBoost = (h2hDelta.clamp(-5, 5) * 3);

    // Winner confidence: if API returns explicit winner, add small boost
    final winnerBoost = winnerName.isNotEmpty ? 5 : 0;

    final score = (base + formBoost + h2hBoost + winnerBoost).clamp(0, 100);
    return score;
  }

  String _maxPick(String home, String away, double pHome, double pDraw, double pAway) {
    final map = <String, double>{home: pHome, 'Egal': pDraw, away: pAway};
    String best = 'N/A';
    double bestVal = -1;
    map.forEach((k, v) {
      if (!v.isNaN && v > bestVal) {
        bestVal = v;
        best = k;
      }
    });
    return best;
  }

  double _safeMax(double a, double b, double c) {
    double best = -1;
    for (final v in [a, b, c]) {
      if (!v.isNaN && v > best) best = v;
    }
    return best < 0 ? 0 : best;
  }

  String _s(dynamic v) => v == null ? '' : v.toString();
  double _parsePercent(String s) {
    final cleaned = s.replaceAll('%', '').trim();
    return double.tryParse(cleaned) ?? double.nan;
  }
}

class _FormSummary {
  final int w, d, l;
  final int points;
  final List<String> last5;
  _FormSummary({required this.w, required this.d, required this.l, required this.points, required this.last5});
}

class _H2HSummary {
  final int homeWins, awayWins, draws;
  final int delta;
  _H2HSummary({required this.homeWins, required this.awayWins, required this.draws, required this.delta});
}
