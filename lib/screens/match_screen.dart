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

  @override
  void initState() {
    super.initState();
    _loadPred();
  }

  Future<void> _loadPred() async {
    setState(() {
      loading = true;
      error = null;
    });

    final res = await widget.api.getPredictions(widget.fixture.id);

    if (!mounted) return;

    setState(() {
      pred = res.data;
      error = res.error;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final title = '${widget.fixture.home} • ${widget.fixture.away}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _loadPred,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPred,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _headerCard(context),
            const SizedBox(height: 14),

            Text(t.t('predictions'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),

            if (loading)
              _loadingCard(t.t('loading'))
            else if (error != null)
              _errorCard(error!)
            else if (pred == null)
              _infoCard('Predicții indisponibile pentru acest meci.')
            else
              ..._buildPredictionUI(context, pred!),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fixture.league,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _teamPill(widget.fixture.home),
                ),
                const SizedBox(width: 10),
                const Text('VS', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Expanded(
                  child: _teamPill(widget.fixture.away, alignEnd: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamPill(String name, {bool alignEnd = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(width: 1),
      ),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Eroare API',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(msg),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String msg) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(msg),
      ),
    );
  }

  List<Widget> _buildPredictionUI(BuildContext context, Map<String, dynamic> root) {
    final predictions = (root['predictions'] ?? {}) as Map<String, dynamic>;
    final percent = (root['percent'] ?? {}) as Map<String, dynamic>;
    final goals = (predictions['goals'] ?? {}) as Map<String, dynamic>;
    final winner = (predictions['winner'] ?? {}) as Map<String, dynamic>;

    final advice = _s(predictions['advice']);
    final underOver = _s(predictions['under_over']);
    final btts = _s(predictions['btts']);

    final winnerName = _s(winner['name']);
    final winnerComment = _s(winner['comment']);

    final pHome = _parsePercent(_s(percent['home']));
    final pDraw = _parsePercent(_s(percent['draw']));
    final pAway = _parsePercent(_s(percent['away']));

    final expHome = _s(goals['home']);
    final expAway = _s(goals['away']);

    final topPick = _topPick(
      home: widget.fixture.home,
      away: widget.fixture.away,
      pHome: pHome,
      pDraw: pDraw,
      pAway: pAway,
      winnerName: winnerName,
    );

    return [
      _sectionCard(
        title: 'Rezumat',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (advice.isNotEmpty) _chip('Advice', advice),
                if (winnerName.isNotEmpty) _chip('Winner', winnerName),
                if (winnerComment.isNotEmpty) _chip('Note', winnerComment),
                if (underOver.isNotEmpty) _chip('O/U', underOver),
                if (btts.isNotEmpty) _chip('BTTS', btts),
              ],
            ),
            const SizedBox(height: 12),
            _metricRow('Top pick', topPick),
            const SizedBox(height: 8),
            _metricRow(
              'Scor estimat (xG)',
              (expHome.isEmpty || expAway.isEmpty) ? 'N/A' : '$expHome - $expAway',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      _sectionCard(
        title: 'Probabilități (1X2)',
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
      const SizedBox(height: 14),

      _sectionCard(
        title: 'Picks rapide',
        child: Column(
          children: [
            _pickTile('1X2', winnerName.isEmpty ? 'N/A' : winnerName),
            _pickTile('BTTS', btts.isEmpty ? 'N/A' : btts),
            _pickTile('O/U 2.5', underOver.isEmpty ? 'N/A' : underOver),
          ],
        ),
      ),
    ];
  }

  Widget _sectionCard({required String title, required Widget child})Widget {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _chip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 1),
      ),
      child: Text('$k: $v', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
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

  Widget _pickTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _topPick({
    required String home,
    required String away,
    required double pHome,
    required double pDraw,
    required double pAway,
    required String winnerName,
  }) {
    // Prefer winner dacă e dat de API (mai “opinie”), altfel alegem max din percent.
    if (winnerName.isNotEmpty) return winnerName;

    final entries = <String, double>{
      home: pHome,
      'Egal': pDraw,
      away: pAway,
    };

    String best = 'N/A';
    double bestVal = -1;
    entries.forEach((k, v) {
      if (!v.isNaN && v > bestVal) {
        bestVal = v;
        best = k;
      }
    });

    return best;
  }

  String _s(dynamic v) => (v == null) ? '' : v.toString();

  double _parsePercent(String s) {
    final cleaned = s.replaceAll('%', '').trim();
    final v = double.tryParse(cleaned);
    return v ?? double.nan;
  }
}
