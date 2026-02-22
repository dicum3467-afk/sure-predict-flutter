import 'package:flutter/material.dart';
import '../state/fixtures_store.dart';
import '../services/sure_predict_service.dart';
import '../api/api_client.dart';

class FixturesScreen extends StatefulWidget {
  final String leagueName;
  final String leagueId; // UUID din backend (id)
  final String providerLeagueId; // ex: api_39 (opțional, îl păstrăm)
  final String country; // opțional
  final String baseUrl;

  const FixturesScreen({
    super.key,
    required this.leagueName,
    required this.leagueId,
    required this.providerLeagueId,
    required this.country,
    this.baseUrl = 'https://sure-predict-backend.onrender.com',
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  late final ApiClient api;
  late final SurePredictService service;
  late final FixturesStore store;

  @override
  void initState() {
    super.initState();
    api = ApiClient(baseUrl: widget.baseUrl);
    service = SurePredictService(api);
    store = FixturesStore(service);

    // Load inițial
    store.loadInitial(widget.leagueId);
  }

  @override
  void dispose() {
    api.dispose();
    store.dispose();
    super.dispose();
  }

  String _fmtDateTime(String s) {
    // backend trimite "2026-02-19 14:24:31" sau ISO; încercăm să parsăm safe
    try {
      final dt = DateTime.parse(s.replaceFirst(' ', 'T'));
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return s;
    }
  }

  Widget _oddsChip(dynamic fx) {
    final home = fx['p_home'];
    final draw = fx['p_draw'];
    final away = fx['p_away'];

    String two(dynamic v) {
      if (v == null) return '--';
      if (v is num) return v.toStringAsFixed(2);
      return v.toString();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '1:${two(home)} X:${two(draw)} 2:${two(away)}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showPredictionSheet(dynamic fx) async {
    final providerFixtureId = fx['provider_fixture_id']?.toString();
    if (providerFixtureId == null || providerFixtureId.isEmpty) return;

    try {
      final pred = await service.getPrediction(providerFixtureId);
      if (!mounted) return;

      String pct(dynamic v) {
        if (v == null) return '--';
        if (v is num) return '${(v * 100).toStringAsFixed(1)}%';
        return v.toString();
      }

      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fx['home']} vs ${fx['away']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text('provider_fixture_id: $providerFixtureId'),
                const SizedBox(height: 12),

                Text('Home: ${pct(pred['p_home'])}'),
                Text('Draw: ${pct(pred['p_draw'])}'),
                Text('Away: ${pct(pred['p_away'])}'),
                const SizedBox(height: 10),
                Text('GG: ${pct(pred['p_gg'])}'),
                Text('Over 2.5: ${pct(pred['p_over25'])}'),
                Text('Under 2.5: ${pct(pred['p_under25'])}'),
                const SizedBox(height: 12),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leagueName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => store.refresh(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.isLoading && store.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // header range (opțional)
          final header = Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'limit=${store.limit} offset=${store.offset}',
                    style: TextStyle(color: Colors.black.withOpacity(0.6)),
                  ),
                ),
                if (store.isLoadingMore)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          );

          if (store.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No fixtures'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => store.refresh(),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // auto-load more când ajungi aproape de fund
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 250) {
                store.loadMore();
              }
              return false;
            },
            child: ListView.separated(
              itemCount: store.items.length + 1, // +1 pentru footer
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                if (index == 0) return header;

                final i = index - 1;
                if (i >= store.items.length) {
                  // footer
                  if (!store.hasMore) {
                    return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: Text('End')),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(18),
                    child: Center(
                      child: ElevatedButton(
                        // IMPORTANT: apel corect pentru Future<void>
                        onPressed: () => store.loadMore(),
                        child: const Text('Load more'),
                      ),
                    ),
                  );
                }

                final fx = store.items[i];
                final home = fx['home']?.toString() ?? '-';
                final away = fx['away']?.toString() ?? '-';
                final status = fx['status']?.toString() ?? '';
                final when = fx['start_time']?.toString() ?? fx['kickoff_at']?.toString() ?? '';

                return ListTile(
                  title: Text(
                    '$home vs $away',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${_fmtDateTime(when)} • $status'),
                  trailing: _oddsChip(fx),
                  onTap: () => _showPredictionSheet(fx),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
