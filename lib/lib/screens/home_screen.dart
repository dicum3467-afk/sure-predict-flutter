import 'package:flutter/material.dart';
import '../api/api_football.dart';
import '../l10n/l10n.dart';
import '../models/fixture.dart';
import 'match_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Locale? locale) onChangeLanguage;
  const HomeScreen({super.key, required this.onChangeLanguage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiFootball api;
  bool loading = true;
  List<FixtureLite> fixtures = [];

  @override
  void initState() {
    super.initState();
    const key = String.fromEnvironment('APIFOOTBALL_KEY');
    api = ApiFootball(key);
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final raw = await api.getTodayFixtures();
    setState(() {
      fixtures = raw.map(FixtureLite.fromApi).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('todayMatches')),
        actions: [
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
            if (loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(t.t('loading')),
                ),
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
            if (!loading && fixtures.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('No matches found for today.')),
              ),
          ],
        ),
      ),
    );
  }
}
