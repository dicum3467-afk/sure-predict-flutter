import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;
  final FavoritesStore favoritesStore;

  /// ligi selectate (poate fi gol => All leagues)
  final List<String> leagueIds;

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

  List<Map<String, dynamic>> _filterBySelectedLeagues(List<Map<String, dynamic>> list) {
    final selected = widget.leagueIds.map((e) => e.toString()).toSet();
    if (selected.isEmpty) return list; // All leagues

    return list.where((it) {
      final lid = (it['league_id'] ?? it['leagueId'] ?? '').toString();
      return selected.contains(lid);
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
      final from = DateTime.now().toUtc();
      final to = from.add(const Duration(days: 7));

      final data = await widget.service.getFixtures(
        from: from.toIso8601String(),
        to: to.toIso8601String(),
        limit: _limit,
        offset: _offset,
        status: _status,
        runType: 'initial',
        force: force,
      );

      final pageRaw = List<Map<String, dynamic>>.from(data);
      final page = _filterBySelectedLeagues(pageRaw);

      setState(() {
        _items.addAll(page);
        _offset += pageRaw.length; // offset după ce ai primit din server
        _hasMore = pageRaw.length == _limit;
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
      final from = DateTime.now().toUtc();
      final to = from.add(const Duration(days: 7));

      final data = await widget.service.getFixtures(
        from: from.toIso8601String(),
        to: to.toIso8601String(),
        limit: _limit,
        offset: _offset,
        status: _status,
        runType: 'initial',
        force: false,
      );

      final pageRaw = List<Map<String, dynamic>>.from(data);
      final page = _filterBySelectedLeagues(pageRaw);

      setState(() {
        _items.addAll(page);
        _offset += pageRaw.length;
        _hasMore = pageRaw.length == _limit;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() => _initialLoad(force: true);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Eroare: $_error'));
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

                      final home = (it['home'] ?? '').toString();
                      final away = (it['away'] ?? '').toString();
                      final league = (it['league'] ?? it['league_name'] ?? '').toString();
                      final time = (it['time'] ?? it['date'] ?? it['kickoff'] ?? '').toString();

                      return ListTile(
                        leading: const Icon(Icons.sports_soccer),
                        title: Text('$home vs $away'),
                        subtitle: Text([league, time].where((e) => e.isNotEmpty).join(' • ')),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
