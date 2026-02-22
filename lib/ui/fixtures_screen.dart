import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/fixture_item.dart';
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    final api = ApiClient();
    final service = SurePredictService(api);
    store = FixturesStore(service);

    // ✅ default: azi -> +7 zile (important)
    store.setDefaultDates(days: 7);

    // ✅ load inițial
    store.loadForLeague(widget.league.id);

    // ✅ auto-refresh la 30 sec
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (store.loading) return;
      store.loadForLeague(widget.league.id);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy • HH:mm').format(dt.toLocal());
  }

  Future<void> _pickRangeDialog() async {
    final choice = await showModalBottomSheet<_RangeChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Azi'),
              onTap: () => Navigator.pop(context, _RangeChoice.today),
            ),
            ListTile(
              title: const Text('Mâine'),
              onTap: () => Navigator.pop(context, _RangeChoice.tomorrow),
            ),
            ListTile(
              title: const Text('Următoarele 7 zile'),
              onTap: () => Navigator.pop(context, _RangeChoice.week),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    // calculează dateFrom/dateTo
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    DateTime from;
    DateTime to;

    switch (choice) {
      case _RangeChoice.today:
        from = start;
        to = start.add(const Duration(days: 1));
        break;
      case _RangeChoice.tomorrow:
        from = start.add(const Duration(days: 1));
        to = start.add(const Duration(days: 2));
        break;
      case _RangeChoice.week:
        from = start;
        to = start.add(const Duration(days: 7));
        break;
    }

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    store.setFilters(
      newDateFrom: fmt(from),
      newDateTo: fmt(to),
    );

    await store.loadForLeague(widget.league.id);
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
                tooltip: 'Filtru zile',
                onPressed: store.loading ? null : _pickRangeDialog,
                icon: const Icon(Icons.calendar_month),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: store.loading ? null : () => store.loadForLeague(widget.league.id),
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
    if (store.loading && store.fixtures.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.error != null && store.fixtures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error:\n${store.error}'),
        ),
      );
    }

    if (store.fixtures.isEmpty) {
      return const Center(child: Text('No fixtures'));
    }

    return RefreshIndicator(
      onRefresh: () => store.loadForLeague(widget.league.id),
      child: ListView.separated(
        itemCount: store.fixtures.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final f = store.fixtures[i];

          final best = _bestPickLabel(f);
          final bestValue = _bestPickValue(f);

          return ListTile(
            title: Text('${f.home} vs ${f.away}'),
            subtitle: Text('${_formatDate(f.kickoffAt)} • ${f.status} • run: ${f.runType ?? '-'}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ProbChip(pHome: f.pHome, pDraw: f.pDraw, pAway: f.pAway),
                const SizedBox(height: 6),
                if (best != null)
                  _BestPickChip(
                    label: best,
                    value: bestValue,
                  ),
              ],
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

  String? _bestPickLabel(FixtureItem f) {
    final h = f.pHome;
    final d = f.pDraw;
    final a = f.pAway;

    if (h == null && d == null && a == null) return null;

    final hv = h ?? -1;
    final dv = d ?? -1;
    final av = a ?? -1;

    if (hv >= dv && hv >= av) return 'BEST: H';
    if (dv >= hv && dv >= av) return 'BEST: D';
    return 'BEST: A';
  }

  double? _bestPickValue(FixtureItem f) {
    final h = f.pHome ?? -1;
    final d = f.pDraw ?? -1;
    final a = f.pAway ?? -1;
    final m = [h, d, a].reduce((x, y) => x > y ? x : y);
    return m >= 0 ? m : null;
  }
}

enum _RangeChoice { today, tomorrow, week }

class _ProbChip extends StatelessWidget {
  const _ProbChip({required this.pHome, required this.pDraw, required this.pAway});

  final double? pHome;
  final double? pDraw;
  final double? pAway;

  String _fmt(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('H ${_fmt(pHome)}'),
        Text('D ${_fmt(pDraw)}'),
        Text('A ${_fmt(pAway)}'),
      ],
    );
  }
}

class _BestPickChip extends StatelessWidget {
  const _BestPickChip({required this.label, required this.value});

  final String label;
  final double? value;

  String _pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(width: 1),
      ),
      child: Text('$label • ${_pct(value)}'),
    );
  }
}
