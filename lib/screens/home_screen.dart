import 'package:flutter/material.dart';

import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';

enum _ViewTab { matches, top10 }
enum _Mode { day, range }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiFootball api;

  final String _tz = 'Europe/Bucharest';

  _ViewTab _tab = _ViewTab.matches;
  _Mode _mode = _Mode.day;

  /// Day mode: -1=ieri, 0=azi, 1=mâine, 2=în 2 zile
  int _dayOffset = 0;

  /// Range mode: 3/5/7 (clamp automat max 7)
  int _rangeDays = 3;

  bool _loading = false;
  String? _error;

  /// Ultimele date bune (ca să nu rămână ecran gol la refresh)
  List<FixtureLite> _lastGood = <FixtureLite>[];
  List<FixtureLite> _fixtures = <FixtureLite>[];

  @override
  void initState() {
    super.initState();
    api = ApiFootball.fromDartDefine();
    _load();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load({bool force = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final base = _today();

    ApiResult<List<FixtureLite>> res;

    if (_mode == _Mode.day) {
      final date = base.add(Duration(days: _dayOffset));
      res = await api.fixturesByDate(date: date, timezone: _tz);
    } else {
      // clamp max 7 zile
      final days = _rangeDays.clamp(1, 7);
      final start = base;
      final end = base.add(Duration(days: days - 1));
      res = await api.fixturesBetween(start: start, end: end, timezone: _tz);
    }

    if (!mounted) return;

    if (res.isOk && res.data != null) {
      final list = res.data!;
      list.sort((a, b) {
        final ad = a.date;
        final bd = b.date;
        final c1 = ad.compareTo(bd);
        if (c1 != 0) return c1;
        final c2 = a.leagueName.toLowerCase().compareTo(b.leagueName.toLowerCase());
        if (c2 != 0) return c2;
        return a.date.compareTo(b.date);
      });

      setState(() {
        _fixtures = list;
        _lastGood = list;
        _loading = false;
      });
    } else {
      setState(() {
        _fixtures = _lastGood; // păstrează ce era bun înainte
        _error = res.error ?? 'Unknown error';
        _loading = false;
      });
    }
  }

  void _setDayOffset(int v) {
    setState(() {
      _mode = _Mode.day;
      _dayOffset = v;
    });
    _load();
  }

  void _setRangeDays(int days) {
    setState(() {
      _mode = _Mode.range;
      _rangeDays = days.clamp(1, 7);
    });
    _load();
  }

  String _titleForHeader(AppL10n t) {
    if (_mode == _Mode.day) {
      if (_dayOffset == -1) return t.t('matches_yesterday');
      if (_dayOffset == 0) return t.t('matches_today');
      if (_dayOffset == 1) return t.t('matches_tomorrow');
      return '${t.t('matches_in')} $_dayOffset';
    }
    return '${t.t('matches_range')} (${_rangeDays.clamp(1, 7)} ${t.t('days')})';
  }

  String _dowShort(DateTime d) {
    const ro = ['Lun', 'Mar', 'Mie', 'Joi', 'Vin', 'Sâm', 'Dum'];
    final i = (d.weekday - 1).clamp(0, 6);
    return ro[i];
  }

  String _md(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Group: Zi -> Ligă -> listă
  List<_DayGroup> _grouped(List<FixtureLite> list) {
    final map = <DateTime, Map<String, List<FixtureLite>>>{};

    for (final f in list) {
      final day = _dateOnly(f.date);
      map.putIfAbsent(day, () => <String, List<FixtureLite>>{});
      final leagueKey = '${f.leagueName} • ${f.leagueCountry}';
      map[day]!.putIfAbsent(leagueKey, () => <FixtureLite>[]);
      map[day]![leagueKey]!.add(f);
    }

    final days = map.keys.toList()..sort((a, b) => a.compareTo(b));

    return days.map((d) {
      final leagues = map[d]!;
      final keys = leagues.keys.toList()..sort((a, b) => a.compareTo(b));
      final leagueGroups = keys.map((k) {
        final items = leagues[k]!..sort((a, b) => a.date.compareTo(b.date));
        return _LeagueGroup(title: k, items: items);
      }).toList();
      return _DayGroup(day: d, leagues: leagueGroups);
    }).toList();
  }

  List<FixtureLite> _top10(List<FixtureLite> all) {
    // “Top 10” simplu: preferă meciuri care NU sunt terminate + ordonate cronologic
    final copy = List<FixtureLite>.from(all);
    copy.sort((a, b) {
      final aDone = a.statusShort == 'FT' || a.statusShort == 'AET' || a.statusShort == 'PEN';
      final bDone = b.statusShort == 'FT' || b.statusShort == 'AET' || b.statusShort == 'PEN';
      if (aDone != bDone) return aDone ? 1 : -1;
      return a.date.compareTo(b.date);
    });
    return copy.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    final title = _titleForHeader(t);
    final grouped = _grouped(_fixtures);
    final top10 = _top10(_fixtures);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TabsHeader(
                      current: _tab,
                      onChange: (v) => setState(() => _tab = v),
                      t: t,
                    ),
                    const SizedBox(height: 12),
                    _ModeRow(
                      mode: _mode,
                      onMode: (m) {
                        setState(() => _mode = m);
                        _load();
                      },
                      t: t,
                    ),
                    const SizedBox(height: 10),
                    if (_mode == _Mode.day)
                      _DayChips(
                        selected: _dayOffset,
                        onPick: _setDayOffset,
                        t: t,
                      )
                    else
                      _RangeChips(
                        selectedDays: _rangeDays,
                        onPick: _setRangeDays,
                        t: t,
                      ),
                    const SizedBox(height: 10),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          '${t.t('info')}: $_error',
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_loading && _fixtures.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_tab == _ViewTab.top10)
              _Top10Sliver(
                items: top10,
                hm: _hm,
              )
            else
              _MatchesSliver(
                groups: grouped,
                dowShort: _dowShort,
                md: _md,
                hm: _hm,
              ),
          ],
        ),
      ),
    );
  }
}

class _TabsHeader extends StatelessWidget {
  final _ViewTab current;
  final ValueChanged<_ViewTab> onChange;
  final AppL10n t;

  const _TabsHeader({
    required this.current,
    required this.onChange,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab({
      required bool active,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white.withOpacity(active ? 0.95 : 0.65)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(color: Colors.white.withOpacity(active ? 0.95 : 0.65)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(
          active: current == _ViewTab.matches,
          icon: Icons.sports_soccer,
          label: t.t('matches'),
          onTap: () => onChange(_ViewTab.matches),
        ),
        const SizedBox(width: 12),
        tab(
          active: current == _ViewTab.top10,
          icon: Icons.emoji_events,
          label: t.t('top10'),
          onTap: () => onChange(_ViewTab.top10),
        ),
      ],
    );
  }
}

class _ModeRow extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onMode;
  final AppL10n t;

  const _ModeRow({
    required this.mode,
    required this.onMode,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, _Mode m) {
      final active = mode == m;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onMode(m),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? Colors.white.withOpacity(0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(color: Colors.white.withOpacity(active ? 0.95 : 0.70)),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(t.t('day'), _Mode.day),
        const SizedBox(width: 10),
        pill(t.t('range'), _Mode.range),
      ],
    );
  }
}

class _DayChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPick;
  final AppL10n t;

  const _DayChips({
    required this.selected,
    required this.onPick,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int v) {
      final active = selected == v;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          selected: active,
          label: Text(label),
          onSelected: (_) => onPick(v),
          selectedColor: Colors.white.withOpacity(0.12),
          backgroundColor: Colors.white.withOpacity(0.05),
          side: BorderSide(color: Colors.white.withOpacity(0.10)),
          labelStyle: TextStyle(color: Colors.white.withOpacity(active ? 0.95 : 0.75)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(t.t('yesterday'), -1),
          chip(t.t('matches_today'), 0),
          chip(t.t('matches_tomorrow'), 1),
          chip('${t.t('in')} 2', 2),
        ],
      ),
    );
  }
}

class _RangeChips extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onPick;
  final AppL10n t;

  const _RangeChips({
    required this.selectedDays,
    required this.onPick,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int v) {
      final active = selectedDays == v;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          selected: active,
          label: Text(label),
          onSelected: (_) => onPick(v),
          selectedColor: Colors.white.withOpacity(0.12),
          backgroundColor: Colors.white.withOpacity(0.05),
          side: BorderSide(color: Colors.white.withOpacity(0.10)),
          labelStyle: TextStyle(color: Colors.white.withOpacity(active ? 0.95 : 0.75)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('3 ${t.t('days')}', 3),
          chip('5 ${t.t('days')}', 5),
          chip('7 ${t.t('days')}', 7),
        ],
      ),
    );
  }
}

class _MatchesSliver extends StatelessWidget {
  final List<_DayGroup> groups;
  final String Function(DateTime) dowShort;
  final String Function(DateTime) md;
  final String Function(DateTime) hm;

  const _MatchesSliver({
    required this.groups,
    required this.dowShort,
    required this.md,
    required this.hm,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('No matches', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, idx) {
          final g = groups[idx];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dowShort(g.day)}, ${md(g.day)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...g.leagues.map((lg) => _LeagueBlock(
                      title: lg.title,
                      items: lg.items,
                      hm: hm,
                    )),
              ],
            ),
          );
        },
        childCount: groups.length,
      ),
    );
  }
}

class _Top10Sliver extends StatelessWidget {
  final List<FixtureLite> items;
  final String Function(DateTime) hm;

  const _Top10Sliver({
    required this.items,
    required this.hm,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('Top 10 empty', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final f = items[i];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _MatchCard(f: f, hm: hm),
          );
        },
        childCount: items.length,
      ),
    );
  }
}

class _LeagueBlock extends StatelessWidget {
  final String title;
  final List<FixtureLite> items;
  final String Function(DateTime) hm;

  const _LeagueBlock({
    required this.title,
    required this.items,
    required this.hm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Text(
              title,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MatchCard(f: f, hm: hm),
              )),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final FixtureLite f;
  final String Function(DateTime) hm;

  const _MatchCard({required this.f, required this.hm});

  bool get _isFinished => f.statusShort == 'FT' || f.statusShort == 'AET' || f.statusShort == 'PEN';

  @override
  Widget build(BuildContext context) {
    final score = (f.goalsHome != null && f.goalsAway != null) ? '${f.goalsHome}-${f.goalsAway}' : '—';
    final time = hm(f.date);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPill(status: f.statusShort, time: time),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${f.homeName} vs ${f.awayName}',
                  style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  f.leagueName,
                  style: TextStyle(color: Colors.white.withOpacity(0.65)),
                ),
                const SizedBox(height: 10),
                Text(
                  _isFinished ? 'Final: $score' : 'Scor: $score',
                  style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            score,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final String time;

  const _StatusPill({required this.status, required this.time});

  @override
  Widget build(BuildContext context) {
    final s = status.isEmpty ? '—' : status;
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Text(
            s,
            style: TextStyle(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DayGroup {
  final DateTime day;
  final List<_LeagueGroup> leagues;

  _DayGroup({required this.day, required this.leagues});
}

class _LeagueGroup {
  final String title;
  final List<FixtureLite> items;

  _LeagueGroup({required this.title, required this.items});
}
