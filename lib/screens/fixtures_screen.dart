import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;

  /// Dacă e listă goală => ia din TOATE ligile (service nu trimite league_ids)
  final List<String> leagueIds;

  /// id -> name (din selector)
  final Map<String, String> leagueNamesById;

  final String title;

  const FixturesScreen({
    super.key,
    required this.service,
    required this.leagueIds,
    required this.leagueNamesById,
    required this.title,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  // default range (poți schimba cum vrei)
  String _from = '2026-02-01';
  String _to = '2026-02-28';
  String _runType = 'initial';

  // paging (opțional – aici păstrăm simplu: încărcare unică limit mare)
  int _limit = 200;
  int _offset = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _load() {
    _future = widget.service.getFixtures(
      leagueIds: widget.leagueIds,
      from: _from,
      to: _to,
      limit: _limit,
      offset: _offset,
      runType: _runType,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  // ---------- Helpers: LIVE auto refresh ----------
  bool _isLiveStatus(String s) {
    final x = s.toLowerCase().trim();
    return x == 'live' || x == 'inplay' || x == 'playing';
  }

  bool _hasLive(List<Map<String, dynamic>> items) {
    for (final it in items) {
      final st = (it['status'] ?? '').toString();
      if (_isLiveStatus(st)) return true;
    }
    return false;
  }

  void _startOrStopLiveTimer(bool shouldRun) {
    _timer?.cancel();
    _timer = null;

    if (!shouldRun) return;

    // refresh la 30s doar dacă există LIVE
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  // ---------- Helpers: sortare pro ----------
  int _statusRank(Map<String, dynamic> it) {
    final st = (it['status'] ?? '').toString();
    if (_isLiveStatus(st)) return 0; // LIVE first
    if (st.toLowerCase() == 'scheduled') return 1;
    if (st.toLowerCase() == 'finished') return 2;
    return 9;
  }

  DateTime _parseKickoff(Map<String, dynamic> it) {
    final s = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ---------- Helpers: grouping ----------
  Map<String, List<Map<String, dynamic>>> _groupByLeague(
    List<Map<String, dynamic>> items,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final leagueId = (it['league_id'] ?? 'unknown').toString();
      map.putIfAbsent(leagueId, () => <Map<String, dynamic>>[]).add(it);
    }
    return map;
  }

  String _leagueTitle(String leagueId) {
    return widget.leagueNamesById[leagueId] ?? leagueId;
  }

  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  // ---------- Prediction Bottom Sheet ----------
  void _openPrediction(BuildContext context, Map<String, dynamic> item) {
    final providerId = (item['provider_fixture_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: widget.service.getPrediction(providerFixtureId: providerId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snap.hasError) {
                  return SizedBox(
                    height: 220,
                    child: Center(child: Text('Eroare: ${snap.error}')),
                  );
                }

                final pred = snap.data ?? <String, dynamic>{};

                // backend-ul tău poate întoarce direct p_home/p_draw/... sau alt obiect
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
                    Text(
                      '$home vs $away',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Eroare: ${snapshot.error}'),
              ),
            );
          }

          final data = (snapshot.data ?? <Map<String, dynamic>>[]);

          if (data.isEmpty) {
            // oprește timerul dacă nu ai date
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startOrStopLiveTimer(false);
            });

            return const Center(
              child: Text('Nu există meciuri în perioada aleasă.'),
            );
          }

          // ✅ Sortare PRO: LIVE first, apoi status, apoi kickoff
          data.sort((a, b) {
            final ra = _statusRank(a);
            final rb = _statusRank(b);
            if (ra != rb) return ra.compareTo(rb);
            return _parseKickoff(a).compareTo(_parseKickoff(b));
          });

          // ✅ Live timer doar dacă există LIVE
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startOrStopLiveTimer(_hasLive(data));
          });

          // ✅ Group by league
          final grouped = _groupByLeague(data);

          // Ordonăm ligile după nume (mai frumos)
          final leagueIds = grouped.keys.toList()
            ..sort((a, b) => _leagueTitle(a).compareTo(_leagueTitle(b)));

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: leagueIds.length,
              itemBuilder: (context, idx) {
                final leagueId = leagueIds[idx];
                final items = grouped[leagueId] ?? <Map<String, dynamic>>[];

                // sort în interior după kickoff (menține live first deja din sort global)
                items.sort((a, b) => _parseKickoff(a).compareTo(_parseKickoff(b)));

                final liveCount = items.where((e) {
                  return _isLiveStatus((e['status'] ?? '').toString());
                }).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ----- Header ligă -----
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Theme.of(context).colorScheme.errorContainer,
                              ),
                              child: Text(
                                'LIVE $liveCount',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Text('${items.length}'),
                        ],
                      ),
                    ),

                    // ----- Lista meciuri -----
                    ...items.map((item) {
                      final home = (item['home'] ?? '').toString();
                      final away = (item['away'] ?? '').toString();
                      final status = (item['status'] ?? '').toString();
                      final kickoff = (item['kickoff_at'] ?? item['kickoff'] ?? '').toString();

                      final pHome = item['p_home'];
                      final pDraw = item['p_draw'];
                      final pAway = item['p_away'];

                      return Column(
                        children: [
                          ListTile(
                            title: Text('$home vs $away'),
                            subtitle: Text('Status: $status\nKickoff: $kickoff'),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('1  ${_fmtPct(pHome)}'),
                                Text('X  ${_fmtPct(pDraw)}'),
                                Text('2  ${_fmtPct(pAway)}'),
                              ],
                            ),
                            onTap: () => _openPrediction(context, item),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          );
        },
      ),
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
