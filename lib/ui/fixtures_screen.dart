import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/fixtures_store.dart';
import 'prediction_sheet.dart';

class FixturesScreen extends StatefulWidget {
  final String leagueId;
  final String leagueName;
  final SurePredictService service;

  const FixturesScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
    required this.service,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  late final FixturesStore store;

  @override
  void initState() {
    super.initState();
    store = FixturesStore(widget.service);

    // Load inițial
    store.loadInitial(widget.leagueId);
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
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

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 48),
            const SizedBox(height: 10),
            Text(
              'Nu sunt meciuri pentru perioada selectată.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Apasă Refresh sau schimbă intervalul de timp.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: store.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 10),
            Text(
              'Eroare la încărcare',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: store.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Încearcă din nou'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fixtureTile(Map<String, dynamic> fx) {
    final home = _str(fx, const ['home', 'home_name'], 'Home');
    final away = _str(fx, const ['away', 'away_name'], 'Away');
    final status = _str(fx, const ['status'], '').toUpperCase();
    final providerFixtureId = _str(fx, const ['provider_fixture_id', 'providerFixtureId'], '');

    return Card(
      child: ListTile(
        title: Text('$home vs $away'),
        subtitle: status.isEmpty ? null : Text(status),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Deschide bottom sheet cu predicția
          showPredictionSheet(
            context: context,
            service: widget.service,
            fixture: fx,
            providerFixtureId: providerFixtureId,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leagueName),
        actions: [
          IconButton(
            onPressed: store.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          // Loading inițial
          if (store.isLoading && store.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Eroare + nu avem nimic încă
          if (store.error != null && store.items.isEmpty) {
            return _errorState(store.error!);
          }

          // Empty state când API întoarce []
          if (store.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: store.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 40),
                  _emptyState(),
                ],
              ),
            );
          }

          // Listă normală
          return RefreshIndicator(
            onRefresh: store.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: store.items.length,
              itemBuilder: (context, i) => _fixtureTile(store.items[i]),
            ),
          );
        },
      ),
    );
  }
}
