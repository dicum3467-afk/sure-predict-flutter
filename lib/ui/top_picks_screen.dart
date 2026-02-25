import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../state/settings_store.dart';

class TopPicksScreen extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;
  final SettingsStore settings;

  const TopPicksScreen({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
    required this.settings,
  });

  @override
  State<TopPicksScreen> createState() => _TopPicksScreenState();
}

class _TopPicksScreenState extends State<TopPicksScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  // interval default
  String _from = _fmt(DateTime.now());
  String _to = _fmt(DateTime.now().add(const Duration(days: 7)));

  // filtre PRO
  double _threshold = 0.62; // probabilitate minimă recomandată
  int _maxPicks = 30;
  bool _groupByLeague = true;
  bool _preferO25 = true; // preferă O2.5 dacă e “mai bun” ca 1X2
  String _status = 'scheduled'; // scheduled / live / finished / all
  bool _force = false;

  @override
  void initState() {
    super.initState();
    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load();
    }
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final leagueIds = widget.leaguesStore.items
        .map((e) => (e['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    // dacă nu sunt ligi încărcate, încercăm oricum (service poate returna ceva)
    return widget.service.getTopPicksPro(
      leagueIds: leagueIds,
      from: _from,
      to: _to,
      status: _status == 'all' ? null : _status,
      runType: 'initial',
      threshold: _threshold,
      maxPicks: _maxPicks,
      preferOver25: _preferO25,
      force: _force,
    );
  }

  void _refresh({bool force = false}) {
    setState(() {
      _force = force;
      _future = _load();
    });
  }

  static String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _leagueName(String leagueId) {
    for (final l in widget.leaguesStore.items) {
      final id = (l['id'] ?? '').toString();
      if (id == leagueId) return (l['name'] ?? leagueId).toString();
    }
    return leagueId;
  }

  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  Color _badgeColor(double score, ColorScheme cs) {
    if (score >= 0.30) return Colors.green;
    if (score >= 0.20) return Colors.lightGreen;
    if (score >= 0.14) return Colors.orange;
    return cs.outline;
  }

  String _badgeText(double score) {
    if (score >= 0.30) return 'HOT';
    if (score >= 0.20) return 'PRO';
    if (score >= 0.14) return 'OK';
    return 'LOW';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Picks PRO'),
        actions: [
          IconButton(
            tooltip: 'Refresh (cache)',
            onPressed: () => _refresh(force: false),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Force refresh (ignora cache)',
            onPressed: () => _refresh(force: true),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Eroare: ${snap.error}'),
            );
          }

          final data = snap.data ?? [];
          if (data.isEmpty) {
            return _filtersPanel(
              context,
              below: const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Nu există Top Picks pentru filtrele curente.')),
              ),
            );
          }

          // group by league dacă e setat
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final it in data) {
            final leagueId = (it['league_id'] ?? 'unknown').toString();
            grouped.putIfAbsent(leagueId, () => []).add(it);
          }

          // sort ligi după nume
          final leagueIds = grouped.keys.toList()
            ..sort((a, b) => _leagueName(a).compareTo(_leagueName(b)));

          final list = _groupByLeague
              ? ListView.builder(
                  itemCount: leagueIds.length,
                  itemBuilder: (context, idx) {
                    final leagueId = leagueIds[idx];
                    final items = grouped[leagueId] ?? [];
                    return _leagueSection(context, leagueId, items);
                  },
                )
              : ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _pickTile(context, data[i]),
                );

          return _filtersPanel(context, below: Expanded(child: list));
        },
      ),
    );
  }

  Widget _filtersPanel(BuildContext context, {required Widget below}) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // panel filtre
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'From',
                      value: _from,
                      onChanged: (v) => setState(() => _from = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: 'To',
                      value: _to,
                      onChanged: (v) => setState(() => _to = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                        DropdownMenuItem(value: 'live', child: Text('Live')),
                        DropdownMenuItem(value: 'finished', child: Text('Finished')),
                        DropdownMenuItem(value: 'all', child: Text('All')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _maxPicks,
                      decoration: const InputDecoration(
                        labelText: 'Max picks',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 30, child: Text('30')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                      ],
                      onChanged: (v) => setState(() => _maxPicks = v ?? 30),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Threshold: ${(_threshold * 100).toStringAsFixed(0)}%'),
                        Slider(
                          value: _threshold,
                          min: 0.55,
                          max: 0.80,
                          divisions: 25,
                          onChanged: (v) => setState(() => _threshold = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Group by league'),
                      value: _groupByLeague,
                      onChanged: (v) => setState(() => _groupByLeague = v),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prefer Over 2.5'),
                      value: _preferO25,
                      onChanged: (v) => setState(() => _preferO25 = v),
                    ),
                  ),
                ],
              ),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _refresh(force: false),
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Recompute'),
                ),
              )
            ],
          ),
        ),

        // content
        Expanded(child: below),
      ],
    );
  }

  Widget _leagueSection(BuildContext context, String leagueId, List<Map<String, dynamic>> items) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: cs.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _leagueName(leagueId),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${items.length}'),
            ],
          ),
        ),
        ...items.map((it) => Column(
              children: [
                _pickTile(context, it),
                const Divider(height: 1),
              ],
            )),
      ],
    );
  }

  Widget _pickTile(BuildContext context, Map<String, dynamic> it) {
    final cs = Theme.of(context).colorScheme;

    final home = (it['home'] ?? '').toString();
    final away = (it['away'] ?? '').toString();
    final kickoff = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();
    final status = (it['status'] ?? '').toString();

    final market = (it['_pick_market'] ?? '').toString(); // ex: "1", "X", "2", "O2.5", "U2.5"
    final pickProb = (it['_pick_prob'] is num)
        ? (it['_pick_prob'] as num).toDouble()
        : double.tryParse((it['_pick_prob'] ?? '').toString()) ?? 0.0;

    final score = (it['_pick_score'] is num)
        ? (it['_pick_score'] as num).toDouble()
        : double.tryParse((it['_pick_score'] ?? '').toString()) ?? 0.0;

    final p1 = it['p_home'];
    final px = it['p_draw'];
    final p2 = it['p_away'];
    final po = it['p_over25'];
    final pu = it['p_under25'];

    final badge = _badgeText(score);

    return ListTile(
      title: Text('$home vs $away'),
      subtitle: Text('Status: $status\nKickoff: $kickoff'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
            label: Text('$market • ${_fmtPct(pickProb)}'),
            backgroundColor: _badgeColor(score, cs).withOpacity(0.12),
            side: BorderSide(color: _badgeColor(score, cs)),
          ),
          const SizedBox(height: 6),
          Text(badge, style: TextStyle(color: _badgeColor(score, cs), fontWeight: FontWeight.w700)),
        ],
      ),
      onTap: () {
        // simplu: bottom sheet cu detalii probabilități
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$home vs $away', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  _row('Pick', '$market • ${_fmtPct(pickProb)}'),
                  _row('Score', score.toStringAsFixed(3)),
                  const Divider(height: 24),
                  _row('1 (Home)', _fmtPct(p1)),
                  _row('X (Draw)', _fmtPct(px)),
                  _row('2 (Away)', _fmtPct(p2)),
                  const Divider(height: 24),
                  _row('Over 2.5', _fmtPct(po)),
                  _row('Under 2.5', _fmtPct(pu)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(a)),
          Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        hintText: 'YYYY-MM-DD',
      ),
      onChanged: onChanged,
    );
  }
}
