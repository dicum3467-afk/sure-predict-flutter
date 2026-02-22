import 'package:flutter/material.dart';
import 'fixture_ui.dart';

class FixtureTile extends StatelessWidget {
  final String home;
  final String away;
  final String status;
  final DateTime kickoff;
  final Map<String, dynamic>? prediction; // poate fi null
  final VoidCallback? onTap;

  const FixtureTile({
    super.key,
    required this.home,
    required this.away,
    required this.status,
    required this.kickoff,
    required this.prediction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final st = statusStyle(status);
    final best = prediction == null ? null : bestBetFromMap(prediction!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            // LEFT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$home vs $away',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: st.bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          st.text,
                          style: TextStyle(color: st.fg, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatKickoff(kickoff),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // RIGHT
            if (best != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.withOpacity(0.25)),
                ),
                child: Text(
                  '${best.label}: ${pct(best.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ] else ...[
              const Icon(Icons.chevron_right),
            ],
          ],
        ),
      ),
    );
  }
}
