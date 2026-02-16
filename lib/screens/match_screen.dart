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

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.fixture.home} - ${widget.fixture.away}'),
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
            _headerCard(),
            const SizedBox(height: 16),

            Text(
              t.t('predictions'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              _infoCard('Eroare API: $error')
            else if (pred == null)
              _infoCard('Predicții indisponibile.')
            else
              ..._buildPredictionUI(pred!),
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
            Text(widget.fixture.league,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _team(widget.fixture.home)),
                const SizedBox(width: 8),
                const Text("VS", style: TextStyle(fontWeight: FontWeight.bold)),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(),
      ),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  List<Widget> _buildPredictionUI(Map<String, dynamic> root) {
    final predictions = (root['predictions'] ?? {}) as Map<String, dynamic>;
    final percent = (root['percent'] ?? {}) as Map<String, dynamic>;
    final goals = (predictions['goals'] ?? {}) as Map<String, dynamic>;
    final winner = (predictions['winner'] ?? {}) as Map<String, dynamic>;

    final advice = _s(predictions['advice']);
    final underOver = _s(predictions['under_over']);
    final btts = _s(predictions['btts']);
    final winnerName = _s(winner['name']);

    final pHome = _parsePercent(_s(percent['home']));
    final pDraw = _parsePercent(_s(percent['draw']));
    final pAway = _parsePercent(_s(percent['away']));

    final expHome = _s(goals['home']);
    final expAway = _s(goals['away']);

    return [
      _sectionCard(
        title: "Rezumat",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (advice.isNotEmpty) _metricRow("Advice", advice),
            if (winnerName.isNotEmpty) _metricRow("Winner", winnerName),
            if (underOver.isNotEmpty) _metricRow("O/U 2.5", underOver),
            if (btts.isNotEmpty) _metricRow("BTTS", btts),
            if (expHome.isNotEmpty && expAway.isNotEmpty)
              _metricRow("Scor estimat", "$expHome - $expAway"),
          ],
        ),
      ),
      const SizedBox(height: 16),
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
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value),
        ],
      ),
    );
  }

  Widget _probRow(String label, double value) {
    final text = value.isNaN ? "N/A" : "${value.toStringAsFixed(0)}%";
    return Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(
          flex: 2,
          child: LinearProgressIndicator(
            value: value.isNaN ? 0 : value / 100,
          ),
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
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

  String _s(dynamic v) => v == null ? '' : v.toString();

  double _parsePercent(String s) {
    final cleaned = s.replaceAll('%', '').trim();
    return double.tryParse(cleaned) ?? double.nan;
  }
}
