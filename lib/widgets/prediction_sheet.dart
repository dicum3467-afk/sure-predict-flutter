import 'package:flutter/material.dart';

class PredictionSheet extends StatelessWidget {
  final String title; // ex: "Arsenal vs Chelsea"
  final String providerFixtureId; // ex: "123"
  final Map<String, dynamic> prediction; // map-ul întors de API

  const PredictionSheet({
    super.key,
    required this.title,
    required this.providerFixtureId,
    required this.prediction,
  });

  String _pct(dynamic v) {
    if (v == null) return "-";
    if (v is num) return "${v.toStringAsFixed(1)}%";
    final s = v.toString().trim();
    if (s.isEmpty) return "-";
    // acceptă "55", "55.0", "55%"
    if (s.endsWith("%")) return s;
    final n = num.tryParse(s);
    if (n == null) return s;
    return "${n.toStringAsFixed(1)}%";
  }

  String _val(dynamic v) {
    if (v == null) return "-";
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == "null") return "-";
    return s;
  }

  @override
  Widget build(BuildContext context) {
    // Ajustează cheile dacă backend-ul tău are alte nume.
    // Am pus o variantă tolerantă (caută în mai multe chei).
    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (prediction.containsKey(k) && prediction[k] != null) return prediction[k];
      }
      return null;
    }

    final home = _pct(pick(["home", "home_win", "homePct", "p_home"]));
    final draw = _pct(pick(["draw", "drawPct", "p_draw"]));
    final away = _pct(pick(["away", "away_win", "awayPct", "p_away"]));

    final gg = _pct(pick(["gg", "btts", "both_teams_score", "p_gg"]));
    final over25 = _pct(pick(["over_2_5", "over25", "over_25", "p_over25"]));
    final under25 = _pct(pick(["under_2_5", "under25", "under_25", "p_under25"]));

    final rawTip = _val(pick(["tip", "recommended", "pick", "best_pick"]));

    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                _ChipSmall(label: "ID: $providerFixtureId"),
              ],
            ),

            if (rawTip != "-" ) ...[
              const SizedBox(height: 10),
              _InfoRow(
                label: "Recomandare",
                value: rawTip,
                valueStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],

            const SizedBox(height: 14),
            _SectionTitle(title: "1X2"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _StatCard(title: "Home", value: home)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: "Draw", value: draw)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: "Away", value: away)),
              ],
            ),

            const SizedBox(height: 14),
            _SectionTitle(title: "Goluri"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _StatCard(title: "GG", value: gg)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: "Over 2.5", value: over25)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(title: "Under 2.5", value: under25)),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Închide"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ChipSmall extends StatelessWidget {
  final String label;
  const _ChipSmall({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: valueStyle ?? theme.textTheme.bodyMedium),
      ],
    );
  }
}
