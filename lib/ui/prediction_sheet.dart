import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';

Future<void> showPredictionSheet({
  required BuildContext context,
  required SurePredictService service,
  required Map<String, dynamic> fixture,
  required String providerFixtureId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PredictionSheet(
      service: service,
      fixture: fixture,
      providerFixtureId: providerFixtureId,
    ),
  );
}

class _PredictionSheet extends StatefulWidget {
  final SurePredictService service;
  final Map<String, dynamic> fixture;
  final String providerFixtureId;

  const _PredictionSheet({
    required this.service,
    required this.fixture,
    required this.providerFixtureId,
  });

  @override
  State<_PredictionSheet> createState() => _PredictionSheetState();
}

class _PredictionSheetState extends State<_PredictionSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  String _str(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  double _num(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    return double.tryParse(s) ?? fallback;
  }

  String _pct(dynamic v) {
    final x = _num(v, 0);
    // dacă vine 0.55 -> 55%
    final val = x <= 1.0 ? x * 100.0 : x;
    return '${val.toStringAsFixed(0)}%';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });

    try {
      final data = await widget.service.getPrediction(
        providerFixtureId: widget.providerFixtureId,
      );

      // service returnează Map<String,dynamic> (sau poate string json)
      if (data is Map<String, dynamic>) {
        setState(() {
          _data = data;
          _loading = false;
        });
      } else if (data is String) {
        // fallback: dacă cumva vine string, încercăm să-l folosim minim
        setState(() {
          _data = {'raw': data};
          _loading = false;
        });
      } else {
        setState(() {
          _data = {};
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = _str(widget.fixture, const ['home', 'home_name'], 'Home');
    final away = _str(widget.fixture, const ['away', 'away_name'], 'Away');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$home vs $away',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'provider_fixture_id: ${widget.providerFixtureId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            if (_loading) ...[
              const Center(child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              )),
            ] else if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Eroare',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(_error!),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reîncearcă'),
                ),
              ),
            ] else ...[
              // aici presupunem structura ta: p_home/p_draw/p_away etc.
              final d = _data ?? <String, dynamic>{};

              // calc "best"
              final pHome = _num(d['p_home']);
              final pDraw = _num(d['p_draw']);
              final pAway = _num(d['p_away']);

              String bestLabel = '';
              double bestVal = 0;

              void consider(String label, double v) {
                if (v > bestVal) {
                  bestVal = v;
                  bestLabel = label;
                }
              }

              consider('1', pHome);
              consider('X', pDraw);
              consider('2', pAway);

              final bestText = bestLabel.isEmpty
                  ? 'Best: -'
                  : 'Best: $bestLabel • ${_pct(bestVal)}';

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(
                      bestText,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _row('Home (1)', _pct(d['p_home'])),
              _row('Draw (X)', _pct(d['p_draw'])),
              _row('Away (2)', _pct(d['p_away'])),
              const Divider(height: 18),
              _row('GG', _pct(d['p_gg'])),
              _row('Over 2.5', _pct(d['p_over25'])),
              _row('Under 2.5', _pct(d['p_under25'])),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reîncarcă predicția'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
