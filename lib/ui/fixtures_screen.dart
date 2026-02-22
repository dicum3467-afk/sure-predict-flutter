// lib/ui/fixtures_screen.dart
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/sure_predict_service.dart';

class FixturesScreen extends StatefulWidget {
  final League league;
  final SurePredictService service;

  const FixturesScreen({
    super.key,
    required this.league,
    required this.service,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  bool loading = false;
  String? error;

  List<Fixture> fixtures = const [];

  int limit = 50;
  int offset = 0;

  // range default 30 zile (cum arătai în screenshot)
  late DateTime from;
  late DateTime to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = DateTime(now.year, now.month, now.day);
    to = from.add(const Duration(days: 30));

    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await widget.service.getFixtures(
        leagueId: widget.league.id, // IMPORTANT: UUID
        from: from,
        to: to,
        limit: limit,
        offset: offset,
      );

      setState(() {
        fixtures = data;
      });
    } on ApiException catch (e) {
      setState(() => error = e.toString());
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _try60Days() async {
    setState(() {
      to = from.add(const Duration(days: 60));
      offset = 0;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.league.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loading ? null : _load,
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final rangeText = 'Range: ${_ymd(from)} → ${_ymd(to)}\nlimit=$limit offset=$offset';

    if (loading && fixtures.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (fixtures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No fixtures', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(rangeText, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              if (error != null) ...[
                Text('Error:\n$error', textAlign: TextAlign.center),
                const SizedBox(height: 14),
              ],
              ElevatedButton(
                onPressed: loading ? null : _load,
                child: const Text('Refresh'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: loading ? null : _try60Days,
                child: const Text('Try 60 days range'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: fixtures.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                rangeText,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            );
          }

          final f = fixtures[i - 1];

          return ListTile(
            title: Text('${f.home} vs ${f.away}'),
            subtitle: Text('${_formatKickoff(f.kickoffAt)} • ${f.status}'),
            trailing: _ProbsChip(f),
            onTap: () async {
              // opțional: la tap, ia predicția detaliată
              await _openPrediction(context, f);
            },
          );
        },
      ),
    );
  }

  Future<void> _openPrediction(BuildContext context, Fixture f) async {
    try {
      final pred = await widget.service.getPrediction(
        providerFixtureId: f.providerFixtureId,
      );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${f.home} vs ${f.away}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('provider_fixture_id: ${f.providerFixtureId}'),
              const SizedBox(height: 12),
              _kv('Home', pred.pHome),
              _kv('Draw', pred.pDraw),
              _kv('Away', pred.pAway),
              _kv('GG', pred.pGG),
              _kv('Over 2.5', pred.pOver25),
              _kv('Under 2.5', pred.pUnder25),
            ],
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _kv(String label, double? v) {
    final text = v == null ? '-' : (v * 100).toStringAsFixed(1) + '%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: $text'),
    );
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatKickoff(DateTime d) {
    final ymd = _ymd(d);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$ymd $hh:$mm';
  }
}

class _ProbsChip extends StatelessWidget {
  final Fixture f;
  const _ProbsChip(this.f);

  @override
  Widget build(BuildContext context) {
    // dacă ai probabilități pe fixture, arătăm un rezumat.
    final parts = <String>[];

    if (f.pHome != null && f.pAway != null && f.pDraw != null) {
      parts.add('1:${(f.pHome! * 100).toStringAsFixed(0)}');
      parts.add('X:${(f.pDraw! * 100).toStringAsFixed(0)}');
      parts.add('2:${(f.pAway! * 100).toStringAsFixed(0)}');
    } else if (f.pHome != null && f.pAway != null) {
      parts.add('H:${(f.pHome! * 100).toStringAsFixed(0)}');
      parts.add('A:${(f.pAway! * 100).toStringAsFixed(0)}');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
      ),
      child: Text(parts.join(' '), style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
