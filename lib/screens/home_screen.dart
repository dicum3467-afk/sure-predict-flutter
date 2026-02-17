import 'dart:math';
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

  // PRO: Top 10
  bool topLoading = false;
  String? topError;
  List<_TopItem> top10 = const [];

  @override
  void initState() {
    super.initState();
    api = ApiFootball.fromDartDefine();
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

    predCache.clear();
    setState(() {
      top10 = const [];
      topError = null;
      topLoading = false;
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
        final start = _ymd(now.subtract(const Duration(days: 2)));
        final end = _ymd(now);
        res = await api.fixturesBetween(start: start, end: end, timezone: tz);
      }

      if (romaniaOnly) {
        res = res.where((f) => (f.league ?? '').toLowerCase().contains('romania')).toList();
      }

      setState(() {
        fixtures = res;
        loading = false;
      });

      // după ce avem meciurile, calculăm Top 10
      _buildTop10();
    } catch (e) {
      setState(() {
        errorText = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _buildTop10() async {
    if (!mounted) return;
    if (fixtures.isEmpty) {
      setState(() {
        top10 = const [];
        topError = null;
        topLoading = false;
      });
      return;
    }

    setState(() {
      topLoading = true;
      topError = null;
      top10 = const [];
    });

    try {
      final items = <_TopItem>[];

      // Preluăm predicțiile (throttle e în PredictionCache)
      for (final f in fixtures) {
        final p = await predCache.getForFixture(f);
        if (!mounted) return;
        if (p == null) continue;
        items.add(_TopItem(fixture: f, pred: p));
      }

      // sort desc după confidence, apoi după DATA vs BASE, apoi după topVal (implicit via confidence)
      items.sort((a, b) {
        final c = b.pred.confidence.compareTo(a.pred.confidence);
        if (c != 0) return c;
        // preferă DATA peste BASE la egalitate
        final ad = a.pred.sourceTag.toUpperCase() == 'DATA';
        final bd = b.pred.sourceTag.toUpperCase() == 'DATA';
        if (ad != bd) return bd ? 1 : -1;
        return 0;
      });

      setState(() {
        top10 = items.take(10).toList();
        topLoading = false;
      });
    } catch (e) {
      setState(() {
        topError = e.toString();
        topLoading = false;
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
              const SizedBox(height: 10),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.sports_soccer), text: 'Meciuri'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Top 10'),
            ],
          ),
          actions: [
            IconButton(tooltip: t.t('filters'), onPressed: _openFilters, icon: const Icon(Icons.tune)),
            IconButton(tooltip: t.t('reload'), onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: TabBarView(
          children: [
            _tabMatches(t),
            _tabTop10(t),
          ],
        ),
      ),
    );
  }

  Widget _tabMatches(AppL10n t) {
    if (loading) return Center(child: Text(t.t('loading')));
    if (errorText != null) {
      return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Info', errorText!));
    }
    if (fixtures.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Info', t.t('no_matches')));
    }

    return RefreshIndicator(
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
    );
  }

  Widget _tabTop10(AppL10n t) {
    // dacă încă se încarcă meciurile de bază
    if (loading) return Center(child: Text(t.t('loading')));
    if (errorText != null) {
      return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Info', errorText!));
    }
    if (fixtures.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Info', t.t('no_matches')));
    }

    // top computation
    if (topLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (topError != null) {
      return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Top 10', topError!));
    }
    if (top10.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _infoCard('Top 10', 'Nu am reușit să calculez Top 10 (predicții indisponibile pentru meciurile curente).'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: top10.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    'Top 10 • sortat după Confidence',
                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.85)),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Recalculează Top 10',
                    onPressed: _buildTop10,
                    icon: const Icon(Icons.replay),
                  )
                ],
              ),
            );
          }
          final item = top10[i - 1];
          return _topCard(context, t, item, rank: i);
        },
      ),
    );
  }

  Widget _rangeChips(AppL10n t) {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
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
            if (romaniaOnly) Padding(padding: const EdgeInsets.only(left: 6), child: Chip(label: Text(t.t('romania_only')))),
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
          Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(api: api, fixture: f)));
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
                  Text(_scoreText(f), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              if ((f.league ?? '').isNotEmpty)
                Text(f.league!, style: TextStyle(color: Colors.white.withOpacity(0.70))),
              const SizedBox(height: 10),

              FutureBuilder<PredictionLite?>(
                future: predCache.getForFixture(f),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return Text(t.t('loading'));
                  final p = snap.data;
                  if (p == null) {
                    return Text(t.t('predictions_unavailable'), style: TextStyle(color: Colors.white.withOpacity(0.70)));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _pickPill(p.topPick),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Text('Confidence ${p.confidence}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(width: 8),
                                _sourceBadge(p.sourceTag),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _probBar(p.pHome, p.pDraw, p.pAway),
                      const SizedBox(height: 6),
                      Text(p.extras, style: TextStyle(color: Colors.white.withOpacity(0.70))),
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

  Widget _topCard(BuildContext context, AppL10n t, _TopItem item, {required int rank}) {
    final f = item.fixture;
    final p = item.pred;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(api: api, fixture: f)));
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _rankPill(rank),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${f.home} vs ${f.away}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _pickPill(p.topPick),
                ],
              ),
              const SizedBox(height: 8),
              if ((f.league ?? '').isNotEmpty)
                Text(f.league!, style: TextStyle(color: Colors.white.withOpacity(0.70))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Confidence ${p.confidence}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  _sourceBadge(p.sourceTag),
                  const Spacer(),
                  Text(_scoreText(f), style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              _probBar(p.pHome, p.pDraw, p.pAway),
              const SizedBox(height: 6),
              Text(p.extras, style: TextStyle(color: Colors.white.withOpacity(0.70))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankPill(int rank) {
    final bg = rank == 1
        ? Colors.amber.withOpacity(0.22)
        : (rank <= 3 ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.10));
    final fg = rank == 1 ? Colors.amberAccent : Colors.white.withOpacity(0.85);

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
    );
  }

  Widget _sourceBadge(String tag) {
    final isData = tag.toUpperCase() == 'DATA';
    final bg = isData ? Colors.green.withOpacity(0.22) : Colors.white.withOpacity(0.10);
    final fg = isData ? Colors.greenAccent : Colors.white.withOpacity(0.80);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(tag.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg)),
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

class _TopItem {
  final FixtureLite fixture;
  final PredictionLite pred;
  const _TopItem({required this.fixture, required this.pred});
}
