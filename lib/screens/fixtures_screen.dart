import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;

  /// Dacă e [] sau null => ALL leagues
  final List<String>? leagueIds;

  /// map id -> name (poate fi gol dacă ALL)
  final Map<String, String> leagueNamesById;

  final String title;

  const FixturesScreen({
    super.key,
    required this.service,
    this.leagueIds,
    required this.leagueNamesById,
    required this.title,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  final ScrollController _scroll = ScrollController();

  // perioadă implicită (poți schimba după cum vrei)
  String _from = '2026-02-01';
  String _to = '2026-02-28';

  String _runType = 'initial';
  String? _status; // ex: scheduled/live/finished, etc.

  // paging
  static const int _pageSize = 50;
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  // data
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _seenKeys = {}; // dedupe

  @override
  void initState() {
    super.initState();
    _loadInitial();

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  String _leagueTitle(String leagueId) {
    final name = widget.leagueNamesById[leagueId];
    return (name == null || name.trim().isEmpty) ? leagueId : name;
  }

  /// cheie stabilă pentru dedupe
  String _itemKey(Map<String, dynamic> it) {
    final id = (it['id'] ?? '').toString();
    if (id.isNotEmpty) return 'id:$id';

    final pf = (it['provider_fixture_id'] ?? it['providerFixtureId'] ?? '')
        .toString();
    final lg = (it['league_id'] ?? '').toString();
    final ko = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();
    final h = (it['home'] ?? '').toString();
    final a = (it['away'] ?? '').toString();
    return 'pf:$pf|lg:$lg|ko:$ko|$h|$a';
  }

  Map<String, List<Map<String, dynamic>>> _groupByLeague(
    List<Map<String, dynamic>> items,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final leagueId = (it['league_id'] ?? 'unknown').toString();
      map.putIfAbsent(leagueId, () => []).add(it);
    }
    return map;
  }

  List<String> _sortedLeagueIds(Map<String, List<Map<String, dynamic>>> grouped) {
    final ids = grouped.keys.toList();

    // ✅ „formula” recomandată:
    // 1) ligile cu mai multe meciuri primele
    // 2) apoi alfabetic după nume
    ids.sort((a, b) {
      final ca = grouped[a]?.length ?? 0;
      final cb = grouped[b]?.length ?? 0;
      if (ca != cb) return cb.compareTo(ca);
      return _leagueTitle(a).toLowerCase().compareTo(_leagueTitle(b).toLowerCase());
    });

    return ids;
  }

  // ---------- loading ----------

  Future<void> _loadInitial() async {
    setState(() {
      _error = null;
      _items.clear();
      _seenKeys.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _refresh() async {
    await _loadInitial();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await widget.service.getFixtures(
        leagueIds: (widget.leagueIds != null && widget.leagueIds!.isNotEmpty)
            ? widget.leagueIds
            : null, // ✅ ALL leagues
        from: _from,
        to: _to,
        limit: _pageSize,
        offset: _offset,
        runType: _runType,
        status: _status,
      );

      // dedupe + append
      int added = 0;
      for (final it in page) {
        final k = _itemKey(it);
        if (_seenKeys.add(k)) {
          _items.add(it);
          added++;
        }
      }

      // dacă backend întoarce mai puține decât pageSize -> end
      final got = page.length;
      setState(() {
        _offset += got;
        _hasMore = got == _pageSize; // standard paging
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------- prediction modal ----------

  void _openPrediction(BuildContext context, Map<String, dynamic> item) {
    final providerId =
        (item['provider_fixture_id'] ?? item['providerFixtureId'] ?? '').toString();
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

                final pred = snap.data ?? {};
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
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByLeague(_items);
    final leagueIds = _sortedLeagueIds(grouped);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scroll,
          itemCount: leagueIds.length + 1, // + footer loader
          itemBuilder: (context, idx) {
            if (idx == leagueIds.length) {
              // footer
              if (_error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Eroare: $_error',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }
              if (_isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!_hasMore && _items.isNotEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('Gata.')),
                );
              }
              if (_items.isEmpty && !_isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Nu există meciuri în perioada aleasă.')),
                );
              }
              return const SizedBox(height: 80);
            }

            final leagueId = leagueIds[idx];
            final items = grouped[leagueId] ?? [];

            // (optional) sort meciuri după kickoff
            items.sort((a, b) =>
                (a['kickoff_at'] ?? a['kickoff'] ?? '').toString().compareTo(
                      (b['kickoff_at'] ?? b['kickoff'] ?? '').toString(),
                    ));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // header liga
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
                      Text('${items.length}'),
                    ],
                  ),
                ),

                // lista meciuri
                ...items.map((item) {
                  final home = (item['home'] ?? '').toString();
                  final away = (item['away'] ?? '').toString();
                  final status = (item['status'] ?? '').toString();
                  final kickoff = (item['kickoff_at'] ?? item['kickoff'] ?? '').toString();

                  return Column(
                    children: [
                      ListTile(
                        title: Text('$home vs $away'),
                        subtitle: Text('Status: $status\nKickoff: $kickoff'),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('1 ${_fmtPct(item["p_home"])}'),
                            Text('X ${_fmtPct(item["p_draw"])}'),
                            Text('2 ${_fmtPct(item["p_away"])}'),
                          ],
                        ),
                        onTap: () => _openPrediction(context, item),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
              ],
            );
          },
        ),
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
