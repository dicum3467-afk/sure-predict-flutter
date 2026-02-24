import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';

class FavoritesScreen extends StatelessWidget {
  final SurePredictService service;
  final FavoritesStore favoritesStore;

  const FavoritesScreen({
    super.key,
    required this.service,
    required this.favoritesStore,
  });

  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  void _openPrediction(BuildContext context, Map<String, dynamic> item) {
    final providerId = (item['provider_fixture_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Map<String, dynamic>>(
            future: service.getPrediction(providerFixtureId: providerId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return SizedBox(height: 220, child: Center(child: Text('Eroare: ${snap.error}')));
              }

              final pred = snap.data ?? <String, dynamic>{};

              final pHome = pred['p_home'] ?? item['p_home'];
              final pDraw = pred['p_draw'] ?? item['p_draw'];
              final pAway = pred['p_away'] ?? item['p_away'];
              final pOver = pred['p_over25'] ?? item['p_over25'];
              final pUnder = pred['p_under25'] ?? item['p_under25'];

              final home = (item['home'] ?? '').toString();
              final away = (item['away'] ?? '').toString();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$home vs $away', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  _row('1 (Home)', _fmtPct(pHome)),
                  _row('X (Draw)', _fmtPct(pDraw)),
                  _row('2 (Away)', _fmtPct(pAway)),
                  const Divider(height: 24),
                  _row('Over 2.5', _fmtPct(pOver)),
                  _row('Under 2.5', _fmtPct(pUnder)),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = favoritesStore.items;

    return Scaffold(
      body: items.isEmpty
          ? const Center(child: Text('Nu ai favorite încă ⭐'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final f = items[index];

                final home = (f['home'] ?? '').toString();
                final away = (f['away'] ?? '').toString();
                final kickoff = (f['kickoff'] ?? '').toString();
                final status = (f['status'] ?? '').toString();

                return ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text('$home vs $away'),
                  subtitle: Text('Status: $status\nKickoff: $kickoff'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => favoritesStore.toggle(f),
                  ),
                  onTap: () => _openPrediction(context, f),
                );
              },
            ),
      floatingActionButton: items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => favoritesStore.clear(),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear'),
            ),
    );
  }
}
