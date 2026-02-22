import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fixture_item.dart';

class MatchDetailsScreen extends StatelessWidget {
  const MatchDetailsScreen({super.key, required this.fixture});

  final FixtureItem fixture;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('EEE, dd MMM yyyy • HH:mm').format(dt.toLocal());
  }

  String _pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';

  int _bestIndex1x2() {
    final a = fixture.pHome ?? -1;
    final b = fixture.pDraw ?? -1;
    final c = fixture.pAway ?? -1;

    if (a >= b && a >= c) return 0;
    if (b >= a && b >= c) return 1;
    return 2;
  }

  /// Confidence 0..100 based on how "clear" the best pick is (gap vs #2).
  int _confidence1x2() {
    final vals = <double>[
      fixture.pHome ?? 0,
      fixture.pDraw ?? 0,
      fixture.pAway ?? 0,
    ];
    final sorted = [...vals]..sort((x, y) => y.compareTo(x));
    final top = sorted[0];
    final second = sorted[1];
    final gap = (top - second).clamp(0.0, 1.0);

    // Base on top prob + gap
    final score = (top * 70) + (gap * 30); // 0..100
    return (score * 100).round().clamp(0, 100);
  }

  /// Simple recommendation logic (you can tune thresholds later)
  _Recommendation _buildRecommendation() {
    final ph = fixture.pHome;
    final pd = fixture.pDraw;
    final pa = fixture.pAway;

    final pGg = fixture.pGg; // BTTS yes
    final pOver = fixture.pOver25;
    final pUnder = fixture.pUnder25;

    // helper
    double max3(double? a, double? b, double? c) =>
        [a ?? -1, b ?? -1, c ?? -1].reduce((x, y) => x > y ? x : y);

    // 1) Strong BTTS / Goals markets first (often best for users)
    if (pGg != null && pGg >= 0.62) {
      return _Recommendation(
        title: 'BTTS (GG) – YES',
        reason: 'Probabilitate GG ridicată (${_pct(pGg)}).',
        confidence: (pGg * 100).round().clamp(0, 100),
      );
    }

    if (pOver != null && pOver >= 0.62) {
      return _Recommendation(
        title: 'Over 2.5',
        reason: 'Probabilitate Over 2.5 ridicată (${_pct(pOver)}).',
        confidence: (pOver * 100).round().clamp(0, 100),
      );
    }

    if (pUnder != null && pUnder >= 0.62) {
      return _Recommendation(
        title: 'Under 2.5',
        reason: 'Probabilitate Under 2.5 ridicată (${_pct(pUnder)}).',
        confidence: (pUnder * 100).round().clamp(0, 100),
      );
    }

    // 2) 1X2 strong single outcome
    final top1x2 = max3(ph, pd, pa);
    if (top1x2 >= 0.55) {
      final idx = _bestIndex1x2();
      final label = idx == 0 ? '1 (Home)' : idx == 1 ? 'X (Draw)' : '2 (Away)';
      return _Recommendation(
        title: '1X2 – $label',
        reason: 'Cea mai mare probabilitate pe 1X2 (${_pct(top1x2)}).',
        confidence: _confidence1x2(),
      );
    }

    // 3) Double chance from 1X2 (safer)
    if (ph != null && pd != null && (ph + pd) >= 0.72) {
      return _Recommendation(
        title: '1X (Home or Draw)',
        reason: 'Șansă dublă mare: 1X = ${_pct(ph + pd)}.',
        confidence: ((ph + pd) * 100).round().clamp(0, 100),
      );
    }
    if (pa != null && pd != null && (pa + pd) >= 0.72) {
      return _Recommendation(
        title: 'X2 (Away or Draw)',
        reason: 'Șansă dublă mare: X2 = ${_pct(pa + pd)}.',
        confidence: ((pa + pd) * 100).round().clamp(0, 100),
      );
    }

    // 4) fallback: best of what we have
    // pick best among (1X2 top, GG, Over, Under)
    final candidates = <_Recommendation>[
      if (top1x2 > 0)
        _Recommendation(
          title: '1X2 – Best pick',
          reason: 'Nu e foarte clar, dar best pe 1X2 este ${_pct(top1x2)}.',
          confidence: _confidence1x2(),
        ),
      if (pGg != null)
        _Recommendation(
          title: 'BTTS (GG)',
          reason: 'GG = ${_pct(pGg)}',
          confidence: (pGg * 100).round().clamp(0, 100),
        ),
      if (pOver != null)
        _Recommendation(
          title: 'Over 2.5',
          reason: 'Over 2.5 = ${_pct(pOver)}',
          confidence: (pOver * 100).round().clamp(0, 100),
        ),
      if (pUnder != null)
        _Recommendation(
          title: 'Under 2.5',
          reason: 'Under 2.5 = ${_pct(pUnder)}',
          confidence: (pUnder * 100).round().clamp(0, 100),
        ),
    ];

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.isNotEmpty
        ? candidates.first
        : _Recommendation(
            title: 'No recommendation',
            reason: 'Nu avem suficiente date pentru recomandare.',
            confidence: 0,
          );
  }

  @override
  Widget build(BuildContext context) {
    final best = _bestIndex1x2();
    final rec = _buildRecommendation();

    return Scaffold(
      appBar: AppBar(
        title: Text('${fixture.home} vs ${fixture.away}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${fixture.home} vs ${fixture.away}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDate(fixture.kickoffAt)} • ${fixture.status} • run: ${fixture.runType ?? '-'}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 18),

          _sectionTitle('Recommended'),
          _RecommendationCard(rec: rec),

          const SizedBox(height: 18),
          _sectionTitle('1X2 Prediction'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProbTile(label: 'H', value: fixture.pHome, highlight: best == 0),
              _ProbTile(label: 'D', value: fixture.pDraw, highlight: best == 1),
              _ProbTile(label: 'A', value: fixture.pAway, highlight: best == 2),
            ],
          ),

          const SizedBox(height: 18),
          _sectionTitle('Markets'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProbTile(label: 'BTTS (GG)', value: fixture.pGg, highlight: false),
              _ProbTile(label: 'Over 2.5', value: fixture.pOver25, highlight: false),
              _ProbTile(label: 'Under 2.5', value: fixture.pUnder25, highlight: false),
            ],
          ),

          if (fixture.computedAt != null) ...[
            const SizedBox(height: 18),
            _sectionTitle('Info'),
            Text(
              'Computed at: ${_formatDate(fixture.computedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(
          t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );
}

class _ProbTile extends StatelessWidget {
  const _ProbTile({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final double? value;
  final bool highlight;

  String _pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
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
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
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
}

class _Recommendation {
  final String title;
  final String reason;
  final int confidence;

  _Recommendation({
    required this.title,
    required this.reason,
    required this.confidence,
  });
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec});

  final _Recommendation rec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rec.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(rec.reason),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Confidence:'),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (rec.confidence / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${rec.confidence}%'),
            ],
          ),
        ],
      ),
    );
  }
}
