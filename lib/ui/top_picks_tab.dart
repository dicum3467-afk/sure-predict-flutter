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

  // optional: dacă vrei filtru și aici
  String _status = 'all'; // all/scheduled/live/finished

  @override
  void initState() {
    super.initState();
    _load(force: false);
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

  Future<void> _ensureLeaguesLoaded() async {
    // dacă nu sunt încă încărcate, încearcă să le încarci
    if (widget.leaguesStore.items.isEmpty) {
      await widget.leaguesStore.load();
    }
  }

  Future<void> _load({required bool force}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _ensureLeaguesLoaded();

      final leagueIds = _allLeagueIds();
      if (leagueIds.isEmpty) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }

      final data = await widget.service.getTopPicks(
        leagueIds: leagueIds,
        threshold: widget.settings.threshold,
        topPerLeague: widget.settings.topPerLeague,
        status: _status,
        force: force,
        limit: 200,
      );

      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() => _load(force: true);

  String _t(dynamic v) => (v ?? '').toString();

  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final d = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return '-';
    return '${(d * 100).toStringAsFixed(0)}%';
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
              DropdownMenuItem(value: 'live', child: Text('Live')),
              DropdownMenuItem(value: 'finished', child: Text('Finished')),
            ],
            onChanged: (v) {
              setState(() => _status = v ?? 'all');
              _load(force: true);
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final it = _items[i];

                final league = _t(it['league_name'] ?? it['competition'] ?? it['league']);
                final home = _t(it['home']);
                final away = _t(it['away']);

                // probabilități (în backend-ul tău apar ca p_home/p_draw/p_away + p_gg/p_over25/p_under25)
                final pHome = it['p_home'] ?? it['pHome'];
                final pDraw = it['p_draw'] ?? it['pDraw'];
                final pAway = it['p_away'] ?? it['pAway'];

                final pGG = it['p_gg'] ?? it['pGG'];
                final pOver = it['p_over25'] ?? it['pOver25'];
                final pUnder = it['p_under25'] ?? it['pUnder25'];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (league.isNotEmpty)
                          Text(
                            league,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '$home vs $away',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: Text('Home: ${_fmtPct(pHome)}')),
                            Expanded(child: Text('Draw: ${_fmtPct(pDraw)}')),
                            Expanded(child: Text('Away: ${_fmtPct(pAway)}')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text('GG: ${_fmtPct(pGG)}')),
                            Expanded(child: Text('O2.5: ${_fmtPct(pOver)}')),
                            Expanded(child: Text('U2.5: ${_fmtPct(pUnder)}')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
