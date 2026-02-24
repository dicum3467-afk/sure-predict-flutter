import 'dart:async';
import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;
  final FavoritesStore favoritesStore;

  /// Dacă e listă goală => ALL leagues (service nu trimite league_ids)
  final List<String> leagueIds;

  final Map<String, String> leagueNamesById;
  final String title;

  const FixturesScreen({
    super.key,
    required this.service,
    required this.favoritesStore,
    required this.leagueIds,
    required this.leagueNamesById,
    required this.title,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  // Default range (poți schimba oricând)
  String _from = '2026-02-01';
  String _to = '2026-02-28';
  String _runType = 'initial';

  // Pagination
  static const int _pageSize = 60;
  int _offset = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  final List<Map<String, dynamic>> _items = [];
  final Set<String> _seen = {};

  final ScrollController _scroll = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.favoritesStore.load();
    _loadInitial();

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  String _leagueTitle(String leagueId) => widget.leagueNamesById[leagueId] ?? leagueId;

  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  double _num(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _itemKey(Map<String, dynamic> it) {
    final pf = (it['provider_fixture_id'] ?? '').toString();
    if (pf.isNotEmpty) return 'pf:$pf';
    final id = (it['id'] ?? '').toString();
    if (id.isNotEmpty) return 'id:$id';
    // fallback
    final lg = (it['league_id'] ?? '').toString();
    final ko = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();
    final h = (it['home'] ?? '').toString();
    final a = (it['away'] ?? '').toString();
    return '$lg|$ko|$h|$a';
  }

  bool _isLiveStatus(String s) {
    final x = s.toLowerCase().trim();
    return x == 'live' || x == 'inplay' || x == 'playing';
  }

  bool _hasLiveNow() {
    for (final it in _items) {
      if (_isLiveStatus((it['status'] ?? '').toString())) return true;
    }
    return false;
  }

  void _startOrStopLiveTimer() {
    _timer?.cancel();
    _timer = null;

    if (!_hasLiveNow()) return;

    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      // refresh „soft”: reîncarcă de la 0 până la cât ai deja
      await _refreshSoft();
    });
  }

  // Best pick + confidence
  ({String label, double p}) _bestPick(Map<String, dynamic> it) {
    final pHome = _num(it['p_home']);
    final pDraw = _num(it['p_draw']);
    final pAway = _num(it['p_away']);
    final pOver = _num(it['p_over25']);
    final pUnder = _num(it['p_under25']);

    final candidates = <String, double>{
      '1': pHome,
      'X': pDraw,
      '2': pAway,
      'O2.5': pOver,
      'U2.5': pUnder,
    };

    String bestLabel = '—';
    double best = 0.0;
    candidates.forEach((k, v) {
      if (v > best) {
        best = v;
        bestLabel = k;
      }
    });

    return (label: bestLabel, p: best);
  }

  Color _confidenceColor(BuildContext context, double p) {
    final cs = Theme.of(context).colorScheme;
    if (p >= 0.70) return cs.tertiaryContainer; // strong
    if (p >= 0.60) return cs.secondaryContainer; // medium
    return cs.surfaceContainerHighest; // low
  }

  Color _confidenceTextColor(BuildContext context, double p) {
    final cs = Theme.of(context).colorScheme;
    if (p >= 0.70) return cs.onTertiaryContainer;
    if (p >= 0.60) return cs.onSecondaryContainer;
    return cs.onSurfaceVariant;
  }

  Map<String, List<Map<String, dynamic>>> _groupByLeague(List<Map<String, dynamic>> items) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final leagueId = (it['league_id'] ?? 'unknown').toString();
      map.putIfAbsent(leagueId, () => <Map<String, dynamic>>[]).add(it);
    }
    return map;
  }

  DateTime _parseKickoff(Map<String, dynamic> it) {
    final s = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _statusRank(Map<String, dynamic> it) {
    final st = (it['status'] ?? '').toString();
    if (_isLiveStatus(st)) return 0;
    if (st.toLowerCase() == 'scheduled') return 1;
    if (st.toLowerCase() == 'finished') return 2;
    return 9;
  }

  void _sortItems(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final ra = _statusRank(a);
      final rb = _statusRank(b);
      if (ra != rb) return ra.compareTo(rb);
      return _parseKickoff(a).compareTo(_parseKickoff(b));
    });
  }

  // ---------- Loading ----------
  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _offset = 0;
      _error = null;
      _items.clear();
      _seen.clear();
    });

    try {
      final page = await widget.service.getFixtures(
        leagueIds: widget.leagueIds, // gol => ALL leagues
        from: _from,
        to: _to,
        limit: _pageSize,
        offset: 0,
        runType: _runType,
      );

      for (final it in page) {
        final k = _itemKey(it);
        if (_seen.add(k)) _items.add(it);
      }

      _sortItems(_items);

      setState(() {
        _offset = page.length;
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
      _startOrStopLiveTimer();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
      _error = null;
    });

    try {
      final page = await widget.service.getFixtures(
        leagueIds: widget.leagueIds,
        from: _from,
        to: _to,
        limit: _pageSize,
        offset: _offset,
        runType: _runType,
      );

      for (final it in page) {
        final k = _itemKey(it);
        if (_seen.add(k)) _items.add(it);
      }

      _sortItems(_items);

      setState(() {
        _offset += page.length;
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingMore = false);
      _startOrStopLiveTimer();
    }
  }

  Future<void> _refreshSoft() async {
    // reîncarcă de la 0 până la cât ai deja (max 180 ca să nu fie greu)
    final want = _items.length.clamp(60, 180);
    try {
      final page = await widget.service.getFixtures(
        leagueIds: widget.leagueIds,
        from: _from,
        to: _to,
        limit: want,
        offset: 0,
        runType: _runType,
      );

      _items.clear();
      _seen.clear();
      for (final it in page) {
        final k = _itemKey(it);
        if (_seen.add(k)) _items.add(it);
      }
      _sortItems(_items);

      setState(() {
        _offset = page.length;
        _hasMore = page.length == want; // aproximativ
      });
    } catch (_) {
      // ignorăm soft errors (nu strici UX)
    } finally {
      _startOrStopLiveTimer();
    }
  }

  Future<void> _refreshHard() async {
    await _loadInitial();
  }

  // ---------- Prediction sheet ----------
  void _openPrediction(BuildContext context, Map<String, dynamic> item) {
    final providerId = (item['provider_fixture_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    final best = _bestPick(item);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Map<String, dynamic>>(
            future: widget.service.getPrediction(providerFixtureId: providerId),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(context, 'BEST ${best.label}', _fmtPct(best.p), best.p),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PredRow(label: '1 (Home)', value: _fmtPct(pHome)),
                  _PredRow(label: 'X (Draw)', value: _fmtPct(pDraw)),
                  _PredRow(label: '2 (Away)', value: _fmtPct(pAway)),
                  const Divider(height: 24),
                  _PredRow(label: 'Over 2.5', value: _fmtPct(pOver)),
                  _PredRow(label: 'Under 2.5', value: _fmtPct(pUnder)),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String left, String right, double p) {
    final bg = _confidenceColor(context, p);
    final fg = _confidenceTextColor(context, p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(left, style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(width: 10),
          Text(right, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.favoritesStore,
      builder: (context, _) {
        if (_loading) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (_error != null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshHard)],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Eroare: $_error'),
              ),
            ),
          );
        }

        if (_items.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshHard)],
            ),
            body: const Center(child: Text('Nu există meciuri în perioada aleasă.')),
          );
        }

        final grouped = _groupByLeague(_items);
        final leagueIds = grouped.keys.toList()
          ..sort((a, b) => _leagueTitle(a).toLowerCase().compareTo(_leagueTitle(b).toLowerCase()));

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshHard),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshHard,
            child: ListView.builder(
              controller: _scroll,
              itemCount: leagueIds.length + 1, // footer
              itemBuilder: (context, idx) {
                if (idx == leagueIds.length) {
                  if (_loadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!_hasMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('Gata.')),
                    );
                  }
                  return const SizedBox(height: 100);
                }

                final leagueId = leagueIds[idx];
                final items = grouped[leagueId] ?? <Map<String, dynamic>>[];
                items.sort((a, b) => _parseKickoff(a).compareTo(_parseKickoff(b)));

                final liveCount = items.where((e) => _isLiveStatus((e['status'] ?? '').toString())).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _leagueTitle(leagueId),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (liveCount > 0)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.6, end: 1.0),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeInOut,
                              builder: (context, value, child) => Opacity(opacity: value, child: child),
                              onEnd: () {}, // pulse effect (rebuild on list changes)
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Theme.of(context).colorScheme.errorContainer,
                                ),
                                child: Text(
                                  'LIVE $liveCount',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Text('${items.length}'),
                        ],
                      ),
                    ),

                    ...items.map((item) {
                      final home = (item['home'] ?? '').toString();
                      final away = (item['away'] ?? '').toString();
                      final status = (item['status'] ?? '').toString();
                      final kickoff = (item['kickoff_at'] ?? item['kickoff'] ?? '').toString();

                      final fav = widget.favoritesStore.isFavorite(item);
                      final best = _bestPick(item);

                      return Column(
                        children: [
                          ListTile(
                            leading: IconButton(
                              icon: Icon(fav ? Icons.star : Icons.star_border),
                              color: fav ? Colors.amber : null,
                              onPressed: () => widget.favoritesStore.toggle(item),
                            ),
                            title: Text('$home vs $away'),
                            subtitle: Text('Status: $status\nKickoff: $kickoff'),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _confidenceColor(context, best.p),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'BEST ${best.label} ${_fmtPct(best.p)}',
                                    style: TextStyle(
                                      color: _confidenceTextColor(context, best.p),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('1 ${_fmtPct(item["p_home"])}  X ${_fmtPct(item["p_draw"])}  2 ${_fmtPct(item["p_away"])}'),
                              ],
                            ),
                            onTap: () => _openPrediction(context, item),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),

                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PredRow extends StatelessWidget {
  final String label;
  final String value;

  const _PredRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
