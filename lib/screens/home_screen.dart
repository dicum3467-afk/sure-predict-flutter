import 'package:flutter/material.dart';

import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';
import '../services/prediction_cache.dart';
import 'match_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _RangeMode { today, tomorrow, last3 }

class _HomeScreenState extends State<HomeScreen> {
  late final ApiFootball api;
  late final PredictionCache predCache;

  _RangeMode mode = _RangeMode.today;
  bool romaniaOnly = false;

  bool loading = true;
  String? errorText;
  List<FixtureLite> fixtures = const [];

  @override
  void initState() {
    super.initState();
    api = ApiFootball.fromDartDefine(); // trebuie să existe în clasa ta ApiFootball
    predCache = PredictionCache(api: api);
    _load();
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      const tz = 'Europe/Bucharest';
      final now = DateTime.now();
      List<FixtureLite> res;

      if (mode == _RangeMode.today) {
        res = await api.fixturesByDate(date: _ymd(now), timezone: tz);
      } else if (mode == _RangeMode.tomorrow) {
        res = await api.fixturesByDate(date: _ymd(now.add(const Duration(days: 1))), timezone: tz);
      } else {
        // ultimele 3 zile (inclusiv azi): [now-2 .. now]
        final start = _ymd(now.subtract(const Duration(days: 2)));
        final end = _ymd(now);
        res = await api.fixturesBetween(start: start, end: end, timezone: tz);
      }

      if (romaniaOnly) {
        // în funcție de modelul tău, filtrează după country/league
        // aici filtrăm după textul ligii (safe)
        res = res.where((f) => (f.league ?? '').toLowerCase().contains('romania')).toList();
      }

      setState(() {
        fixtures = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        errorText = e.toString();
        loading = false;
      });
    }
  }

  void _openFilters() {
    final t = AppL10n.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(t.t('filters'), style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        romaniaOnly = false;
                      });
                      Navigator.pop(context);
                      _load();
                    },
                    child: Text(t.t('reset')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: romaniaOnly,
                onChanged: (v) {
                  setState(() => romaniaOnly = v);
                  Navigator.pop(context);
                  _load();
                },
                title: Text(t.t('romania_only')),
                subtitle: Text(t.t('romania_only_hint')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    String title;
    switch (mode) {
      case _RangeMode.today:
        title = t.t('matches_today');
        break;
      case _RangeMode.tomorrow:
        title = t.t('matches_tomorrow');
        break;
      case _RangeMode.last3:
        title = t.t('last_3_days');
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: t.t('filters'),
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: t.t('reload'),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? Center(child: Text(t.t('loading')))
          : errorText != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: _infoCard('Info', errorText!),
                )
              : fixtures.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: _infoCard('Info', t.t('no_matches')),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        itemCount: fixtures.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) return _rangeChips(t);
                          final f = fixtures[i - 1];
                          return _fixtureCard(context, t, f);
                        },
                      ),
                    ),
    );
  }

  Widget _rangeChips(AppL10n t) {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(t.t('matches_today'), mode == _RangeMode.today, () {
              setState(() => mode = _RangeMode.today);
              _load();
            }),
            chip(t.t('matches_tomorrow'), mode == _RangeMode.tomorrow, () {
              setState(() => mode = _RangeMode.tomorrow);
              _load();
            }),
            chip(t.t('last_3_days'), mode == _RangeMode.last3, () {
              setState(() => mode = _RangeMode.last3);
              _load();
            }),
            if (romaniaOnly)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Chip(label: Text(t.t('romania_only'))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fixtureCard(BuildContext context, AppL10n t, FixtureLite f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchScreen(api: api, fixture: f),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black.withOpacity(0.08),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header row
              Row(
                children: [
                  _statusPill(f.statusShort ?? 'NS'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${f.home} vs ${f.away}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _scoreText(f),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if ((f.league ?? '').isNotEmpty)
                Text(
                  f.league!,
                  style: TextStyle(color: Colors.white.withOpacity(0.70)),
                ),

              const SizedBox(height: 10),

              FutureBuilder<PredictionLite?>(
                future: predCache.getForFixture(f),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Text(t.t('loading'));
                  }
                  final p = snap.data;
                  if (p == null) {
                    return Text(
                      t.t('predictions_unavailable'),
                      style: TextStyle(color: Colors.white.withOpacity(0.70)),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _pickPill(p.topPick),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Confidence ${p.confidence}% (${p.sourceTag})',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _probBar(p.pHome, p.pDraw, p.pAway),
                      const SizedBox(height: 6),
                      Text(
                        p.extras,
                        style: TextStyle(color: Colors.white.withOpacity(0.70)),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scoreText(FixtureLite f) {
    final sh = f.scoreHome;
    final sa = f.scoreAway;
    if (sh == null || sa == null) return '—';
    return '$sh-$sa';
  }

  Widget _statusPill(String txt) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _pickPill(String txt) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _probBar(double p1, double px, double p2) {
    double clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);

    p1 = clamp01(p1);
    px = clamp01(px);
    p2 = clamp01(p2);

    final sum = (p1 + px + p2);
    if (sum > 0) {
      p1 /= sum;
      px /= sum;
      p2 /= sum;
    }

    Widget seg(double v) => Expanded(
          flex: max(1, (v * 1000).round()),
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.18),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('1 ${(p1 * 100).toStringAsFixed(0)}%'),
            const Spacer(),
            Text('X ${(px * 100).toStringAsFixed(0)}%'),
            const Spacer(),
            Text('2 ${(p2 * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              seg(p1),
              const SizedBox(width: 6),
              seg(px),
              const SizedBox(width: 6),
              seg(p2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String title, String body) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withOpacity(0.08),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    );
  }
}
