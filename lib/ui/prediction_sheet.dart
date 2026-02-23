import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';

/// Afiseaza bottom sheet-ul cu predictia.
/// IMPORTANT: foloseste named parameter la getPrediction
Future<void> showPredictionSheet({
  required BuildContext context,
  required SurePredictService service,
  required Map<String, dynamic> fixture,
  required String providerFixtureId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return _PredictionSheet(
        service: service,
        fixture: fixture,
        providerFixtureId: providerFixtureId,
      );
    },
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
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await widget.service.getPrediction(
      providerFixtureId: widget.providerFixtureId,
    );

    // uneori api poate intoarce string json
    if (res is Map<String, dynamic>) return res;

    if (res is String) {
      final decoded = jsonDecode(res);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
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

  double _num(Map<String, dynamic> m, List<String> keys, [double fallback = 0]) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      final parsed = double.tryParse(s);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _pct(double v) => '${(v * 100).round()}%';

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
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.hasError) {
              return SizedBox(
                height: 260,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$home vs $away',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Eroare: ${snap.error}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() => _future = _load()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Încearcă din nou'),
                    ),
                  ],
                ),
              );
            }

            final data = snap.data ?? <String, dynamic>{};

            final pHome = _num(data, const ['p_home', 'home', 'p1'], 0);
            final pDraw = _num(data, const ['p_draw', 'draw', 'px'], 0);
            final pAway = _num(data, const ['p_away', 'away', 'p2'], 0);

            final pGG = _num(data, const ['p_gg', 'gg'], 0);
            final pOver25 = _num(data, const ['p_over25', 'over25', 'p_over_25'], 0);
            final pUnder25 = _num(data, const ['p_under25', 'under25', 'p_under_25'], 0);

            // best dintre 1/X/2
            String bestLabel = '1';
            double bestValue = pHome;
            if (pDraw > bestValue) {
              bestLabel = 'X';
              bestValue = pDraw;
            }
            if (pAway > bestValue) {
              bestLabel = '2';
              bestValue = pAway;
            }

            return Column(
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

                // Card "Best"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Best: $bestLabel • ${_pct(bestValue)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _row(context, 'Home (1)', _pct(pHome)),
                _row(context, 'Draw (X)', _pct(pDraw)),
                _row(context, 'Away (2)', _pct(pAway)),
                const SizedBox(height: 8),
                _row(context, 'GG', _pct(pGG)),
                _row(context, 'Over 2.5', _pct(pOver25)),
                _row(context, 'Under 2.5', _pct(pUnder25)),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Închide'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => setState(() => _future = _load()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reîncarcă'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Text(
            right,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
