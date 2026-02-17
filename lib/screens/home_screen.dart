import 'package:flutter/material.dart';

import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';
import '../widgets/neo_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum ViewMode { day, range }

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final ApiFootball api;
  late final TabController _tabs;

  static const String _tz = 'Europe/Bucharest';

  ViewMode _mode = ViewMode.day;
  int _dayOffset = 0;

  DateTimeRange? _range;
  int _rangeDays = 3; // auto clamp 1..7

  bool _loading = false;
  String? _error;
  String? _debug;

  List<FixtureLite> _items = [];
  List<FixtureLite> _lastGoodItems = [];

  @override
  void initState() {
    super.initState();
    api = ApiFootball(key: const String.fromEnvironment('APIFOOTBALL_KEY'));
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  int _clampDays(int v) => v.clamp(1, 7);

  Future<void> _pickRange() async {
    final now = _stripTime(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now.add(const Duration(days: 90)),
      initialDateRange: _range ??
          DateTimeRange(
            start: now.subtract(Duration(days: _rangeDays - 1)),
            end: now,
          ),
    );
    if (picked == null) return;

    final days = picked.end.difference(picked.start).inDays + 1;
    final safeDays = _clampDays(days);

    DateTimeRange safeRange = picked;
    if (days > 7) {
      safeRange = DateTimeRange(start: picked.end.subtract(const Duration(days: 6)), end: picked.end);
    }

    setState(() {
      _mode = ViewMode.range;
      _rangeDays = safeDays;
      _range = safeRange;
    });

    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _debug = null;
    });

    try {
      final datesToLoad = <DateTime>[];

      if (_mode == ViewMode.day) {
        datesToLoad.add(_stripTime(DateTime.now().add(Duration(days: _dayOffset))));
      } else {
        final now = _stripTime(DateTime.now());
        final r = _range ??
            DateTimeRange(
              start: now.subtract(Duration(days: _rangeDays - 1)),
              end: now,
            );

        DateTime start = _stripTime(r.start);
        DateTime end = _stripTime(r.end);
        final span = end.difference(start).inDays + 1;
        if (span > 7) start = end.subtract(const Duration(days: 6));

        for (int i = 0; i <= end.difference(start).inDays; i++) {
          datesToLoad.add(start.add(Duration(days: i)));
        }
      }

      _debug = 'tz=$_tz dates=${datesToLoad.map(_ymd).join(", ")}';

      final combined = <FixtureLite>[];

      for (final d in datesToLoad) {
        final ymd = _ymd(d);
        final res = await api.fixturesByDate(date: ymd, timezone: _tz);

        final ok = (res as dynamic).isOk == true;
        final data = (res as dynamic).data;
        if (!ok || data == null) {
          final err = (res as dynamic).error?.toString() ?? 'API error';
          throw Exception('fixturesByDate($ymd) failed: $err');
        }

        if (data is List<FixtureLite>) {
          combined.addAll(data);
        } else if (data is List) {
          for (final x in data) {
            if (x is FixtureLite) combined.add(x);
            else if (x is Map<String, dynamic>) combined.add(FixtureLite.fromApiFootball(x));
            else if (x is Map) combined.add(FixtureLite.fromApiFootball(x.cast<String, dynamic>()));
          }
        }
      }

      // sort: day -> league -> time
      combined.sort((a, b) {
        final da = _stripTime(a.dateUtc.toLocal());
        final db = _stripTime(b.dateUtc.toLocal());
        final c0 = da.compareTo(db);
        if (c0 != 0) return c0;

        final c1 = a.leagueCountry.compareTo(b.leagueCountry);
        if (c1 != 0) return c1;

        final c2 = a.leagueName.compareTo(b.leagueName);
        if (c2 != 0) return c2;

        final c3 = a.dateUtc.compareTo(b.dateUtc);
        if (c3 != 0) return c3;

        return a.home.compareTo(b.home);
      });

      setState(() {
        _loading = false;
        _items = combined;
        _lastGoodItems = combined;
        _debug = '${_debug ?? ""} | count=${combined.length}';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
        _items = _lastGoodItems; // keep last good
        _debug = '${_debug ?? ""} | ERROR=$_error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final title = _mode == ViewMode.day ? _titleForDay(t) : _titleForRange(t);

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        tooltip: t.t('refresh'),
                      ),
                      IconButton(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.tune),
                        tooltip: t.t('filters'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tabs inside glass
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    radius: 18,
                    child: TabBar(
                      controller: _tabs,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(icon: const Icon(Icons.sports_soccer), text: t.t('matches')),
                        Tab(icon: const Icon(Icons.emoji_events), text: t.t('top10')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                children: [
                  NeoSegment(
                    left: t.t('day'),
                    right: t.t('range'),
                    isLeftSelected: _mode == ViewMode.day,
                    onLeft: () async {
                      setState(() => _mode = ViewMode.day);
                      await _load();
                    },
                    onRight: () async {
                      setState(() => _mode = ViewMode.range);
                      await _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  _mode == ViewMode.day ? _dayChips(t) : _rangeChips(t),
                  if (_error != null || _debug != null) ...[
                    const SizedBox(height: 10),
                    GlassCard(
                      radius: 16,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error != null ? 'Info: $_error' : 'Info: $_debug',
                        style: TextStyle(
                          color: _error != null ? Colors.redAccent : Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _matchesTab(t),
                  _top10Tab(t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayChips(AppL10n t) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(label: t.t('yesterday'), selected: _dayOffset == -1, onTap: () => _setDay(-1)),
          _chip(label: t.t('today'), selected: _dayOffset == 0, onTap: () => _setDay(0)),
          _chip(label: t.t('tomorrow'), selected: _dayOffset == 1, onTap: () => _setDay(1)),
          _chip(label: '${t.t('in')} 2', selected: _dayOffset == 2, onTap: () => _setDay(2)),
          _chip(label: '${t.t('in')} 3', selected: _dayOffset == 3, onTap: () => _setDay(3)),
        ],
      ),
    );
  }

  Widget _rangeChips(AppL10n t) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            label: '${t.t('last')} 3 ${t.t('days')}',
            selected: _rangeDays == 3,
            onTap: () async {
              setState(() {
                _rangeDays = 3;
                _range = null;
              });
              await _load();
            },
          ),
          _chip(
            label: '${t.t('last')} 5 ${t.t('days')}',
            selected: _rangeDays == 5,
            onTap: () async {
              setState(() {
                _rangeDays = 5;
                _range = null;
              });
              await _load();
            },
          ),
          _chip(
            label: '${t.t('last')} 7 ${t.t('days')}',
            selected: _rangeDays == 7,
            onTap: () async {
              setState(() {
                _rangeDays = 7;
                _range = null;
              });
              await _load();
            },
          ),
          const SizedBox(width: 10),
          ActionChip(
            label: Text('${t.t('pick_range')} (≤ 7)'),
            onPressed: _pickRange,
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.10),
            ),
            color: selected ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.06),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setDay(int offset) async {
    setState(() {
      _mode = ViewMode.day;
      _dayOffset = offset;
    });
    await _load();
  }

  Widget _matchesTab(AppL10n t) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: GlassCard(
          margin: const EdgeInsets.all(14),
          child: Text(t.t('no_matches')),
        ),
      );
    }

    final groups = _groupForUI(_items);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
      itemCount: groups.length,
      itemBuilder: (context, i) => _NeoGroupTile(groups[i]),
    );
  }

  Widget _top10Tab(AppL10n t) {
    final top = _computeTop10(_items);

    if (_loading && top.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (top.isEmpty) {
      return Center(
        child: GlassCard(
          margin: const EdgeInsets.all(14),
          child: Text(t.t('top10_empty')),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        // podium for top 3
        if (top.length >= 3) _podium(top.take(3).toList()),
        const SizedBox(height: 14),
        for (int i = 0; i < top.length; i++) ...[
          _NeoTopCard(rank: i + 1, f: top[i]),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _podium(List<FixtureLite> top3) {
    Widget medal(int place, FixtureLite f, Color c) {
      final local = f.dateUtc.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return Expanded(
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeoBadge(text: '#$place', color: c, icon: Icons.auto_awesome),
              const SizedBox(height: 10),
              Text('${f.home} vs ${f.away}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${f.leagueLabel()} • $hh:$mm', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
              NeoProgressBar(a: 0.45, d: 0.28, b: 0.27),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        medal(2, top3[1], const Color(0xFF6EE7FF)),
        const SizedBox(width: 10),
        medal(1, top3[0], const Color(0xFFB7A6FF)),
        const SizedBox(width: 10),
        medal(3, top3[2], const Color(0xFF22C55E)),
      ],
    );
  }

  String _titleForDay(AppL10n t) {
    if (_dayOffset == -1) return t.t('matches_yesterday');
    if (_dayOffset == 0) return t.t('matches_today');
    if (_dayOffset == 1) return t.t('matches_tomorrow');
    return '${t.t('matches_in')} $_dayOffset';
  }

  String _titleForRange(AppL10n t) {
    final r = _range;
    if (r == null) return '${t.t('matches_range')} ($_rangeDays ${t.t('days')})';
    return '${t.t('matches_range')} ${_ymd(r.start)} → ${_ymd(r.end)}';
  }

  // ---------- Grouping ----------
  List<_UiGroup> _groupForUI(List<FixtureLite> items) {
    final out = <_UiGroup>[];
    DateTime? currentDay;
    String? currentLeagueKey;

    for (final f in items) {
      final day = _stripTime(f.dateUtc.toLocal());
      final leagueKey = '${f.leagueId}:${f.leagueName}:${f.leagueCountry}';

      if (currentDay == null || day != currentDay) {
        currentDay = day;
        currentLeagueKey = null;
        out.add(_UiGroup.dayHeader(day));
      }

      if (currentLeagueKey == null || leagueKey != currentLeagueKey) {
        currentLeagueKey = leagueKey;
        out.add(_UiGroup.leagueHeader(f.leagueName, f.leagueCountry));
      }

      out.add(_UiGroup.fixture(f));
    }

    return out;
  }

  // ---------- Top10 heuristic (înlocuiești ulterior cu predicții reale) ----------
  List<FixtureLite> _computeTop10(List<FixtureLite> items) {
    double score(FixtureLite f) {
      if (f.isFinished) return 0;
      double s = 50;
      if (f.isNotStarted) s += 12;
      if (f.home.isNotEmpty && f.away.isNotEmpty) s += 6;
      final now = DateTime.now().toUtc();
      final diffH = f.dateUtc.difference(now).inMinutes / 60.0;
      if (diffH.abs() < 6) s += 6;
      return s;
    }

    final list = List<FixtureLite>.from(items);
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list.take(10).toList();
  }
}

class _UiGroup {
  final _UiGroupType type;
  final DateTime? day;
  final String? league;
  final String? country;
  final FixtureLite? fixture;

  _UiGroup._(this.type, {this.day, this.league, this.country, this.fixture});

  factory _UiGroup.dayHeader(DateTime day) => _UiGroup._(_UiGroupType.day, day: day);
  factory _UiGroup.leagueHeader(String league, String country) =>
      _UiGroup._(_UiGroupType.league, league: league, country: country);
  factory _UiGroup.fixture(FixtureLite f) => _UiGroup._(_UiGroupType.fixture, fixture: f);
}

enum _UiGroupType { day, league, fixture }

class _NeoGroupTile extends StatelessWidget {
  final _UiGroup g;
  const _NeoGroupTile(this.g);

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    switch (g.type) {
      case _UiGroupType.day:
        final d = g.day!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
          child: Row(
            children: [
              NeoBadge(text: _dayLabel(t, d), icon: Icons.calendar_month),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.10))),
            ],
          ),
        );

      case _UiGroupType.league:
        final text = (g.country == null || g.country!.isEmpty) ? g.league! : '${g.league!} • ${g.country!}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: NeoBadge(text: text, icon: Icons.verified),
          ),
        );

      case _UiGroupType.fixture:
        return _NeoMatchCard(f: g.fixture!);
    }
  }

  String _dayLabel(AppL10n t, DateTime d) {
    final now = DateTime.now();
    final dd = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = dd.difference(today).inDays;

    if (diff == -1) return t.t('yesterday');
    if (diff == 0) return t.t('today');
    if (diff == 1) return t.t('tomorrow');

    final weekday = [
      t.t('mon'),
      t.t('tue'),
      t.t('wed'),
      t.t('thu'),
      t.t('fri'),
      t.t('sat'),
      t.t('sun'),
    ][dd.weekday - 1];

    return '$weekday • ${dd.day.toString().padLeft(2, '0')}.${dd.month.toString().padLeft(2, '0')}';
  }
}

class _NeoMatchCard extends StatelessWidget {
  final FixtureLite f;
  const _NeoMatchCard({required this.f});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final local = f.dateUtc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    final status = f.statusShort.isEmpty ? '—' : f.statusShort;
    final isLive = status == '1H' || status == '2H' || status == 'HT';

    return GlassCard(
      radius: 22,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeoBadge(
                text: status,
                color: isLive ? const Color(0xFF22C55E) : cs.secondary,
                icon: isLive ? Icons.sensors : Icons.timelapse,
              ),
              const SizedBox(width: 10),
              Text('$hh:$mm', style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(f.scoreText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text('${f.home} vs ${f.away}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(f.leagueName, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),

          // “AI confidence” look (vizual), îl conectezi la predicții când e gata
          Row(
            children: const [
              NeoBadge(text: 'AI', icon: Icons.auto_awesome),
              SizedBox(width: 10),
              NeoBadge(text: 'Confidence 55%', icon: Icons.bolt),
              SizedBox(width: 10),
              NeoBadge(text: 'DATA', icon: Icons.insights),
            ],
          ),
          const SizedBox(height: 12),
          const NeoProgressBar(a: 0.50, d: 0.28, b: 0.22),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 50%', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              Text('X 28%', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              Text('2 22%', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeoTopCard extends StatelessWidget {
  final int rank;
  final FixtureLite f;
  const _NeoTopCard({required this.rank, required this.f});

  @override
  Widget build(BuildContext context) {
    final local = f.dateUtc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    Color rankColor() {
      if (rank == 1) return const Color(0xFFB7A6FF);
      if (rank == 2) return const Color(0xFF6EE7FF);
      if (rank == 3) return const Color(0xFF22C55E);
      return Colors.white70;
    }

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          NeoBadge(text: '#$rank', color: rankColor(), icon: Icons.emoji_events),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f.home} vs ${f.away}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${f.leagueLabel()} • $hh:$mm', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(f.scoreText, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
