import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;
  final FavoritesStore favoritesStore;
  final List<String> leagueIds; // ligile selectate (filtrare locală)

  const FixturesScreen({
    super.key,
    required this.service,
    required this.favoritesStore,
    required this.leagueIds,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  final List<Map<String, dynamic>> _items = [];
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;

  String _status = 'all'; // all/scheduled/live/finished

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Set<String> get _selectedLeagueIds =>
      widget.leagueIds.map((e) => e.toString()).toSet();

  List<Map<String, dynamic>> _filterBySelectedLeagues(
    List<Map<String, dynamic>> list,
  ) {
    final selected = _selectedLeagueIds;
    if (selected.isEmpty) return list;

    return list.where((it) {
      final id = (it['league_id'] ?? it['leagueId'] ?? it['leagueid'])?.toString();
      return id != null && selected.contains(id);
    }).toList();
  }

  Future<void> _initialLoad({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });

    try {
      final data = await widget.service.getFixtures(
        limit: _limit,
        offset: _offset,
        status: _status,
        runType: 'initial',
        force: force,
      );

      final page = _filterBySelectedLeagues(List<Map<String, dynamic>>.from(data));

      setState(() {
        _items.addAll(page);
        // offset îl creștem cu câte am primit DIN BACKEND
        // ca să paginezi corect chiar dacă filtrarea locală micșorează lista
        _offset += data.length;
        _hasMore = data.length == _limit;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);

    try {
      final data = await widget.service.getFixtures(
        limit: _limit,
        offset: _offset,
        status: _status,
        runType: 'initial',
        force: false,
      );

      final page = _filterBySelectedLeagues(List<Map<String, dynamic>>.from(data));

      setState(() {
        _items.addAll(page);
        _offset += data.length;
        _hasMore = data.length == _limit;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() => _initialLoad(force: true);

  String _fmtTeam(dynamic v) => (v ?? '').toString();

  String _fmtKickoff(dynamic it) {
    final v = it['kickoff_at'] ?? it['kickoffAt'] ?? it['date'] ?? it['time'];
    if (v == null) return '';
    return v.toString();
  }

  String _fmtLeague(dynamic it) {
    final v = it['league_name'] ?? it['leagueName'] ?? it['league'] ?? '';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Eroare la fixtures:\n$_error',
            textAlign: TextAlign.center,
          ),
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
              _initialLoad(force: true);
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No fixtures')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        if (_hasMore) {
                          _loadMore();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return const SizedBox(height: 12);
                      }

                      final it = _items[i];

                      final home = _fmtTeam(it['home']);
                      final away = _fmtTeam(it['away']);
                      final league = _fmtLeague(it);
                      final kickoff = _fmtKickoff(it);

                      final pHome = it['p_home'] ?? it['pHome'];
                      final pDraw = it['p_draw'] ?? it['pDraw'];
                      final pAway = it['p_away'] ?? it['pAway'];

                      String pct(dynamic v) {
                        if (v == null) return '-';
                        final num? n = (v is num) ? v : num.tryParse(v.toString());
                        if (n == null) return '-';
                        return '${(n * 100).toStringAsFixed(0)}%';
                      }

                      return ListTile(
                        leading: const Icon(Icons.sports_soccer),
                        title: Text('$home vs $away'),
                        subtitle: Text(
                          [
                            if (league.isNotEmpty) league,
                            if (kickoff.isNotEmpty) kickoff,
                            'H ${pct(pHome)} | D ${pct(pDraw)} | A ${pct(pAway)}',
                          ].where((e) => e.trim().isNotEmpty).join(' • '),
                        ),
                        onTap: () async {
                          final providerId = (it['provider_fixture_id'] ??
                                  it['providerFixtureId'] ??
                                  it['id'])
                              ?.toString();

                          if (providerId == null || providerId.isEmpty) return;

                          try {
                            final pred = await widget.service.getPrediction(providerId);

                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Prediction'),
                                content: SingleChildScrollView(
                                  child: Text(pred.toString()),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Prediction error: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
