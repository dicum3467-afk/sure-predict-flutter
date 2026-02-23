import 'package:flutter/material.dart';

import 'fixture_ui.dart';

class PredictionSheet extends StatelessWidget {
  final Map<String, dynamic> fixture;
  final Map<String, dynamic> prediction;

  const PredictionSheet({
    super.key,
    required this.fixture,
    required this.prediction,
  });

  @override
  Widget build(BuildContext context) {
    final home = (fixture['home'] ?? '').toString();
    final away = (fixture['away'] ?? '').toString();
    final id = (fixture['provider_fixture_id'] ?? '').toString();

    final best = bestBetFromMap(prediction);

    double? _num(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final homeP = _num(prediction['p_home'] ?? prediction['home']);
    final drawP = _num(prediction['p_draw'] ?? prediction['draw']);
    final awayP = _num(prediction['p_away'] ?? prediction['away']);
    final ggP = _num(prediction['p_gg'] ?? prediction['gg']);
    final over25P =
        _num(prediction['p_over_2_5'] ?? prediction['over_2_5'] ?? prediction['p_over25'] ?? prediction['over25']);
    final under25P =
        _num(prediction['p_under_2_5'] ?? prediction['under_2_5'] ?? prediction['p_under25'] ?? prediction['under25']);

    Widget row(String label, double? v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 90, child: Text(label)),
              Expanded(
                child: Text(
                  v == null ? '-' : pct(v),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$home vs $away',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'provider_fixture_id: $id',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),

          const SizedBox(height: 12),
          if (best != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Best: ${best.label} • ${pct(best.value)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
          row('Home (1)', homeP),
          row('Draw (X)', drawP),
          row('Away (2)', awayP),
          row('GG', ggP),
          row('Over 2.5', over25P),
          row('Under 2.5', under25P),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
