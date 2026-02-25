import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../state/settings_store.dart';

class TopPicksTab extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;
  final SettingsStore settings;

  const TopPicksTab({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
    required this.settings,
  });

  @override
  State<TopPicksTab> createState() => _TopPicksTabState();
}

class _TopPicksTabState extends State<TopPicksTab> {
  late Future<List<Map<String, dynamic>>> _future;

  String _from = _fmtDate(DateTime.now());
  String _to = _fmtDate(DateTime.now().add(const Duration(days: 7)));
  String _runType = 'initial';

  // FREE limit (MAX MONEY)
  static const int _freeLimit = 5;
  bool _vip = false; // toggle demo (poți lega de VipStore dacă vrei în HomeShell)

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // ia toate ligile disponibile
    final leagues = widget.leaguesStore.items;
    final leagueIds = leagues
        .map((e) => (e['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    // status default din Settings (all / scheduled / live / finished)
    final status = widget.settings.status;

    // 👇 ajustează AICI dacă semnătura ta e diferită
    final data = await widget.service.getFixtures(
      leagueIds: leagueIds,
      from: _from,
      to: _to,
      limit: 400,
      offset: 0,
      runType: _runType,
      status: status == 'all' ? null : status,
    );

    // normalizează la List<Map<String,dynamic>>
    final items = data.cast<Map<String, dynamic>>();

    // calculează picks + scor
    final threshold = widget.settings.threshold; // ex 0.65
    final picks = <Map<String, dynamic>>[];

    for (final it in items) {
      final pHome = _toDouble(it['p_home']);
      final pDraw = _toDouble(it['p_draw']);
      final pAway = _toDouble(it['p_away']);

      final best = _bestMarket(pHome, pDraw, pAway);
      final bestP = best.$2;

      if (bestP < threshold) continue; // filtrul PRO

      final odds = _extractOdds(it); // value bets if odds exist
      final ev = _expectedValue(bestP, odds[best.$1]);

      final score = _score(bestP: bestP, ev: ev, kickoff: it['kickoff']);

      picks.add({
        ...it,
        '_pick': best.$1, // '1', 'X', '2'
        '_p': bestP,
        '_ev': ev,
        '_score': score,
      });
    }

    // sortare GOD MODE: scor desc (prob + EV + recency)
    picks.sort((a, b) => (_toDouble(b['_score'])).compareTo(_toDouble(a['_score'])));

    // Top per league (opțional)
    if (widget.settings.topPerLeague) {
      final byLeague = <String, List<Map<String, dynamic>>>{};
      for (final p in picks) {
        final lid = (p['league_id'] ?? 'unknown').toString();
        (byLeague[lid] ??= []).add(p);
      }
      final out = <Map<String, dynamic>>[];
      for (final entry in byLeague.entries) {
        // ia max 3 per league (poți schimba)
        out.addAll(entry.value.take(3));
      }
      out.sort((a, b) => (_toDouble(b['_score'])).compareTo(_toDouble(a['_score'])));
      return out;
    }

    return picks;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  // return (market, prob)
  (String, double) _bestMarket(double pHome, double pDraw, double pAway) {
    var market = '1';
    var p = pHome;

    if (pDraw > p) {
      market = 'X';
      p = pDraw;
    }
    if (pAway > p) {
      market = '2';
      p = pAway;
    }
    return (market, p);
  }

  // odds map: '1'/'X'/'2' -> odd
  Map<String, double> _extractOdds(Map<String, dynamic> it) {
    // dacă backend-ul tău returnează alt nume, mapează aici
    // ex: odds_1 / odds_x / odds_2  sau odd_home/odd_draw/odd_away
    final o1 = _toDouble(it['odds_1'] ?? it['odd_home'] ?? it['odds_home']);
    final ox = _toDouble(it['odds_x'] ?? it['odd_draw'] ?? it['odds_draw']);
    final o2 = _toDouble(it['odds_2'] ?? it['odd_away'] ?? it['odds_away']);
    return {'1': o1, 'X': ox, '2': o2};
  }

  // EV = p*odds - 1  (dacă nu avem odds => 0)
  double _expectedValue(double p, double odd) {
    if (odd <= 1.01) return 0;
    return (p * odd) - 1.0;
  }

  // scor: probabilitate + EV bonus + recency bonus
  double _score({required double bestP, required double ev, required dynamic kickoff}) {
    final pScore = bestP * 100.0; // 0.72 -> 72
    final evBonus = (ev > 0 ? (ev * 80.0) : 0); // EV+ ridică în top
    final timeBonus = _timeBonus(kickoff);
    return pScore + evBonus + timeBonus;
  }

  double _timeBonus(dynamic kickoff) {
    final s = (kickoff ?? '').toString();
    final dt = DateTime.tryParse(s);
    if (dt == null) return 0;
    final hours = dt.difference(DateTime.now()).inHours;
    // meciurile apropiate primesc ușor bonus (dar mic)
    if (hours < 0) return 0;
    if (hours <= 6) return 6;
    if (hours <= 24) return 3;
    return 0;
  }

  String _leagueName(String leagueId) {
    for (final l in widget.leaguesStore.items) {
      final id = (l['id'] ?? '').toString();
      if (id == leagueId) return (l['name'] ?? leagueId).toString();
    }
    return leagueId;
  }

  String _fmtPct(double p) => '${(p * 100).toStringAsFixed(0)}%';

  String _hotLabel(double score, double ev) {
    if (ev > 0.10) return 'VALUE+';
    if (score >= 80) return 'HOT';
    if (score >= 72) return 'PRO';
    return 'OK';
  }

  Color _badgeColor(String tag, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (tag) {
      case 'VALUE+':
        return cs.tertiary;
      case 'HOT':
        return cs.primary;
      case 'PRO':
        return cs.secondary;
      default:
        return cs.outlineVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Picks PRO'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: _vip ? 'VIP ON' : 'VIP OFF (demo toggle)',
            onPressed: () => setState(() => _vip = !_vip),
            icon: Icon(_vip ? Icons.lock_open : Icons.lock_outline),
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

          final all = snap.data ?? [];
          if (all.isEmpty) {
            return const Center(child: Text('Nu am găsit Top Picks pentru perioada aleasă.'));
          }

          // MAX MONEY: free gating
          final visible = _vip ? all : all.take(_freeLimit).toList();
          final lockedCount = all.length - visible.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _HeaderCard(
                  from: _from,
                  to: _to,
                  threshold: widget.settings.threshold,
                  topPerLeague: widget.settings.topPerLeague,
                  total: all.length,
                  shown: visible.length,
                  vip: _vip,
                  locked: lockedCount > 0 ? lockedCount : 0,
                ),

                if (!_vip && lockedCount > 0) ...[
                  const SizedBox(height: 10),
                  _PaywallCard(
                    lockedCount: lockedCount,
                    onUnlock: () => setState(() => _vip = true), // demo unlock
                  ),
                ],

                const SizedBox(height: 12),

                // list
                for (final it in visible) _PickTile(
                  item: it,
                  leagueName: _leagueName((it['league_id'] ?? 'unknown').toString()),
                  pct: _fmtPct(_toDouble(it['_p'])),
                  pick: (it['_pick'] ?? '').toString(),
                  ev: _toDouble(it['_ev']),
                  score: _toDouble(it['_score']),
                  tag: _hotLabel(_toDouble(it['_score']), _toDouble(it['_ev'])),
                  badgeColor: _badgeColor(_hotLabel(_toDouble(it['_score']), _toDouble(it['_ev'])), context),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String from;
  final String to;
  final double threshold;
  final bool topPerLeague;
  final int total;
  final int shown;
  final bool vip;
  final int locked;

  const _HeaderCard({
    required this.from,
    required this.to,
    required this.threshold,
    required this.topPerLeague,
    required this.total,
    required this.shown,
    required this.vip,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRO Engine', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Interval: $from → $to'),
            Text('Threshold: ${(threshold * 100).toStringAsFixed(0)}%'),
            Text('Mode: ${topPerLeague ? "Top per league" : "Global top"}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                Chip(label: Text('Total: $total')),
                Chip(label: Text('Afișate: $shown')),
                Chip(
                  label: Text(vip ? 'VIP ON' : 'FREE'),
                  backgroundColor: vip ? cs.primaryContainer : cs.surfaceContainerHighest,
                ),
                if (!vip && locked > 0) Chip(label: Text('Locked: $locked')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallCard extends StatelessWidget {
  final int lockedCount;
  final VoidCallback onUnlock;

  const _PaywallCard({required this.lockedCount, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.lock, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ai încă $lockedCount picks blocate.\nActivează VIP ca să vezi tot (demo unlock).',
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onUnlock,
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String leagueName;
  final String pick;
  final String pct;
  final double ev;
  final double score;
  final String tag;
  final Color badgeColor;

  const _PickTile({
    required this.item,
    required this.leagueName,
    required this.pick,
    required this.pct,
    required this.ev,
    required this.score,
    required this.tag,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final home = (item['home'] ?? '').toString();
    final away = (item['away'] ?? '').toString();
    final kickoff = (item['kickoff'] ?? '').toString();
    final status = (item['status'] ?? '').toString();

    final evTxt = ev > 0 ? 'EV+: ${(ev * 100).toStringAsFixed(1)}%' : 'EV: n/a';
    final sub = 'Liga: $leagueName\nStatus: $status\nKickoff: $kickoff\n$evTxt';

    return Card(
      child: ListTile(
        title: Text('$home vs $away'),
        subtitle: Text(sub),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$tag  $pick', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            Text('$pct • ${score.toStringAsFixed(1)}'),
          ],
        ),
      ),
    );
  }
}
