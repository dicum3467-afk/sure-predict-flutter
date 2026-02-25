import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../state/leagues_store.dart';
import '../state/favorites_store.dart';
import '../state/settings_store.dart';

class TopPicksTab extends StatefulWidget {
  final SurePredictService service;
  final LeaguesStore leaguesStore;
  final FavoritesStore favoritesStore; // (nefolosit aici ca să nu rupem build-ul)
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
  bool _loading = false;
  String? _error;

  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();

    // dacă ligile nu-s încă încărcate, le încărcăm
    if (widget.leaguesStore.items.isEmpty && !widget.leaguesStore.isLoading) {
      widget.leaguesStore.load();
    }

    // load inițial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(force: false);
    });
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _fmtPct(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return '-';
    return '${(d * 100).toStringAsFixed(0)}%';
  }

  String _fmtOdds(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return '-';
    return d.toStringAsFixed(2);
  }

  // scor “value” simplu: p * odds (nu e EV real, dar e util pt sortare)
  double _score(Map<String, dynamic> item) {
    final p = _toDouble(item['p']) ?? _toDouble(item['prob']) ?? 0.0;
    final o = _toDouble(item['odds']) ?? 0.0;
    return p * o;
  }

  Future<void> _load({required bool force}) async {
    if (_loading) return;

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final leagues = widget.leaguesStore.selectedIds;
      if (leagues.isEmpty) {
        setState(() {
          _items.clear();
          _loading = false;
          _error = 'Nu ai selectat nicio ligă.';
        });
        return;
      }

      final threshold = widget.settings.threshold; // double
      final topPerLeague = widget.settings.topPerLeague; // bool
      final status = widget.settings.status; // String: all/scheduled/live/finished

      final data = await widget.service.getTopPicks(
        leagueIds: leagues,
        threshold: threshold,
        topPerLeague: topPerLeague,
        status: status,
        force: force,
        limit: 200,
      );

      // sort desc după “score”
      data.sort((a, b) => _score(b).compareTo(_score(a)));

      setState(() {
        _items
          ..clear()
          ..addAll(data);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

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

              final home = (item['home'] ?? '').toString();
              final away = (item['away'] ?? '').toString();

              final pHome = _fmtPct(pred['p_home'] ?? item['p_home']);
              final pDraw = _fmtPct(pred['p_draw'] ?? item['p_draw']);
              final pAway = _fmtPct(pred['p_away'] ?? item['p_away']);
              final pOver = _fmtPct(pred['p_over25'] ?? item['p_over25']);
              final pUnder = _fmtPct(pred['p_under25'] ?? item['p_under25']);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$home vs $away',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  _kv('1 (Home)', pHome),
                  _kv('X (Draw)', pDraw),
                  _kv('2 (Away)', pAway),
                  const Divider(height: 24),
                  _kv('Over 2.5', pOver),
                  _kv('Under 2.5', pUnder),

                  const SizedBox(height: 16),
                  Text(
                    'Notă: Probabilitățile sunt orientative.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ascultă schimbări din leaguesStore + settings
    return AnimatedBuilder(
      animation: Listenable.merge([widget.leaguesStore, widget.settings]),
      builder: (context, _) {
        final leaguesSelected = widget.leaguesStore.selectedIds.length;

        return Scaffold(
          appBar: AppBar(
            title: Text('Top Picks PRO ($leaguesSelected)'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : () => _load(force: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _load(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _headerCard(context),
                ),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _errorCard(_error!),
                  )
                else if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('Nu există top picks pentru filtrul ales.')),
                  )
                else
                  ..._items.map((item) => _pickTile(context, item)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerCard(BuildContext context) {
    final t = widget.settings.threshold;
    final st = widget.settings.status;
    final per = widget.settings.topPerLeague;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtre',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _kv('Confidence threshold', '${(t * 100).toStringAsFixed(0)}%'),
            _kv('Status', st),
            _kv('Top per league', per ? 'ON' : 'OFF'),
            const SizedBox(height: 8),
            Text(
              'Tip: schimbi filtrele din Settings.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }

  Widget _pickTile(BuildContext context, Map<String, dynamic> item) {
    final home = (item['home'] ?? '').toString();
    final away = (item['away'] ?? '').toString();

    final league = (item['league_name'] ?? item['league'] ?? '').toString();
    final country = (item['country'] ?? '').toString();

    final pick = (item['pick'] ?? item['market'] ?? '').toString();
    final p = _fmtPct(item['p'] ?? item['prob']);
    final odds = _fmtOdds(item['odds']);

    final score = _score(item);
    final scoreText = score == 0 ? '-' : score.toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: () => _openPrediction(context, item),
        title: Text('$home vs $away'),
        subtitle: Text(
          [
            if (country.isNotEmpty) country,
            if (league.isNotEmpty) league,
            if (pick.isNotEmpty) 'Pick: $pick',
          ].join(' • '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(p, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('odds $odds'),
            Text('score $scoreText', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
