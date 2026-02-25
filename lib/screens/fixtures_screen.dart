import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore;

  const FixturesScreen({
    super.key,
    required this.service,
    required this.leaguesStore,
    required this.favoritesStore,
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
    _status = 'all';
    _initialLoad();
  }

  List<String> _allLeagueIds() {
    // ia toate ligile încărcate
    final ids = <String>[];
    for (final l in widget.leaguesStore.items) {
      final v = l['id'] ?? l['league_id'] ?? l['leagueId'];
      final id = (v ?? '').toString();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
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
      if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
        await widget.leaguesStore.load();
      }

      final leagueIds = _allLeagueIds();
      if (leagueIds.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final from = DateTime.now().toUtc();
      final to = from.add(const Duration(days: 7));

      final data = await widget.service.getFixtures(
        leagueIds: leagueIds,
        from: from.toIso8601String(),
        to: to.toIso8601String(),
        limit: _limit,
        offset: _offset,
        status: _status,
        force: force,
      );

      final page = List<Map<String, dynamic>>.from(data);
      setState(() {
        _items.addAll(page);
        _offset += page.length; // IMPORTANT: page.length e int (rezolvă eroarea int/double)
        _hasMore = page.length == _limit;
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
      final leagueIds = _allLeagueIds();
      if (leagueIds.isEmpty) return;

      final from = DateTime.now().toUtc();
      final to = from.add(const Duration(days: 7));

      final data = await widget.service.getFixtures(
        leagueIds: leagueIds,
        from: from.toIso8601String(),
        to: to.toIso8601String(),
        limit: _limit,
        offset: _offset,
        status: _status,
        force: false,
      );

      final page = List<Map<String, dynamic>>.from(data);
      setState(() {
        _items.addAll(page);
        _offset += page.length;
        _hasMore = page.length == _limit;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Eroare: $_error'));

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
            onRefresh: () => _initialLoad(force: true),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _items.length + 1,
              itemBuilder: (context, i) {
                if (i == _items.length) {
                  if (_hasMore) {
                    // trigger load more
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
                  title: Text('$home vs $away'),
                  subtitle: Text([league, time].where((e) => e.isNotEmpty).join(' • ')),
                  leading: const Icon(Icons.sports_soccer),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
