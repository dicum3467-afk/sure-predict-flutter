import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';

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

    // ✅ FIX IMPORTANT — res este deja Map
    if (res is Map<String, dynamic>) {
      return res;
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
      final parsed = double.tryParse(v.toString());
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
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.hasError) {
              return SizedBox(
                height: 260,
                child: Center(
                  child: Text('Eroare: ${snap.error}'),
                ),
              );
            }

            final data = snap.data ?? {};

            final pHome = _num(data, const ['p_home'], 0);
            final pDraw = _num(data, const ['p_draw'], 0);
            final pAway = _num(data, const ['p_away'], 0);
            final pGG = _num(data, const ['p_gg'], 0);
            final pOver25 = _num(data, const ['p_over25'], 0);
            final pUnder25 = _num(data, const ['p_under25'], 0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$home vs $away',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                _row(context, 'Home (1)', _pct(pHome)),
                _row(context, 'Draw (X)', _pct(pDraw)),
                _row(context, 'Away (2)', _pct(pAway)),
                const SizedBox(height: 8),
                _row(context, 'GG', _pct(pGG)),
                _row(context, 'Over 2.5', _pct(pOver25)),
                _row(context, 'Under 2.5', _pct(pUnder25)),

                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reîncarcă'),
                ),
                const SizedBox(height: 12),
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
          Expanded(child: Text(left)),
          Text(
            right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
