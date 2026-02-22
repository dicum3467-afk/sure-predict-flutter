import 'package:flutter/material.dart';
import 'fixture_ui.dart';

Future<void> showPredictionSheet(
  BuildContext context, {
  required String home,
  required String away,
  required String providerFixtureId,
  required Map<String, dynamic> prediction,
}) async {
  final best = bestBetFromMap(prediction);

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$home vs $away',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'provider_fixture_id: $providerFixtureId',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),

              // ===== BEST BET
              if (best != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    'Best bet: ${best.label} • ${pct(best.value)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),

              const SizedBox(height: 12),

              _row('Home (1)', prediction['p_home']),
              _row('Draw (X)', prediction['p_draw']),
              _row('Away (2)', prediction['p_away']),
              const Divider(height: 20),
              _row('GG', prediction['p_gg']),
              _row('Over 2.5', prediction['p_over25']),
              _row('Under 2.5', prediction['p_under25']),
            ],
          ),
        ),
      );
    },
  );
}

Widget _row(String label, dynamic v) {
  double? d(dynamic x) =>
      x == null ? null : (x is num ? x.toDouble() : double.tryParse(x.toString()));

  final val = d(v);
  final txt = val == null ? '-' : pct(val);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(txt, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
