// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum ViewMode { day, range }

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final ApiFootball api;
  late final TabController _tabs;

  // ---- Settings ----
  static const String _tz = 'Europe/Bucharest';
  ViewMode _mode = ViewMode.day;

  // Day mode offsets (relative to today)
  int _dayOffset = 0; // -1 yesterday, 0 today, 1 tomorrow, ...

  // Range mode
  DateTimeRange? _range;
  int _rangeDays = 3; // auto clamp 1..7

  // ---- Data state ----
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

  // ---------- Date helpers ----------
  DateTime _todayLocal() => DateTime.now();

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  int _clampDays(int v) => v.clamp(1, 7);

  Future<void> _pickRange() async {
    final now = _todayLocal();
    final start = _stripTime(now.subtract(Duration(days: _rangeDays - 1)));
    final end = _stripTime(now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now.add(const Duration(days: 90)),
      initialDateRange: _range ?? DateTimeRange(start: start, end: end),
    );

    if (picked == null) return;

    // clamp to max 7 days
    final days = picked.end.difference(picked.start).inDays + 1;
    final safeDays = _clampDays(days);

    DateTimeRange safeRange = picked;
    if (days > 7) {
      safeRange = DateTimeRange(start: picked.end.subtract(const Duration(days: 6)), end: picked.end);
    }

    setState(() {
      _rangeDays = safeDays;
      _range = safeRange;
      _mode = ViewMode.range;
    });

    await _load();
  }

  // ---------- Load logic ----------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _debug = null;
    });

    try {
      final List<DateTime> datesToLoad = [];

      if (_mode == ViewMode.day) {
        final d = _stripTime(_todayLocal().add(Duration(days: _dayOffset)));
        datesToLoad.add(d);
      } else {
        final now = _stripTime(_todayLocal());
        final range = _range ??
            DateTimeRange(
              start: now.subtract(Duration(days: _rangeDays - 1)),
              end: now,
            );

        // clamp to 7 days
        DateTime start = _stripTime(range.start);
        DateTime end = _stripTime(range.end);
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

        // We accept BOTH: ApiResult<List<FixtureLite>> OR ApiResult<List<Map>>
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
            if (x is FixtureLite) {
              combined.add(x);
            } else if (x is Map<String, dynamic>) {
              combined.add(FixtureLite.fromApiFootball(x));
            } else if (x is Map) {
              combined.add(FixtureLite.fromApiFootball(x.cast<String, dynamic>()));
            }
          }
        }
      }

      // Sort: day -> league -> time
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
      // IMPORTANT: keep last good list, don't blank screen
      setState(() {
        _loading = false;
        _error = e.toString();
        _items = _lastGoodItems;
        _debug = '${_debug ?? ""} | ERROR=$_error';
      });
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    final title = _mode == ViewMode.day
        ? _titleForDay(t)
        : _titleForRange(t);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: t.t('refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: t.t('filters'),
            onPressed: _showQuickSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.sports_soccer), text: t.t('matches')),
            Tab(icon: const Icon(Icons.emoji_events), text: t.t('top10')),
          ],
        ),
      ),
      body: Column(
        children: [
          _topControls(t),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildMatchesTab(t),
                _buildTop10Tab(t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleForDay(AppL10n t) {
    if (_dayOffset == -1) return t.t('matches_yesterday');
    if (_dayOffset == 0) return t.t('matches_today');
    if (_dayOffset == 1) return t.t('matches_tomorrow');
    return '${t.t('matches_in')} ${_dayOffset}';
  }

  String _titleForRange(AppL10n t) {
    final r = _range;
    if (r == null) return '${t.t('matches_range')} (${_rangeDays} ${t.t('days')})';
    return '${t.t('matches_range')} ${_ymd(r.start)} → ${_ymd(r.end)}';
  }

  Widget _topControls(AppL10n t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode chips: Zi / Interval
          Row(
            children: [
              ChoiceChip(
                selected: _mode == ViewMode.day,
                label: Text(t.t('day')),
                onSelected: (_) async {
                  setState(() => _mode = ViewMode.day);
                  await _load();
                },
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                selected: _mode == ViewMode.range,
                label: Text(t.t('range')),
                onSelected: (_) async {
                  setState(() => _mode = ViewMode.range);
                  await _load();
                },
              ),
              const Spacer(),
              if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 10),

          if (_mode == ViewMode.day)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _dayChip(t, label: t.t('yesterday'), offset: -1),
                _dayChip(t, label: t.t('today'), offset: 0),
                _dayChip(t, label: t.t('tomorrow'), offset: 1),
                _dayChip(t, label: '${t.t('in')} 2', offset: 2),
                _dayChip(t, label: '${t.t('in')} 3', offset: 3),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  label: Text('${t.t('pick_range')} (≤ 7)'),
                  onPressed: _pickRange,
                ),
                ChoiceChip(
                  selected: _rangeDays == 3,
                  label: Text('${t.t('last')} 3 ${t.t('days')}'),
                  onSelected: (_) async {
                    setState(() {
                      _rangeDays = 3;
                      _range = null;
                    });
                    await _load();
                  },
                ),
                ChoiceChip(
                  selected: _rangeDays == 5,
                  label: Text('${t.t('last')} 5 ${t.t('days')}'),
                  onSelected: (_) async {
                    setState(() {
                      _rangeDays = 5;
                      _range = null;
                    });
                    await _load();
                  },
                ),
                ChoiceChip(
                  selected: _rangeDays == 7,
                  label: Text('${t.t('last')} 7 ${t.t('days')}'),
                  onSelected: (_) async {
                    setState(() {
                      _rangeDays = 7;
                      _range = null;
                    });
                    await _load();
                  },
                ),
              ],
            ),

          // Debug/Error row (safe)
          if (_error != null || _debug != null) ...[
            const SizedBox(height: 10),
            Text(
              _error != null ? 'Info: $_error' : 'Info: $_debug',
              style: TextStyle(
                color: _error != null ? Colors.redAccent : Colors.white70,
                fontSize: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayChip(AppL10n t, {required String label, required int offset}) {
    return ChoiceChip(
      selected: _dayOffset == offset && _mode == ViewMode.day,
      label: Text(label),
      onSelected: (_) async {
        setState(() {
          _mode = ViewMode.day;
          _dayOffset = offset;
        });
        await _load();
      },
    );
  }

  Widget _buildMatchesTab(AppL10n t) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t.t('no_matches')),
        ),
      );
    }

    final groups = _groupForUI(_items);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final g = groups[index];
        return _GroupSection(group: g);
      },
    );
  }

  Widget _buildTop10Tab(AppL10n t) {
    final top = _computeTop10(_items);

    if (_loading && top.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (top.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t.t('top10_empty')),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: top.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = top[i];
        return _TopCard(rank: i + 1, f: item);
      },
    );
  }

  void _showQuickSettings() {
    final t = AppL10n.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(t.t('settings'), style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Text('TZ: $_tz', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(t.t('pick_range')),
                  subtitle: Text(t.t('max_7_days')),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickRange();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(t.t('refresh')),
                  onTap: () async {
                    Navigator.pop(context);
                    await _load();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

  // ---------- Top 10 heuristic (safe, deterministic) ----------
  List<FixtureLite> _computeTop10(List<FixtureLite> items) {
    // Simple “real” confidence without predictions endpoint:
    // finished matches get 0, not started get slight boost, popular leagues not tracked -> neutral.
    // You can replace this later with real API predictions once stable.
    double score(FixtureLite f) {
      if (f.isFinished) return 0;
      // prioritize matches that are not started and have known teams
      double s = 50;
      if (f.isNotStarted) s += 10;
      if (f.home.isNotEmpty && f.away.isNotEmpty) s += 5;
      // earlier kickoff => higher priority for "today"
      final now = DateTime.now().toUtc();
      final diffH = f.dateUtc.difference(now).inMinutes / 60.0;
      if (diffH.abs() < 6) s += 5;
      return s;
    }

    final list = List<FixtureLite>.from(items);
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list.take(10).toList();
  }
}

// -------------------- UI widgets --------------------

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

class _GroupSection extends StatelessWidget {
  final _UiGroup group;
  const _GroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    switch (group.type) {
      case _UiGroupType.day:
        final d = group.day!;
        final label = _dayLabel(t, d);
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
          child: Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const Expanded(child: Divider(indent: 12)),
            ],
          ),
        );

      case _UiGroupType.league:
        final text = group.country == null || group.country!.isEmpty
            ? group.league!
            : '${group.league!} • ${group.country!}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        );

      case _UiGroupType.fixture:
        return _FixtureCard(f: group.fixture!);
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

    // e.g. Luni, 16 feb.
    final weekday = [
      t.t('mon'),
      t.t('tue'),
      t.t('wed'),
      t.t('thu'),
      t.t('fri'),
      t.t('sat'),
      t.t('sun'),
    ][dd.weekday - 1];

    return '$weekday, ${dd.day.toString().padLeft(2, '0')}.${dd.month.toString().padLeft(2, '0')}';
  }
}

class _FixtureCard extends StatelessWidget {
  final FixtureLite f;
  const _FixtureCard({required this.f});

  @override
  Widget build(BuildContext context) {
    final local = f.dateUtc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row: status/time + score
          Row(
            children: [
              _badge(f.statusShort.isEmpty ? '—' : f.statusShort),
              const SizedBox(width: 10),
              Text('$hh:$mm', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                f.scoreText,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${f.home} vs ${f.away}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            f.leagueName,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _TopCard extends StatelessWidget {
  final int rank;
  final FixtureLite f;
  const _TopCard({required this.rank, required this.f});

  @override
  Widget build(BuildContext context) {
    final local = f.dateUtc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white10),
            ),
            alignment: Alignment.center,
            child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f.home} vs ${f.away}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${f.leagueLabel()} • $hh:$mm', style: const TextStyle(color: Colors.white70)),
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
