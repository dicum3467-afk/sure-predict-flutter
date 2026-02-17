import 'package:flutter/material.dart';

import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';
import '../services/prediction_cache.dart';

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
  late final PredictionCache cache;
  PredictionLite? p;
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    cache = PredictionCache(api: widget.api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });

    try {
      final res = await cache.getForFixture(widget.fixture);
      setState(() {
        p = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final f = widget.fixture;

    return Scaffold(
      appBar: AppBar(
        title: Text('${f.home} - ${f.away}'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? Center(child: Text(t.t('loading')))
            : err != null
                ? Text(err!)
                : p == null
                    ? Text(t.t('predictions_unavailable'))
                    : _content(context, t, f, p!),
      ),
    );
  }

  Widget _content(BuildContext context, AppL10n t, FixtureLite f, PredictionLite p) {
    return ListView(
      children: [
        Text(
          f.league ?? '',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        _card(
          title: t.t('predictions'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top pick: ${p.topPick}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Confidence: ${p.confidence}% (${p.sourceTag})'),
              const SizedBox(height: 12),
              _rowProb('1', p.pHome),
              _rowProb('X', p.pDraw),
              _rowProb('2', p.pAway),
              const SizedBox(height: 10),
              Text(p.extras),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rowProb(String name, double v) {
    final pct = (v.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 22, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: v.clamp(0.0, 1.0),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 42, child: Text('$pct%')),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withOpacity(0.08),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
