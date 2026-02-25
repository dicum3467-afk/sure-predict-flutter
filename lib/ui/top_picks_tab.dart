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

  String _idFromLeague(Map<String, dynamic> l) {
    final v = l['id'] ?? l['league_id'] ?? l['leagueId'];
    return (v ?? '').toString();
  }

  List<String> _allLeagueIds() {
    final ids = <String>[];
    for (final l in widget.leaguesStore.items) {
      final id = _idFromLeague(l);
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // dacă ligile nu sunt încă încărcate, încearcă să le încarci
      if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
        await widget.leaguesStore.load();
      }

      final leagueIds = _allLeagueIds();
      if (leagueIds.isEmpty) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }

      // IMPORTANT: presupune că în SurePredictService există getTopPicks(...)
      final data = await widget.service.getTopPicks(
        leagueIds: leagueIds,
        threshold: widget.settings.threshold,
        force: force,
      );

      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _load(force: true);

  String _fmtTeam(dynamic v) => (v ?? '').toString();
  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Eroare: $_error'));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No top picks')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final it = _items[i];

          final league = (it['league'] ?? it['league_name'] ?? it['competition'] ?? '').toString();
          final home = _fmtTeam(it['home']);
          final away = _fmtTeam(it['away']);

          final pHome = it['p_home'] ?? it['pHome'];
          final pDraw = it['p_draw'] ?? it['pDraw'];
          final pAway = it['p_away'] ?? it['pAway'];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (league.isNotEmpty)
                    Text(league, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text('$home vs $away', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text('Home: ${_fmtPct(pHome)}')),
                      Expanded(child: Text('Draw: ${_fmtPct(pDraw)}')),
                      Expanded(child: Text('Away: ${_fmtPct(pAway)}')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
