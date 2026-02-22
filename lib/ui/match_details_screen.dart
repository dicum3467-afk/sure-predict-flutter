import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fixture_item.dart';

class MatchDetailsScreen extends StatelessWidget {
  const MatchDetailsScreen({super.key, required this.fixture});

  final FixtureItem fixture;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('EEE, dd MMM yyyy · HH:mm').format(dt.toLocal());
  }

  String _pct(double? v) {
    if (v == null) return '-';
    return '${(v * 100).toStringAsFixed(0)}%';
  }

  int? _bestIndex() {
    final a = fixture.pHome ?? -1;
    final b = fixture.pDraw ?? -1;
    final c = fixture.pAway ?? -1;

    if (a >= b && a >= c) return 0;
    if (b >= a && b >= c) return 1;
    return 2;
  }

  Widget _probTile({
    required String label,
    required double? value,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 1),
        color: highlight ? Colors.green.withOpacity(0.08) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _pct(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(
          t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final best = _bestIndex();

    return Scaffold(
      appBar: AppBar(
        title: Text('${fixture.home} vs ${fixture.away}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${fixture.home} vs ${fixture.away}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDate(fixture.kickoffAt)} · ${fixture.status} · run: ${fixture.runType ?? "-"}',
            style: const TextStyle(fontSize: 14),
          ),

          _sectionTitle('1X2 Prediction'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _probTile(
                label: 'H',
                value: fixture.pHome,
                highlight: best == 0,
              ),
              _probTile(
                label: 'D',
                value: fixture.pDraw,
                highlight: best == 1,
              ),
              _probTile(
                label: 'A',
                value: fixture.pAway,
                highlight: best == 2,
              ),
            ],
          ),

          _sectionTitle('Markets'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _probTile(
                label: 'BTTS',
                value: fixture.pGg, // ✅ FIX AICI
                highlight: false,
              ),
              _probTile(
                label: 'Over 2.5',
                value: fixture.pOver25,
                highlight: false,
              ),
              _probTile(
                label: 'Under 2.5',
                value: fixture.pUnder25,
                highlight: false,
              ),
            ],
          ),

          if (fixture.computedAt != null) ...[
            _sectionTitle('Info'),
            Text(
              'Computed at: ${fixture.computedAt}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
