import 'package:flutter/material.dart';
import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';
import 'match_screen.dart';

enum _Tab { today, tomorrow, romania, last3days, romaniaLast3days }

class HomeScreen extends StatefulWidget {
  final void Function(Locale? locale) onChangeLanguage;
  const HomeScreen({super.key, required this.onChangeLanguage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiFootball api;

  // DEBUG: verificăm dacă dart-define intră în APK
  static const _key = String.fromEnvironment('APIFOOTBALL_KEY');

  bool loading = true;
  String? error;
  List<FixtureLite> fixtures = [];
  _Tab tab = _Tab.today;

  static const _tz = 'Europe/Bucharest';
  static const _romaniaLeagueId = 283;

  @override
  void initState() {
    super.initState();
    const key = String.fromEnvironment('APIFOOTBALL_KEY');
    api = ApiFootball(key);
    _load();
  }

  DateTime _dateForTab(_Tab t) {
    final now = DateTime.now();
    if (t == _Tab.tomorrow) return now.add(const Duration(days: 1));
    return now;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    if (!api.hasKey) {
      setState(() {
        loading = false;
        fixtures = [];
        error =
            'Lipsește cheia API (APIFOOTBALL_KEY). Seteaz-o în Codemagic (Environment variables) și rebuild APK.';
      });
      return;
    }

    // Ultimele 3 zile (toate ligile)
    if (tab == _Tab.last3days) {
      final res = await api.fixturesLastDays(daysBack: 3, timezone: _tz);
      if (!mounted) return;

      if (!res.isOk) {
        setState(() {
          loading = false;
          fixtures = [];
          error = res.error;
        });
        return;
      }

      setState(() {
        fixtures = res.data!.map(FixtureLite.fromApi).toList();
        loading = false;
      });
      return;
    }

    // România • ultimele 3 zile
    if (tab == _Tab.romaniaLast3days) {
      final res = await api.fixturesLastDays(
        daysBack: 3,
        timezone: _tz,
        leagueId: _romaniaLeagueId,
      );
      if (!mounted) return;

      if (!res.isOk) {
        setState(() {
          loading = false;
          fixtures = [];
          error = res.error;
        });
        return;
      }

      setState(() {
        fixtures = res.data!.map(FixtureLite.fromApi).toList();
        loading = false;
      });
      return;
    }

    // Azi / Mâine / România (azi)
    final date = _dateForTab(tab);

    final res = await api.fixturesByDate(
      date: date,
      timezone: _tz,
      leagueId: tab == _Tab.romania ? _romaniaLeagueId : null,
    );

    if (!mounted) return;

    if (!res.isOk) {
      setState(() {
        loading = false;
        fixtures = [];
        error = res.error;
      });
      return;
    }

    setState(() {
      fixtures = res.data!.map(FixtureLite.fromApi).toList();
      loading = false;
    });

    // fallback: dacă azi e gol, încearcă mâine
    if (tab == _Tab.today && fixtures.isEmpty) {
      final res2 = await api.fixturesByDate(
        date: date.add(const Duration(days: 1)),
        timezone: _tz,
      );
      if (!mounted) return;

      if (res2.isOk) {
        final f2 = res2.data!.map(FixtureLite.fromApi).toList();
        if (f2.isNotEmpty) {
          setState(() {
            tab = _Tab.tomorrow;
            fixtures = f2;
            error = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    String title;
    switch (tab) {
      case _Tab.today:
        title = t.t('todayMatches');
        break;
      case _Tab.tomorrow:
        title = 'Meciuri mâine';
        break;
      case _Tab.romania:
        title = 'România • SuperLiga';
        break;
      case _Tab.last3days:
        title = 'Ultimele 3 zile';
        break;
      case _Tab.romaniaLast3days:
        title = 'România • ultimele 3 zile';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<_Tab>(
            icon: const Icon(Icons.tune),
            onSelected: (v) {
              setState(() => tab = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Tab.today, child: Text('Azi')),
              PopupMenuItem(value: _Tab.tomorrow, child: Text('Mâine')),
              PopupMenuItem(value: _Tab.romania, child: Text('România (SuperLiga)')),
              PopupMenuItem(value: _Tab.last3days, child: Text('Ultimele 3 zile')),
              PopupMenuItem(value: _Tab.romaniaLast3days, child: Text('România • ultimele 3 zile')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (v) {
              if (v == 'ro') widget.onChangeLanguage(const Locale('ro'));
              if (v == 'en') widget.onChangeLanguage(const Locale('en'));
              if (v == 'sys') widget.onChangeLanguage(null);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ro', child: Text('Română')),
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'sys', child: Text('System')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // DEBUG CARD (după ce merge, îl ștergem)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'DEBUG KEY: ${_key.isEmpty ? "EMPTY" : _key.substring(0, 4)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),

            if (error != null) _warnCard('Info', error!),

            if (loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(t.t('loading')),
                ),
              )
            else if (fixtures.isEmpty && error == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('Nu s-au găsit meciuri pentru selecția curentă.')),
              )
            else
              ..._groupByDay(fixtures).entries.expand((entry) {
                final dayTitle = entry.key;
                final list = entry.value;

                return [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                    child: Text(
                      dayTitle,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  ...list.map(_fixtureCard),
                ];
              }).toList(),
          ],
        ),
      ),
    );
  }

  Map<String, List<FixtureLite>> _groupByDay(List<FixtureLite> all) {
    final map = <String, List<FixtureLite>>{};
    for (final f in all) {
      final d = f.date;
      final key = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
      (map[key] ??= []).add(f);
    }
    return map;
  }

  Widget _fixtureCard(FixtureLite f) {
    final score = (f.goalsHome != null && f.goalsAway != null)
        ? '${f.goalsHome}-${f.goalsAway}'
        : '—';

    final statusBadge = f.isFinished
        ? 'FT'
        : f.isLive
            ? f.statusShort
            : 'NS';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        title: Text('${f.home} vs ${f.away}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(f.league),
        leading: _statusPill(statusBadge),
        trailing: Text(score, style: const TextStyle(fontWeight: FontWeight.w800)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchScreen(api: api, fixture: f),
            ),
          );
        },
      ),
    );
  }

  Widget _statusPill(String s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 1),
      ),
      child: Text(s, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _warnCard(String title, String msg) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(msg),
          ],
        ),
      ),
    );
  }
}
