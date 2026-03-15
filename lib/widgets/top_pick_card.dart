import 'package:flutter/material.dart';
import '../models/app_models.dart';

class TopPickCard extends StatelessWidget {
  final TopPickUiModel pick;

  const TopPickCard({super.key, required this.pick});

  String _percent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  Color _edgeColor(double edge) {
    if (edge >= 0.08) return Colors.greenAccent;
    if (edge >= 0.04) return Colors.orangeAccent;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pick.homeTeam} vs ${pick.awayTeam}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${pick.leagueName} • ${pick.market}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniBox(
                  title: 'Pick',
                  value: pick.selection,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniBox(
                  title: 'Odd',
                  value: pick.odd.toStringAsFixed(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniBox(
                  title: 'Model Prob.',
                  value: _percent(pick.modelProbability),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniBox(
                  title: 'Implied Prob.',
                  value: _percent(pick.impliedProbability),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniBox(
                  title: 'Edge',
                  value: _percent(pick.edge),
                  valueColor: _edgeColor(pick.edge),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniBox(
                  title: 'EV',
                  value: _percent(pick.expectedValue),
                  valueColor: _edgeColor(pick.expectedValue),
                ),
              ),
            ],
          ),
          if (pick.fairOdd != null) ...[
            const SizedBox(height: 10),
            _miniBox(
              title: 'Fair Odd',
              value: pick.fairOdd!.toStringAsFixed(2),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: pick.edge.clamp(0, 0.20) / 0.20,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(_edgeColor(pick.edge)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBox({
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
