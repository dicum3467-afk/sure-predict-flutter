import 'package:flutter/material.dart';
import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';
import 'match_screen.dart';

enum _Tab { today, tomorrow, romania }

class HomeScreen extends StatefulWidget {
  final void Function(Locale? locale) onChangeLanguage;
  const HomeScreen({super.key, required this.onChangeLanguage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiFootball api;

  bool loading = true;
  String? error;
  List<FixtureLite> fixtures = [];
  _Tab tab = _Tab.today;

  static const _tz = 'Europe/Bucharest';

  // NOTE: API-Football league id for Romania SuperLiga is commonly 283.
  // If in contul tău apare alt ID, îl schimbăm aici.
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
    return now; // today + romania use "today"
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    final date = _dateForTab(tab);

    final res = await api.fixturesByDate(
      date: date,
      timezone: _tz,
      leagueId: tab == _Tab.romania ? _romaniaLeagueId : null,
      // season: DateTime.now().year, // opțional, dacă vrei strict sezonul
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

    final raw = res.data!;
    setState(() {
      fixtures = raw.map(FixtureLite.fromApi).toList();
      loading = false;
    });

    // Expert fallback: dacă azi e gol, încearcă automat mâine (doar pentru tab today)
    if (tab == _Tab.today && fixtures.isEmpty) {
      final res2 = await api.fixturesByDate(date: date.add(const Duration(days: 1)), timezone: _tz);
      if (!mounted) return;
      if (res2.isOk) {
        final raw2 = res2.data!;
        final f2 = raw2.map(FixtureLite.fromApi).toList();
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
            if (!api.hasKey)
              _warnCard(
                'Cheie API lipsă',
                'În Codemagic → Environment variables setează APIFOOTBALL_KEY (Secret), apoi rebuild APK.',
              ),
            if (error != null)
              _warnCard('Eroare API', error!),
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
              ...fixtures.map((f) => Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListTile(
                      title: Text('${f.home} vs ${f.away}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(f.league),
                      trailing: const Icon(Icons.analytics_outlined),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchScreen(api: api, fixture: f),
                          ),
                        );
                      },
                    ),
                  )),
          ],
        ),
      ),
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
