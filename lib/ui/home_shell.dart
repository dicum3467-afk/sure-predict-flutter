import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/settings_store.dart';

class TopPicksTab extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final SettingsStore settings;

  const TopPicksTab({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.settings,
  });

  @override
  State<TopPicksTab> createState() => _TopPicksTabState();
}

class _TopPicksTabState extends State<TopPicksTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final leagues = widget.leaguesStore.selectedIds;

      final data = await widget.service.getTopPicks(
        leagueIds: leagues,
        threshold: widget.settings.threshold,
        force: force,
      );

      _items = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _load(force: true);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Eroare: $_error'));
    }

    if (_items.isEmpty) {
      return const Center(child: Text('No top picks'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final m = _items[i];

          final home = m['home'] ?? '?';
          final away = m['away'] ?? '?';
          final prob = (m['confidence'] ?? 0).toDouble();

          return Card(
            child: ListTile(
              title: Text('$home vs $away'),
              subtitle:
                  Text('Confidence: ${(prob * 100).toStringAsFixed(0)}%'),
              trailing: const Icon(Icons.star, color: Colors.amber),
            ),
          );
        },
      ),
    );
  }
}
