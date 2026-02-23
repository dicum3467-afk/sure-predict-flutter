import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';

/// Bottom sheet helper (NUMAI named params)
Future<void> showPredictionSheet({
  required BuildContext context,
  required SurePredictService service,
  required Map<String, dynamic> fixture,
  required String providerFixtureId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PredictionSheet(
      service: service,
      fixture: fixture,
      providerFixtureId: providerFixtureId,
    ),
  );
}

class PredictionSheet extends StatefulWidget {
  final SurePredictService service;
  final Map<String, dynamic> fixture;
  final String providerFixtureId;

  const PredictionSheet({
    super.key,
    required this.service,
    required this.fixture,
    required this.providerFixtureId,
  });

  @override
  State<PredictionSheet> createState() => _PredictionSheetState();
}

class _PredictionSheetState extends State<PredictionSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _str(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  String _pct(dynamic v) {
    final n = _num(v);
    if (n == null) return '-';
    // backend-ul tău pare să trimită 0.55 => 55%
    final p = (n * 100).round();
    return '$p%';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.service.getPrediction(widget.providerFixtureId);

      // service.getPrediction întoarce Map<String,dynamic>
      setState(() {
        _data = res;
        _loading = false;
      });
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
          const SizedBox(width: 12),
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
    final fx = widget.fixture;
    final home = _str(fx, const ['home', 'home_name'], 'Home');
    final away = _str(fx, const ['away', 'away_name'], 'Away');

    final d = _data ?? <String, dynamic>{};

    // chei posibile din backend (din screenshot-urile tale):
    // p_home, p_draw, p_away, p_gg, p_over25, p_under25
    final pHome = d['p_home'];
    final pDraw = d['p_draw'];
    final pAway = d['p_away'];
    final pGG = d['p_gg'];
    final pOver25 = d['p_over25'];
    final pUnder25 = d['p_under25'];

    // Best (dacă backend trimite best_label + best_prob, altfel calculăm)
    String bestLabel = d['best_label']?.toString() ?? '';
    double? bestProb = _num(d['best_prob']);

    // fallback: alegem maxim din 1/X/2 dacă nu există best explicit
    if (bestLabel.isEmpty || bestProb == null) {
      final a = _num(pHome) ?? -1;
      final b = _num(pDraw) ?? -1;
      final c = _num(pAway) ?? -1;

      if (a >= b && a >= c && a >= 0) {
        bestLabel = '1';
        bestProb = a;
      } else if (b >= a && b >= c && b >= 0) {
        bestLabel = 'X';
        bestProb = b;
      } else if (c >= 0) {
        bestLabel = '2';
        bestProb = c;
      }
    }

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
            const SizedBox(height: 6),
            Text(
              'provider_fixture_id: ${widget.providerFixtureId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            if (_loading) ...[
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
            ] else if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reîncearcă'),
              ),
            ] else ...[
              if (bestProb != null && bestLabel.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  child: Row(
                    children: [
                      const Text('✨  '),
                      Text(
                        'Best: $bestLabel • ${_pct(bestProb)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _row('Home (1)', _pct(pHome)),
              _row('Draw (X)', _pct(pDraw)),
              _row('Away (2)', _pct(pAway)),
              const Divider(height: 18),
              _row('GG', _pct(pGG)),
              _row('Over 2.5', _pct(pOver25)),
              _row('Under 2.5', _pct(pUnder25)),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
