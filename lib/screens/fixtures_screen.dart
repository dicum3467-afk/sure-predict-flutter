import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';
import '../state/favorites_store.dart';
import '../state/leagues_store.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;
  final FavoritesStore favoritesStore;
  final LeaguesStore leaguesStore;

  const FixturesScreen({
    super.key,
    required this.service,
    required this.favoritesStore,
    required this.leaguesStore,
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

  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  // ⭐ IMPORTANT: luăm league IDs selectate
  List<String> _selectedLeagueIds() {
    return widget.leaguesStore.selectedIds.toList();
  }

  Future<void> _initialLoad({bool force = false}) async {
    final leagueIds = _selectedLeagueIds();

    if (leagueIds.isEmpty) {
      setState(() {
        _items.clear();
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });

    try {
      final data = await widget.service.getFixtures(
        leagueIds: leagueIds,
        limit: _limit,
        offset: _offset,
        status: _status,
        runType: 'initial',
        force: force,
      );

      setState(() {
        _items.addAll(List<Map<String, dynamic>>.from(data));
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

    final leagueIds = _selectedLeagueIds();
    if (leagueIds.isEmpty) return;

    setState(() => _loadingMore = true);

    try {
      final data = await widget.service.getFixtures(
        leagueIds: leagueIds,
        limit: _limit,
        offset: _offset,
        status: _status,
        runType: 'initial',
        force: false,
      );

      setState(() {
        _items.addAll(List<Map<String, dynamic>>.from(data));
        _offset += data.length;
        _hasMore = data.length == _limit;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _refresh() => _initialLoad(force: true);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Eroare la fixtures:\n$_error'),
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
                ? const ListView(
                    children: [
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
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return const SizedBox(height: 12);
                      }

                      final it = _items[i];

                      final home = (it['home'] ?? '').toString();
                      final away = (it['away'] ?? '').toString();
                      final league = (it['league'] ??
                              it['league_name'] ??
                              '')
                          .toString();
                      final time =
                          (it['time'] ?? it['kickoff'] ?? '').toString();

                      return ListTile(
                        leading: const Icon(Icons.sports_soccer),
                        title: Text('$home vs $away'),
                        subtitle: Text(
                          [league, time]
                              .where((e) => e.isNotEmpty)
                              .join(' • '),
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
