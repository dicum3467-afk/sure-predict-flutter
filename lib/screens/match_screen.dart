import 'package:flutter/material.dart';

import '../api/api_football.dart';
import '../models/fixture.dart';
import '../models/prediction_lite.dart';
import '../l10n/l10n.dart';

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
  PredictionLite? pred;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    final res = await widget.api.getPredictionLite(widget.fixture.id);

    if (!mounted) return;

    setState(() {
      loading = false;
      if (res.isOk) {
        pred = res.data;
      } else {
        error = res.error ?? 'Predictions unavailable';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final f = widget.fixture;

    return Scaffold(
      appBar: AppBar(
        title: Text('${f.homeName} - ${f.awayName}'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? Center(child: Text(t.t('loading')))
            : (pred == null)
                ? _errorCard(t)
                : _predUI(t, pred!),
      ),
    );
  }

  Widget _errorCard(AppL10n t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.t('predictions_unavailable'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Text(error ?? '—', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _predUI(AppL10n t, PredictionLite p) {
    final picks = p.picks;
    final top = p.topPick;

    return ListView(
      children: [
        _card(
          title: t.t('ai_overview'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _badge('AI'),
                  const SizedBox(width: 10),
                  _badge('${t.t('confidence')}: ${p.confidence}%'),
                  const Spacer(),
                  if (top != null) _badge('${t.t('top_pick')}: ${top.label} (${top.percent}%)'),
                ],
              ),
              const SizedBox(height: 14),
              if (p.has1x2) ...[
                _barRow(p),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 ${(p.pHome! * 100).round()}%',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    Text('X ${(p.pDraw! * 100).round()}%',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    Text('2 ${(p.pAway! * 100).round()}%',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  ],
                ),
              ] else
                Text(t.t('no_probabilities'), style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: t.t('details'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv(t.t('advice'), p.advice ?? '—'),
              _kv('Under/Over', p.underOver ?? '—'),
              _kv('BTTS', p.btts ?? '—'),
              _kv(t.t('predicted_score'), p.predictedScore ?? '—'),
              _kv(t.t('winner'), p.winnerName ?? '—'),
              if (p.winnerComment != null && p.winnerComment!.isNotEmpty) _kv(t.t('note'), p.winnerComment!),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: t.t('picks_ranked'),
          child: Column(
            children: [
              for (final pk in picks) ...[
                _pickLine(pk.label, pk.percent),
                const SizedBox(height: 8),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _barRow(PredictionLite p) {
    int flex(double x) => (x * 1000).round().clamp(1, 1000);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            Expanded(flex: flex(p.pHome!), child: Container(color: Colors.purpleAccent.withOpacity(0.75))),
            Expanded(flex: flex(p.pDraw!), child: Container(color: Colors.cyanAccent.withOpacity(0.75))),
            Expanded(flex: flex(p.pAway!), child: Container(color: Colors.greenAccent.withOpacity(0.65))),
          ],
        ),
      ),
    );
  }

  Widget _pickLine(String label, int pct) {
    return Row(
      children: [
        SizedBox(width: 26, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: pct / 100.0, minHeight: 10),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text('$pct%', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
