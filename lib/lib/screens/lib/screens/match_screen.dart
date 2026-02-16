import 'package:flutter/material.dart';
import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';

class MatchScreen extends StatefulWidget {
  final ApiFootball api;
  final FixtureLite fixture;
  const MatchScreen({super.key, required this.api, required this.fixture});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool loading = true;
  Map<String, dynamic>? pred;

  @override
  void initState() {
    super.initState();
    _loadPred();
  }

  Future<void> _loadPred() async {
    setState(() => loading = true);
    final p = await widget.api.getPredictions(widget.fixture.id);
    setState(() {
      pred = p;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.fixture.home} - ${widget.fixture.away}'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPred,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.fixture.league),
            const SizedBox(height: 16),
            Text(t.t('predictions'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (loading)
              Text(t.t('loading'))
            else if (pred == null)
              const Text('Predictions not available (plan/quota/fixture).')
            else
              _predCards(pred!),
          ],
        ),
      ),
    );
  }

  Widget _predCards(Map<String, dynamic> p) {
    final predictions = (p['predictions'] ?? {}) as Map<String, dynamic>;

    final winner = (predictions['winner'] ?? {}) as Map<String, dynamic>;
    final winnerName = (winner['name'] ?? '').toString();

    final underOver = (predictions['under_over'] ?? '').toString();
    final btts = (predictions['btts'] ?? '').toString();

    return Column(
      children: [
        _pill('1X2', winnerName.isEmpty ? 'N/A' : winnerName),
        const SizedBox(height: 10),
        _pill('O/U 2.5', underOver.isEmpty ? 'N/A' : underOver),
        const SizedBox(height: 10),
        _pill('BTTS', btts.isEmpty ? 'N/A' : btts),
      ],
    );
  }

  Widget _pill(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text(value),
        ],
      ),
    );
  }
}
