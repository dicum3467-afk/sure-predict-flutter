// lib/ui/top_picks_tab.dart
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
  late Future<List<Map<String, dynamic>>> _future;

  // interval default (poți schimba în UI dacă vrei)
  String _from = _todayIso();
  String _to = _todayPlusDaysIso(3);

  @override
  void initState() {
    super.initState();
    _future = _load();

    // re-render când se schimbă settings
    widget.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  static String _todayIso() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return d.toIso8601String().substring(0, 10);
  }

  static String _todayPlusDaysIso(int days) {
    final now = DateTime.now().add(Duration(days: days));
    final d = DateTime(now.year, now.month, now.day);
    return d.toIso8601String().substring(0, 10);
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // asigură leagues (pentru nume)
    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      await widget.leaguesStore.load();
    }

    // “din toate ligile” = toate league ids din store
    final leagueIds = widget.leaguesStore.items
        .map((l) => (l['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    // dacă nu sunt ligi încă, return gol
    if (leagueIds.isEmpty) return <Map<String, dynamic>>[];

    return widget.service.getFixtures(
      leagueIds: leagueIds,
      from: _from,
      to: _to,
      limit: 250,
      offset: 0,
      runType: 'top_picks',
      useCache: true,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      // reîncarcă dar tot cu cache; dacă vrei “hard refresh”, fă useCache:false în service.
      _future = _load();
    });
    await _future;
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

  // Odds:
  // - dacă backend trimite o_home/o_draw/o_away folosim aia.
  // - altfel, derivăm “odds” simple: 1/p (cu protecție).
  double _oddForOutcome(Map<String, dynamic> item, String outcome) {
    String key;
    String pKey;
    switch (outcome) {
      case 'H':
        key = 'o_home';
        pKey = 'p_home';
        break;
      case 'D':
        key = 'o_draw';
        pKey = 'p_draw';
        break;
      case 'A':
      default:
        key = 'o_away';
        pKey = 'p_away';
    }

    final raw = item[key];
    final o = raw is num ? raw.toDouble() : double.tryParse((raw ?? '').toString());
    if (o != null && o > 1.0) return o;

    final pRaw = item[pKey];
    final p = pRaw is num ? pRaw.toDouble() : double.tryParse((pRaw ?? '').toString());
    if (p == null || p <= 0) return 0.0;

    final derived = 1.0 / p;
    if (derived.isFinite && derived > 1.0) return derived;
    return 0.0;
  }

  // Expected Value (simplu): EV = p * odd - 1
  double _expectedValue(double p, double odd) {
    if (p <= 0 || odd <= 1.0) return -999.0;
    return (p * odd) - 1.0;
  }

  // pick best outcome din H/D/A
  ({String outcome, double p, double odd, double ev}) _bestPick(Map<String, dynamic> item) {
    double pH = _toDouble(item['p_home']);
    double pD = _toDouble(item['p_draw']);
    double pA = _toDouble(item['p_away']);

    final oddH = _oddForOutcome(item, 'H');
    final oddD = _oddForOutcome(item, 'D');
    final oddA = _oddForOutcome(item, 'A');

    final evH = _expectedValue(pH, oddH);
    final evD = _expectedValue(pD, oddD);
    final evA = _expectedValue(pA, oddA);

    // max EV, tie-break: probability
    var best = ('H', pH, oddH, evH);

    void consider(String o, double p, double odd, double ev) {
      final cur = best;
      final curEv = cur.$4;
      final curP = cur.$2;
      if (ev > curEv) {
        best = (o, p, odd, ev);
      } else if (ev == curEv && p > curP) {
        best = (o, p, odd, ev);
      }
    }

    consider('D', pD, oddD, evD);
    consider('A', pA, oddA, evA);

    return (outcome: best.$1, p: best.$2, odd: best.$3, ev: best.$4);
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    final n = v is num ? v.toDouble() : double.tryParse(v.toString());
    return n ?? 0.0;
  }

  String _outcomeLabel(String o) {
    switch (o) {
      case 'H':
        return '1 (Home)';
      case 'D':
        return 'X (Draw)';
      case 'A':
      default:
        return '2 (Away)';
    }
  }

  bool _statusOk(Map<String, dynamic> item) {
    final filter = (widget.settings.status ?? 'all').toString();
    if (filter == 'all') return true;

    final st = (item['status'] ?? '').toString().toLowerCase();
    return st == filter.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final threshold = widget.settings.threshold; // ex: 0.60
    final topPerLeague = widget.settings.topPerLeague;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Picks'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Eroare: ${snap.error}'),
              ),
            );
          }

          final data = snap.data ?? <Map<String, dynamic>>[];
          if (data.isEmpty) {
            return const Center(child: Text('Nu există meciuri în intervalul ales.'));
          }

          // build picks
          final picks = <_Pick>[];

          for (final item in data) {
            if (!_statusOk(item)) continue;

            final best = _bestPick(item);

            // filtrează după threshold
            if (best.p < threshold) continue;

            // păstrează doar EV “decent” (opțional)
            if (!best.ev.isFinite) continue;

            final leagueId = (item['league_id'] ?? 'unknown').toString();
            final home = (item['home'] ?? '').toString();
            final away = (item['away'] ?? '').toString();
            final kickoff = (item['kickoff'] ?? '').toString();

            picks.add(_Pick(
              leagueId: leagueId,
              leagueName: _leagueName(leagueId),
              home: home,
              away: away,
              kickoff: kickoff,
              outcome: best.outcome,
              p: best.p,
              odd: best.odd,
              ev: best.ev,
              raw: item,
            ));
          }

          // grupare per league
          final byLeague = <String, List<_Pick>>{};
          for (final p in picks) {
            byLeague.putIfAbsent(p.leagueId, () => <_Pick>[]).add(p);
          }

          // sort in fiecare liga: EV desc, p desc
          for (final k in byLeague.keys) {
            byLeague[k]!.sort((a, b) {
              final ev = b.ev.compareTo(a.ev);
              if (ev != 0) return ev;
              return b.p.compareTo(a.p);
            });
          }

          // “top per league” sau toate
          final finalList = <_Pick>[];
          final leagueKeys = byLeague.keys.toList()
            ..sort((a, b) => _leagueName(a).compareTo(_leagueName(b)));

          for (final leagueId in leagueKeys) {
            final list = byLeague[leagueId]!;
            if (topPerLeague) {
              finalList.add(list.first);
            } else {
              finalList.addAll(list);
            }
          }

          if (finalList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Nu există Top Picks la threshold ${(threshold * 100).toStringAsFixed(0)}%.'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _HeaderCard(
                  from: _from,
                  to: _to,
                  threshold: threshold,
                  topPerLeague: topPerLeague,
                  total: finalList.length,
                ),
                const SizedBox(height: 12),

                for (final p in finalList) ...[
                  Card(
                    child: ListTile(
                      title: Text('${p.home} vs ${p.away}'),
                      subtitle: Text('${p.leagueName}\nKickoff: ${p.kickoff}'),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_outcomeLabel(p.outcome)),
                          const SizedBox(height: 4),
                          Text('${(p.p * 100).toStringAsFixed(0)}%'),
                          Text('EV ${(p.ev * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                      onTap: () {
                        // poți deschide prediction sheet dacă vrei.
                        // momentan doar dialog cu detalii.
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('${p.home} vs ${p.away}'),
                            content: Text(
                              'League: ${p.leagueName}\n'
                              'Pick: ${_outcomeLabel(p.outcome)}\n'
                              'Prob: ${_fmtPct(p.p)}\n'
                              'Odd: ${p.odd.toStringAsFixed(2)}\n'
                              'EV: ${(p.ev * 100).toStringAsFixed(1)}%\n',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Pick {
  final String leagueId;
  final String leagueName;
  final String home;
  final String away;
  final String kickoff;

  final String outcome; // H/D/A
  final double p;
  final double odd;
  final double ev;

  final Map<String, dynamic> raw;

  _Pick({
    required this.leagueId,
    required this.leagueName,
    required this.home,
    required this.away,
    required this.kickoff,
    required this.outcome,
    required this.p,
    required this.odd,
    required this.ev,
    required this.raw,
  });
}

class _HeaderCard extends StatelessWidget {
  final String from;
  final String to;
  final double threshold;
  final bool topPerLeague;
  final int total;

  const _HeaderCard({
    required this.from,
    required this.to,
    required this.threshold,
    required this.topPerLeague,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interval: $from → $to', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Threshold: ${(threshold * 100).toStringAsFixed(0)}%'),
            Text('Mode: ${topPerLeague ? "Top 1 per league" : "All picks"}'),
            const SizedBox(height: 6),
            Text('Total picks: $total'),
          ],
        ),
      ),
    );
  }
}
