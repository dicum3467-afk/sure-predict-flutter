import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';
import '../services/prediction_cache.dart';
import 'match_screen.dart';

enum _ViewMode { singleDay, range }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiFootball api;
  late final PredictionCache predCache;

  bool loading = true;
  String? errorText;

  // ✅ lista curentă
  List<FixtureLite> fixtures = const [];

  // ✅ ultimul rezultat bun (stale cache)
  List<FixtureLite> lastGoodFixtures = const [];
  DateTime? lastGoodAt;

  bool romaniaOnly = false;

  _ViewMode viewMode = _ViewMode.singleDay;
  int dayOffset = 0;

  int rangeDays = 7;
  bool includePast = true;
  bool includeFuture = true;

  bool topLoading = false;
  String? topError;
  List<_TopItem> top10 = const [];

  static const int _maxRangeDays = 7;

  DateTime? _lastRefreshTap; // debounce refresh taps

  @override
  void initState() {
    super.initState();
    api = ApiFootball.fromDartDefine();
    predCache = PredictionCache(api: api);
    _load(showSpinner: true);
  }

  int _clampedRangeDays(int d) => d.clamp(1, _maxRangeDays);

  // ---------- API ----------
  Future<List<FixtureLite>> _fixturesByDate(DateTime date, String tz) async {
    final raw = await api.fixturesByDate(date: date, timezone: tz);
    return raw.map((m) => FixtureLite.fromApiFootball(m)).toList();
  }

  // ---------- LOAD with stale fallback ----------
  Future<void> _load({required bool showSpinner}) async {
    if (showSpinner) {
      setState(() {
        loading = true;
        errorText = null;
      });
    } else {
      setState(() => errorText = null);
    }

    // NU ștergem predCache înainte să știm că avem succes (reduce “gol după refresh”)
    setState(() {
      top10 = const [];
      topError = null;
      topLoading = false;
    });

    try {
      const tz = 'Europe/Bucharest';
      final now = DateTime.now();

      List<FixtureLite> res;

      if (viewMode == _ViewMode.singleDay) {
        res = await _fixturesByDate(now.add(Duration(days: dayOffset)), tz);
      } else {
        final d = _clampedRangeDays(rangeDays);

        final days = <DateTime>[];
        if (includePast) {
          for (int i = d; i >= 1; i--) {
            days.add(now.subtract(Duration(days: i)));
          }
        }
        days.add(now);
        if (includeFuture) {
          for (int i = 1; i <= d; i++) {
            days.add(now.add(Duration(days: i)));
          }
        }

        final combined = <FixtureLite>[];
        for (final day in days) {
          combined.addAll(await _fixturesByDate(day, tz));
        }

        final seen = <int>{};
        res = combined.where((f) => seen.add(f.id)).toList();
      }

      if (romaniaOnly) {
        res = res.where((f) {
          final c = (f.country ?? '').toLowerCase();
          final l = (f.league ?? '').toLowerCase();
          return c.contains('romania') || l.contains('romania') || l.contains('liga');
        }).toList();
      }

      // sort: zi -> ligă -> oră -> echipă
      res.sort((a, b) => _fixtureCompare(a, b));

      // ✅ SUCCESS: actualizăm cache + resetăm pred cache
      predCache.clear();

      setState(() {
        fixtures = res;
        lastGoodFixtures = res;
        lastGoodAt = DateTime.now();
        loading = false;
        errorText = null;
      });

      _buildTop10();
    } catch (e) {
      // ✅ dacă a eșuat refresh: păstrăm lastGoodFixtures pe ecran
      setState(() {
        fixtures = lastGoodFixtures;
        loading = false;
        errorText = e.toString();
      });
    }
  }

  int _fixtureCompare(FixtureLite a, FixtureLite b) {
    final da = a.date ?? DateTime(3000);
    final db = b.date ?? DateTime(3000);

    final aDay = DateTime(da.year, da.month, da.day);
    final bDay = DateTime(db.year, db.month, db.day);
    final cDay = aDay.compareTo(bDay);
    if (cDay != 0) return cDay;

    final la = (a.league ?? '').toLowerCase();
    final lb = (b.league ?? '').toLowerCase();
    final cLeague = la.compareTo(lb);
    if (cLeague != 0) return cLeague;

    final cTime = da.compareTo(db);
    if (cTime != 0) return cTime;

    return a.home.toLowerCase().compareTo(b.home.toLowerCase());
  }

  // ---------- TOP 10 ----------
  Future<void> _buildTop10() async {
    if (!mounted) return;
    if (fixtures.isEmpty) return;

    setState(() {
      topLoading = true;
      topError = null;
      top10 = const [];
    });

    try {
      final items = <_TopItem>[];
      for (final f in fixtures) {
        final p = await predCache.getForFixture(f);
        if (!mounted) return;
        if (p == null) continue;
        items.add(_TopItem(fixture: f, pred: p));
      }

      items.sort((a, b) => b.pred.confidence.compareTo(a.pred.confidence));

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

  // ---------- UI ----------
  void _refreshTapped() {
    final now = DateTime.now();
    if (_lastRefreshTap != null && now.difference(_lastRefreshTap!).inSeconds < 2) {
      // debounce: ignore rapid taps
      return;
    }
    _lastRefreshTap = now;
    _load(showSpinner: false);
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
                      setState(() => romaniaOnly = false);
                      Navigator.pop(context);
                      _load(showSpinner: true);
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
                  _load(showSpinner: true);
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
    final title = viewMode == _ViewMode.singleDay ? _singleTitle(t) : 'Interval ${_rangeLabel()}';

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
            IconButton(onPressed: _openFilters, icon: const Icon(Icons.tune)),
            IconButton(onPressed: _refreshTapped, icon: const Icon(Icons.refresh)),
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

  String _singleTitle(AppL10n t) {
    if (dayOffset == 0) return t.t('matches_today');
    if (dayOffset == 1) return t.t('matches_tomorrow');
    if (dayOffset == -1) return 'Meciuri ieri';
    if (dayOffset > 1) return 'Ziua +$dayOffset';
    return 'Ziua $dayOffset';
  }

  String _rangeLabel() {
    final d = _clampedRangeDays(rangeDays);
    final parts = <String>[];
    if (includePast) parts.add('-$d');
    parts.add('0');
    if (includeFuture) parts.add('+$d');
    return parts.join(' .. ');
  }

  Widget _tabMatches(AppL10n t) {
    if (loading) return Center(child: Text(t.t('loading')));

    final rows = _buildRowsDayLeague(fixtures);

    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: rows.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _errorBannerIfNeeded();
          if (i == 1) return _modeControls(t);
          final r = rows[i - 2];

          if (r.kind == _RowKind.dayHeader) return _dayHeader(context, r.day!);
          if (r.kind == _RowKind.leagueHeader) return _leagueHeader(r.leagueName!, r.country);
          return _fixtureCard(context, t, r.fixture!);
        },
      ),
    );
  }

  Widget _errorBannerIfNeeded() {
    if (errorText == null) return const SizedBox.shrink();

    final ts = lastGoodAt == null ? '' : ' (ultimul rezultat: ${DateFormat('HH:mm').format(lastGoodAt!)})';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.red.withOpacity(0.12),
          border: Border.all(color: Colors.red.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.all(12),
        child: Text(
          'Refresh a eșuat$ts.\n${errorText!}',
          style: TextStyle(color: Colors.white.withOpacity(0.90)),
        ),
      ),
    );
  }

  List<_RowItem> _buildRowsDayLeague(List<FixtureLite> list) {
    final rows = <_RowItem>[];

    DateTime? currentDay;
    String? currentLeague;

    for (final f in list) {
      final dt = f.date ?? DateTime(3000, 1, 1);
      final day = DateTime(dt.year, dt.month, dt.day);
      final league = (f.league ?? '').trim();
      final leagueKey = league.isEmpty ? '—' : league;

      if (currentDay == null || day != currentDay) {
        currentDay = day;
        currentLeague = null;
        rows.add(_RowItem.day(day));
      }

      if (currentLeague == null || leagueKey != currentLeague) {
        currentLeague = leagueKey;
        rows.add(_RowItem.league(leagueKey, country: f.country));
      }

      rows.add(_RowItem.fixture(f));
    }

    return rows;
  }

  Widget _dayHeader(BuildContext context, DateTime day) {
    final loc = Localizations.localeOf(context).toLanguageTag();
    final text = DateFormat('EEEE, d MMM', loc).format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Row(
        children: [
          Text(
            text[0].toUpperCase() + text.substring(1),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1)),
        ],
      ),
    );
  }

  Widget _leagueHeader(String league, String? country) {
    final sub = (country == null || country.isEmpty) ? '' : ' • $country';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              '$league$sub',
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.85)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeControls(AppL10n t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('Zi'),
                selected: viewMode == _ViewMode.singleDay,
                onSelected: (_) {
                  setState(() => viewMode = _ViewMode.singleDay);
                  _load(showSpinner: true);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Interval'),
                selected: viewMode == _ViewMode.range,
                onSelected: (_) {
                  setState(() => viewMode = _ViewMode.range);
                  rangeDays = _clampedRangeDays(rangeDays);
                  _load(showSpinner: true);
                },
              ),
              const Spacer(),
              if (romaniaOnly) Chip(label: Text(t.t('romania_only'))),
            ],
          ),
          const SizedBox(height: 10),
          if (viewMode == _ViewMode.singleDay) _singleDayChips(t) else _rangeControls(),
        ],
      ),
    );
  }

  Widget _singleDayChips(AppL10n t) {
    Widget chip(String label, bool selected, int newOffset) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            setState(() => dayOffset = newOffset);
            _load(showSpinner: true);
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Ieri', dayOffset == -1, -1),
          chip(t.t('matches_today'), dayOffset == 0, 0),
          chip(t.t('matches_tomorrow'), dayOffset == 1, 1),
          chip('În 2 zile', dayOffset == 2, 2),
          chip('În 3 zile', dayOffset == 3, 3),
        ],
      ),
    );
  }

  Widget _rangeControls() {
    final d = _clampedRangeDays(rangeDays);

    Widget chip(String label, bool selected, int newDays) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => _setRangeDays(newDays),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            chip('±3 zile', d == 3, 3),
            chip('±7 zile', d == 7, 7),
            chip('±14 zile', rangeDays == 14, 14),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Include trecut'),
                value: includePast,
                onChanged: (v) {
                  setState(() => includePast = v);
                  _load(showSpinner: true);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Include viitor'),
                value: includeFuture,
                onChanged: (v) {
                  setState(() => includeFuture = v);
                  _load(showSpinner: true);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tabTop10(AppL10n t) {
    if (loading) return Center(child: Text(t.t('loading')));
    if (fixtures.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Info', t.t('no_matches')));

    if (topLoading) return const Center(child: CircularProgressIndicator());
    if (topError != null) return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Top 10', topError!));
    if (top10.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: _infoCard('Top 10', 'Nu există suficiente predicții pentru Top 10 acum.'));

    return RefreshIndicator(
      onRefresh: () async => _load(showSpinner: false),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: top10.length,
        itemBuilder: (context, i) => _topCard(context, top10[i], rank: i + 1),
      ),
    );
  }

  Widget _fixtureCard(BuildContext context, AppL10n t, FixtureLite f) {
    final loc = Localizations.localeOf(context).toLanguageTag();
    final timeText = f.date == null ? '—' : DateFormat('HH:mm', loc).format(f.date!.toLocal());
    final leagueText = (f.league ?? '').isEmpty ? '—' : (f.league!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(api: api, fixture: f))),
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
                  _statusPill(f.statusSafe()),
                  const SizedBox(width: 10),
                  _timePill(timeText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${f.home} vs ${f.away}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(leagueText, style: TextStyle(color: Colors.white.withOpacity(0.70))),
              const SizedBox(height: 10),
              FutureBuilder<PredictionLite?>(
                future: predCache.getForFixture(f),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return Text(t.t('loading'));
                  final p = snap.data;
                  if (p == null) return Text(t.t('predictions_unavailable'), style: TextStyle(color: Colors.white.withOpacity(0.70)));

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

  Widget _topCard(BuildContext context, _TopItem item, {required int rank}) {
    final f = item.fixture;
    final p = item.pred;

    final loc = Localizations.localeOf(context).toLanguageTag();
    final timeText = f.date == null ? '—' : DateFormat('HH:mm', loc).format(f.date!.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(api: api, fixture: f))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _rankPill(rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${f.home} vs ${f.away}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Confidence ${p.confidence}% • ${p.sourceTag}', style: TextStyle(color: Colors.white.withOpacity(0.70))),
                    const SizedBox(height: 8),
                    _probBar(p.pHome, p.pDraw, p.pAway),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _pickPill(p.topPick),
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

  Widget _timePill(String txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
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

    final sum = p1 + px + p2;
    if (sum > 0) {
      p1 /= sum;
      px /= sum;
      p2 /= sum;
    }

    Widget seg(double v) => Expanded(
          flex: max(1, (v * 1000).round()),
          child: Container(
            height: 10,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.white.withOpacity(0.18)),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.black.withOpacity(0.08)),
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

enum _RowKind { dayHeader, leagueHeader, fixture }

class _RowItem {
  final _RowKind kind;
  final DateTime? day;
  final String? leagueName;
  final String? country;
  final FixtureLite? fixture;

  const _RowItem._(this.kind, {this.day, this.leagueName, this.country, this.fixture});

  factory _RowItem.day(DateTime d) => _RowItem._(_RowKind.dayHeader, day: d);
  factory _RowItem.league(String name, {String? country}) =>
      _RowItem._(_RowKind.leagueHeader, leagueName: name, country: country);
  factory _RowItem.fixture(FixtureLite f) => _RowItem._(_RowKind.fixture, fixture: f);
}

class _TopItem {
  final FixtureLite fixture;
  final PredictionLite pred;
  const _TopItem({required this.fixture, required this.pred});
}
