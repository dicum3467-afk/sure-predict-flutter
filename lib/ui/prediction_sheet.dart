import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';

/// Deschide bottom sheet cu predicția pentru un meci.
/// IMPORTANT: trebuie să fie TOP-LEVEL (nu în clasă), ca să poți chema direct:
/// showPredictionSheet(...)
Future<void> showPredictionSheet({
  required BuildContext context,
  required SurePredictService service,
  required Map<String, dynamic> fixture,
  required String providerFixtureId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
  Map<String, dynamic>? _prediction;

  String _str(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  double _num(Map<String, dynamic> m, List<String> keys, [double fallback = 0]) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      final parsed = double.tryParse(s);
      if (parsed != null) return parsed;
    }
    return fallback;
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
      _prediction = null;
    });

    try {
      if (widget.providerFixtureId.trim().isEmpty) {
        throw Exception('provider_fixture_id lipsă.');
      }

      final data = await widget.service.getPrediction(widget.providerFixtureId);
      setState(() {
        _prediction = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _pct(double v) => '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final home = _str(widget.fixture, const ['home', 'home_name'], 'Home');
    final away = _str(widget.fixture, const ['away', 'away_name'], 'Away');

    final p = _prediction ?? const <String, dynamic>{};

    // Chei compatibile cu backend-ul tău (din screenshot)
    final pHome = _num(p, const ['p_home', 'home', 'p1']);
    final pDraw = _num(p, const ['p_draw', 'draw', 'px']);
    final pAway = _num(p, const ['p_away', 'away', 'p2']);
    final pGG = _num(p, const ['p_gg', 'gg', 'btts']);
    final pOver25 = _num(p, const ['p_over25', 'over25', 'over_2_5']);
    final pUnder25 = _num(p, const ['p_under25', 'under25', 'under_2_5']);

    // best pick simplu
    String bestLabel = '1';
    double best = pHome;
    if (pDraw > best) {
      best = pDraw;
      bestLabel = 'X';
    }
    if (pAway > best) {
      best = pAway;
      bestLabel = '2';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 6,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$home vs $away',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'provider_fixture_id: ${widget.providerFixtureId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),

          if (_loading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          ] else if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.error),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eroare',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_error!),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reîncearcă'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 10),
                  Text(
                    'Best: $bestLabel • ${_pct(best)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Row(label: 'Home (1)', value: _pct(pHome)),
            _Row(label: 'Draw (X)', value: _pct(pDraw)),
            _Row(label: 'Away (2)', value: _pct(pAway)),
            const SizedBox(height: 8),
            _Row(label: 'GG', value: _pct(pGG)),
            _Row(label: 'Over 2.5', value: _pct(pOver25)),
            _Row(label: 'Under 2.5', value: _pct(pUnder25)),
          ],

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
