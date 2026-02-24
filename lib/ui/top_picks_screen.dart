import 'dart:async';
import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';

class TopPicksScreen extends StatefulWidget {
  final SurePredictService service;
  final FavoritesStore favoritesStore;

  const TopPicksScreen({
    super.key,
    required this.service,
    required this.favoritesStore,
  });

  @override
  State<TopPicksScreen> createState() => _TopPicksScreenState();
}

class _TopPicksScreenState extends State<TopPicksScreen> {
  // ✅ Prag Top Picks
  double _threshold = 0.60; // 60%

  // ✅ Status filter
  // all | scheduled | live | finished
  String _status = 'all';

  // ✅ Mode: global vs top-per-league
  bool _topPerLeague = false;
  int _topNPerLeague = 10;

  // ✅ Days: today / tomorrow
  int _dayIndex = 0; // 0=today, 1=tomorrow

  String _runType = 'initial';

  // Pagination
  static const int _pageSize = 80;
  int _offset = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  final List<Map<String, dynamic>> _all = [];
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

  // ---------- date helpers ----------
  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  ({String from, String to, String label}) _rangeForIndex(int idx) {
    final base = _today();
    final day = base.add(Duration(days: idx));
    // range = aceeași zi (from=day, to=day)
    return (from: _fmtDate(day), to: _fmtDate(day), label: idx == 0 ? 'Today' : 'Tomorrow');
  }

  // ---------- data helpers ----------
  double _num(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _fmtPct(double p) => '${(p * 100).toStringAsFixed(0)}%';

  String _keyOf(Map<String, dynamic> it) {
    final pf = (it['provider_fixture_id'] ?? '').toString();
    if (pf.isNotEmpty) return 'pf:$pf';
    final id = (it['id'] ?? '').toString();
    if (id.isNotEmpty) return 'id:$id';
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

  bool _statusMatches(Map<String, dynamic> it) {
    if (_status == 'all') return true;
    final st = (it['status'] ?? '').toString().toLowerCase().trim();
    if (_status == 'live') return _isLiveStatus(st);
    return st == _status;
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

  Color _confidenceBg(BuildContext context, double p) {
    final cs = Theme.of(context).colorScheme;
    if (p >= 0.70) return cs.tertiaryContainer;
    if (p >= 0.60) return cs.secondaryContainer;
    return cs.surfaceContainerHighest;
  }

  Color _confidenceFg(BuildContext context, double p) {
    final cs = Theme.of(context).colorScheme;
    if (p >= 0.70) return cs.onTertiaryContainer;
    if (p >= 0.60) return cs.onSecondaryContainer;
    return cs.onSurfaceVariant;
  }

  bool _hasLiveInList(List<Map<String, dynamic>> list) {
    for (final it in list) {
      if (_isLiveStatus((it['status'] ?? '').toString())) return true;
    }
    return false;
  }

  void _startOrStopTimer(List<Map<String, dynamic>> top) {
    _timer?.cancel();
    _timer = null;

    if (!_hasLiveInList(top)) return;

    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      await _refreshSoft();
    });
  }

  // ---------- loading ----------
  Future<void> _loadInitial() async {
    final r = _rangeForIndex(_dayIndex);

    setState(() {
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _offset = 0;
      _error = null;
      _all.clear();
      _seen.clear();
    });

    try {
      final page = await widget.service.getFixtures(
        leagueIds: const [], // ✅ ALL leagues
        from: r.from,
        to: r.to,
        limit: _pageSize,
        offset: 0,
        runType: _runType,
        // NU trimitem status aici (filtrăm local) ca să nu pierdem LIVE mixed
      );

      for (final it in page) {
        final k = _keyOf(it);
        if (_seen.add(k)) _all.add(it);
      }

      setState(() {
        _offset = page.length;
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;

    final r = _rangeForIndex(_dayIndex);

    setState(() {
      _loadingMore = true;
      _error = null;
    });

    try {
      final page = await widget.service.getFixtures(
        leagueIds: const [],
        from: r.from,
        to: r.to,
        limit: _pageSize,
        offset: _offset,
        runType: _runType,
      );

      for (final it in page) {
        final k = _keyOf(it);
        if (_seen.add(k)) _all.add(it);
      }

      setState(() {
        _offset += page.length;
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _refreshSoft() async {
    final r = _rangeForIndex(_dayIndex);
    final want = _all.length.clamp(80, 160);

    try {
      final page = await widget.service.getFixtures(
        leagueIds: const [],
        from: r.from,
        to: r.to,
        limit: want,
        offset: 0,
        runType: _runType,
      );

      _all.clear();
      _seen.clear();
      for (final it in page) {
        final k = _keyOf(it);
        if (_seen.add(k)) _all.add(it);
      }

      setState(() {
        _offset = page.length;
        _hasMore = page.length == want;
      });
    } catch (_) {}
  }

  Future<void> _refreshHard() async => _loadInitial();

  // ---------- build Top Picks ----------
  List<Map<String, dynamic>> _buildTopPicks() {
    // 1) filter status
    final filtered = _all.where(_statusMatches).toList();

    // 2) compute best + threshold filter
    final List<Map<String, dynamic>> picks = [];
    for (final it in filtered) {
      final best = _bestPick(it);
      if (best.p >= _threshold) {
        final copy = Map<String, dynamic>.from(it);
        copy['_best_label'] = best.label;
        copy['_best_p'] = best.p;
        picks.add(copy);
      }
    }

    // 3) sort: LIVE first, best desc, kickoff asc
    picks.sort((a, b) {
      final ra = _statusRank(a);
      final rb = _statusRank(b);
      if (ra != rb) return ra.compareTo(rb);

      final pa = (a['_best_p'] as double?) ?? 0.0;
      final pb = (b['_best_p'] as double?) ?? 0.0;
      if (pa != pb) return pb.compareTo(pa);

      return _parseKickoff(a).compareTo(_parseKickoff(b));
    });

    // 4) option: top per league
    if (_topPerLeague) {
      final out = <Map<String, dynamic>>[];
      final byLeague = <String, List<Map<String, dynamic>>>{};

      for (final it in picks) {
        final leagueId = (it['league_id'] ?? '').toString();
        byLeague.putIfAbsent(leagueId, () => []).add(it);
      }

      // ia primele N din fiecare ligă, păstrând sortarea internă
      byLeague.forEach((_, list) {
        out.addAll(list.take(_topNPerLeague));
      });

      // resort global după aceleași reguli
      out.sort((a, b) {
        final ra = _statusRank(a);
        final rb = _statusRank(b);
        if (ra != rb) return ra.compareTo(rb);

        final pa = (a['_best_p'] as double?) ?? 0.0;
        final pb = (b['_best_p'] as double?) ?? 0.0;
        if (pa != pb) return pb.compareTo(pa);

        return _parseKickoff(a).compareTo(_parseKickoff(b));
      });

      return out;
    }

    return picks;
  }

  // ---------- prediction sheet ----------
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
            future: widget.service.getPrediction(providerFixtureId: providerId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return SizedBox(height: 220, child: Center(child: Text('Eroare: ${snap.error}')));
              }

              final pred = snap.data ?? <String, dynamic>{};

              String fmt(dynamic v) {
                final n = v is num ? v.toDouble() : double.tryParse(v.toString());
                if (n == null) return '-';
                return '${(n * 100).toStringAsFixed(0)}%';
              }

              final pHome = pred['p_home'] ?? item['p_home'];
              final pDraw = pred['p_draw'] ?? item['p_draw'];
              final pAway = pred['p_away'] ?? item['p_away'];
              final pOver = pred['p_over25'] ?? item['p_over25'];
              final pUnder = pred['p_under25'] ?? item['p_under25'];

              final home = (item['home'] ?? '').toString();
              final away = (item['away'] ?? '').toString();

              final bestLabel = (item['_best_label'] ?? '').toString();
              final bestP = (item['_best_p'] is double) ? (item['_best_p'] as double) : _num(item['_best_p']);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$home vs $away', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  if (bestLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _confidenceBg(context, bestP),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'BEST $bestLabel ${_fmtPct(bestP)}',
                        style: TextStyle(
                          color: _confidenceFg(context, bestP),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _PredRow(label: '1 (Home)', value: fmt(pHome)),
                  _PredRow(label: 'X (Draw)', value: fmt(pDraw)),
                  _PredRow(label: '2 (Away)', value: fmt(pAway)),
                  const Divider(height: 24),
                  _PredRow(label: 'Over 2.5', value: fmt(pOver)),
                  _PredRow(label: 'Under 2.5', value: fmt(pUnder)),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _rangeForIndex(_dayIndex);
    final top = _buildTopPicks();

    // live timer based on TOP list
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOrStopTimer(top));

    return AnimatedBuilder(
      animation: widget.favoritesStore,
      builder: (context, _) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Eroare: $_error'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _refreshHard, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Top Picks • ${r.label}', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshHard),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Today/Tomorrow switch
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Today')),
                      ButtonSegment(value: 1, label: Text('Tomorrow')),
                    ],
                    selected: {_dayIndex},
                    onSelectionChanged: (s) {
                      setState(() => _dayIndex = s.first);
                      _loadInitial();
                    },
                  ),

                  const SizedBox(height: 10),

                  // Status filter + top-per-league
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
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                            DropdownMenuItem(value: 'live', child: Text('Live')),
                            DropdownMenuItem(value: 'finished', child: Text('Finished')),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'all'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Top/league'),
                          value: _topPerLeague,
                          onChanged: (v) => setState(() => _topPerLeague = v),
                        ),
                      ),
                    ],
                  ),

                  if (_topPerLeague)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Text('N:'),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: _topNPerLeague,
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5')),
                              DropdownMenuItem(value: 10, child: Text('10')),
                              DropdownMenuItem(value: 15, child: Text('15')),
                            ],
                            onChanged: (v) => setState(() => _topNPerLeague = v ?? 10),
                          ),
                          const Spacer(),
                          Text('Fixtures: ${_all.length} • Picks: ${top.length}'),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Fixtures: ${_all.length} • Picks: ${top.length}'),
                    ),

                  const SizedBox(height: 8),

                  // Threshold slider
                  Text('Prag: ${(100 * _threshold).toStringAsFixed(0)}%'),
                  Slider(
                    value: _threshold,
                    min: 0.55,
                    max: 0.80,
                    divisions: 25,
                    label: '${(100 * _threshold).toStringAsFixed(0)}%',
                    onChanged: (v) => setState(() => _threshold = v),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshHard,
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: top.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == top.length) {
                      if (_loadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (_hasMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Scroll pentru mai multe fixtures…')),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Gata.')),
                      );
                    }

                    final it = top[idx];

                    final home = (it['home'] ?? '').toString();
                    final away = (it['away'] ?? '').toString();
                    final status = (it['status'] ?? '').toString();
                    final kickoff = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();
                    final leagueId = (it['league_id'] ?? '').toString();

                    final bestLabel = (it['_best_label'] ?? '—').toString();
                    final bestP = (it['_best_p'] is double) ? (it['_best_p'] as double) : _num(it['_best_p']);

                    final fav = widget.favoritesStore.isFavorite(it);

                    return Column(
                      children: [
                        ListTile(
                          leading: IconButton(
                            icon: Icon(fav ? Icons.star : Icons.star_border),
                            color: fav ? Colors.amber : null,
                            onPressed: () => widget.favoritesStore.toggle(it),
                          ),
                          title: Text('$home vs $away'),
                          subtitle: Text('League: $leagueId\nStatus: $status • Kickoff: $kickoff'),
                          isThreeLine: true,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _confidenceBg(context, bestP),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'BEST $bestLabel ${_fmtPct(bestP)}',
                              style: TextStyle(
                                color: _confidenceFg(context, bestP),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          onTap: () => _openPrediction(context, it),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
