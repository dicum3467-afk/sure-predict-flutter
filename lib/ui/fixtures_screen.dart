import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/fixtures_store.dart';

class FixturesScreen extends StatefulWidget {
  final String leagueId;
  final String leagueName;
  final SurePredictService service;
  final FixturesStore store;

  const FixturesScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
    required this.service,
    required this.store,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.loadInitial(widget.leagueId);
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

  num? _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num) return v;
      final parsed = num.tryParse(v.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _showPrediction(Map<String, dynamic> fx) async {
    final providerFixtureId = _str(
      fx,
      ['provider_fixture_id', 'providerFixtureId', 'fixture_id', 'fixtureId'],
      '',
    );
    if (providerFixtureId.isEmpty) return;

    try {
      // IMPORTANT: apel cu parametru NAMED (asta îți crăpa build-ul)
      final pred = await widget.service.getPrediction(providerFixtureId: providerFixtureId);

      if (!mounted) return;

      final home = _str(fx, ['home', 'home_name', 'homeTeam', 'home_team'], 'Home');
      final away = _str(fx, ['away', 'away_name', 'awayTeam', 'away_team'], 'Away');

      // încearcă să citească probabilități din pred (indiferent de chei)
      final pHome = _num(pred, ['p_home', 'home', 'homeWin', 'home_win']);
      final pDraw = _num(pred, ['p_draw', 'draw']);
      final pAway = _num(pred, ['p_away', 'away', 'awayWin', 'away_win']);
      final gg = _num(pred, ['p_gg', 'gg', 'btts']);
      final over25 = _num(pred, ['p_over_2_5', 'over_2_5', 'over25']);
      final under25 = _num(pred, ['p_under_2_5', 'under_2_5', 'under25']);

      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 10,
              children: [
                Text(
                  '$home vs $away',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text('provider_fixture_id: $providerFixtureId'),
                const Divider(),
                Text('Home: ${pHome != null ? (pHome * 100).toStringAsFixed(1) : '-'}%'),
                Text('Draw: ${pDraw != null ? (pDraw * 100).toStringAsFixed(1) : '-'}%'),
                Text('Away: ${pAway != null ? (pAway * 100).toStringAsFixed(1) : '-'}%'),
                const SizedBox(height: 6),
                Text('GG: ${gg != null ? (gg * 100).toStringAsFixed(1) : '-'}%'),
                Text('Over 2.5: ${over25 != null ? (over25 * 100).toStringAsFixed(1) : '-'}%'),
                Text('Under 2.5: ${under25 != null ? (under25 * 100).toStringAsFixed(1) : '-'}%'),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prediction error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.leagueName),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: store.isLoading ? null : store.refresh,
              ),
            ],
          ),
          body: Builder(
            builder: (_) {
              if (store.isLoading && store.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (store.error != null && store.items.isEmpty) {
                return Center(child: Text(store.error!));
              }

              if (store.items.isEmpty) {
                return const Center(child: Text('No fixtures'));
              }

              return NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                    store.loadMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: store.items.length + 1, // +1 footer
                  itemBuilder: (context, index) {
                    if (index == store.items.length) {
                      if (store.isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return const SizedBox(height: 24);
                    }

                    final fx = store.items[index];

                    final home = _str(fx, ['home', 'home_name', 'homeTeam', 'home_team'], 'Home');
                    final away = _str(fx, ['away', 'away_name', 'awayTeam', 'away_team'], 'Away');
                    final status = _str(fx, ['status'], '');
                    final kickoff = _str(fx, ['kickoff', 'date', 'utc_date', 'fixture_date'], '');

                    // odds (dacă există)
                    final oHome = _num(fx, ['p_home', 'odds_home', 'home_odds']);
                    final oDraw = _num(fx, ['p_draw', 'odds_draw', 'draw_odds']);
                    final oAway = _num(fx, ['p_away', 'odds_away', 'away_odds']);

                    String? rightChip;
                    if (oHome != null || oDraw != null || oAway != null) {
                      rightChip =
                          '1:${oHome?.toStringAsFixed(2) ?? '-'}  X:${oDraw?.toStringAsFixed(2) ?? '-'}  2:${oAway?.toStringAsFixed(2) ?? '-'}';
                    }

                    return Card(
                      child: ListTile(
                        title: Text('$home vs $away'),
                        subtitle: Text(
                          [
                            if (kickoff.isNotEmpty) kickoff,
                            if (status.isNotEmpty) status,
                          ].join(' • '),
                        ),
                        trailing: rightChip == null
                            ? null
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                ),
                                child: Text(rightChip, style: const TextStyle(fontSize: 12)),
                              ),
                        onTap: () => _showPrediction(fx),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
