import 'package:flutter/material.dart';
import '../state/favorites_store.dart';
import 'fixture_ui.dart';

class FixtureTile extends StatelessWidget {
  final String home;
  final String away;
  final String status;
  final DateTime kickoff;
  final Map<String, dynamic>? prediction;
  final String fixtureId;
  final FavoritesStore favorites;
  final VoidCallback? onTap;

  const FixtureTile({
    super.key,
    required this.home,
    required this.away,
    required this.status,
    required this.kickoff,
    required this.prediction,
    required this.fixtureId,
    required this.favorites,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final st = statusStyle(status);
    final best = prediction == null ? null : bestBetFromMap(prediction!);
    final isFav = favorites.isFavorite(fixtureId);

    return AnimatedBuilder(
      animation: favorites,
      builder: (_, __) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$home vs $away',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: st.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              st.text,
                              style: TextStyle(
                                color: st.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
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

                // ⭐ FAVORITE STAR
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => favorites.toggle(fixtureId),
                ),

                if (best != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${best.label}: ${pct(best.value)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
