import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/league.dart';
import '../services/sure_predict_service.dart';
import '../state/fixtures_store.dart';
import 'match_details_screen.dart';

class FixturesScreen extends StatefulWidget {
  const FixturesScreen({super.key, required this.league});

  final League league;

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  late final FixturesStore store;

  @override
  void initState() {
    super.initState();
    final api = ApiClient();
    final service = SurePredictService(api);
    store = FixturesStore(service);

    // IMPORTANT: range mai mare => ligi precum Ligue 1 vor avea meciuri
    store.setDefaultDateRange(days: 30);

    // primul load: cacheFirst = true (rapid)
    store.loadForLeague(widget.league.id, cacheFirst: true);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('EEE, dd MMM yyyy • HH:mm').format(dt.toLocal());
  }

  String _pct(double? v) {
    if (v == null) return '--';
    return '${(v * 100).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.league.name),
            actions: [
              IconButton(
                tooltip: 'Refresh (network)',
                onPressed: store.loading ? null : () => store.refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _body(),
        );
      },
    );
  }

  Widget _body() {
    // loading + gol => spinner
    if (store.loading && store.fixtures.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // eroare + gol => ecran eroare
    if (store.error != null && store.fixtures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error:\n${store.error}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => store.loadForLeague(widget.league.id, cacheFirst: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => store.refresh(),
                child: const Text('Force network refresh'),
              ),
            ],
          ),
        ),
      );
    }

    // gol fara eroare
    if (store.fixtures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No fixtures'),
              const SizedBox(height: 8),
              Text(
                'Range: ${store.dateFrom ?? "-"} → ${store.dateTo ?? "-"}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => store.refresh(),
                child: const Text('Refresh (network)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  // extinde range-ul rapid
                  store.setDefaultDateRange(days: 60);
                  store.refresh();
                },
                child: const Text('Try 60 days range'),
              ),
            ],
          ),
        ),
      );
    }

    // lista
    return RefreshIndicator(
      onRefresh: () => store.refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: store.fixtures.length + 1, // + footer
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == store.fixtures.length) {
            return _footer();
          }

          final f = store.fixtures[index];
          final when = _formatDate(f.kickoffAt);

          return ListTile(
            title: Text('${f.home} vs ${f.away}'),
            subtitle: Text('$when • ${f.status} • run: ${f.runType ?? "-"}'),
            trailing: _ProbsChip(
              pHome: f.pHome,
              pDraw: f.pDraw,
              pAway: f.pAway,
              fmt: _pct,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MatchDetailsScreen(fixture: f),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _footer() {
    // arată eroare mică jos dacă există
    final errorText = store.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Text(
            'Range: ${store.dateFrom ?? "-"} → ${store.dateTo ?? "-"}'
            '   •   limit=${store.limit} offset=${store.offset}',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: store.loading
                      ? null
                      : () {
                          store.setDefaultDateRange(days: 30);
                          store.refresh();
                        },
                  icon: const Icon(Icons.date_range),
                  label: const Text('30 days'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (store.loading || !store.hasMore)
                      ? null
                      : () => store.loadMore(cacheFirst: true),
                  icon: store.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(store.hasMore ? 'Load more' : 'No more'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh (network)',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ProbsChip extends StatelessWidget {
  const _ProbsChip({
    required this.pHome,
    required this.pDraw,
    required this.pAway,
    required this.fmt,
  });

  final double? pHome;
  final double? pDraw;
  final double? pAway;
  final String Function(double? v) fmt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('H ${fmt(pHome)}', style: const TextStyle(fontSize: 12)),
        Text('D ${fmt(pDraw)}', style: const TextStyle(fontSize: 12)),
        Text('A ${fmt(pAway)}', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
