import 'package:flutter/material.dart';
import '../api/api_football.dart';
import '../models/fixture.dart';
import '../services/prediction_cache.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiFootball api;
  late final PredictionCache predictionCache;

  bool loading = true;
  String? error;
  List<FixtureLite> fixtures = [];

  @override
  void initState() {
    super.initState();

    const apiKey = String.fromEnvironment('APIFOOTBALL_KEY');

    api = ApiFootball(apiKey);
    predictionCache = PredictionCache(api: api);

    _loadToday();
  }

  Future<void> _loadToday() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final today = DateTime.now();
      final res = await api.fixturesByDate(today);

      if (!res.isOk) {
        setState(() {
          error = res.error;
          loading = false;
        });
        return;
      }

      setState(() {
        fixtures = res.data ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const debugKey = String.fromEnvironment('APIFOOTBALL_KEY');

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1B17),
        title: const Text('Meciuri azi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? _errorCard(error!)
                : fixtures.isEmpty
                    ? const Text('Nu sunt meciuri azi.')
                    : ListView(
                        children: [
                          _debugCard(debugKey),
                          const SizedBox(height: 16),
                          ...fixtures.map(_fixtureCard),
                        ],
                      ),
      ),
    );
  }

  // ---------------- UI ----------------

  Widget _debugCard(String key) {
    return Card(
      color: const Color(0xFF1C2A25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'DEBUG KEY: ${key.isEmpty ? "EMPTY" : key.substring(0, 4)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Card(
      color: const Color(0xFF1C2A25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _fixtureCard(FixtureLite f) {
    return Card(
      color: const Color(0xFF1C2A25),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${f.home} vs ${f.away}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(f.leagueName),
            const SizedBox(height: 12),
            FutureBuilder<PredictionLite?>(
              future: predictionCache.getForFixture(f),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Text('Calcul AI...');
                }

                final p = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _predChip(p.topPick),
                        const SizedBox(width: 8),
                        Text(
                          'Confidence ${p.confidence}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _miniBar(
                      leftLabel: '1',
                      midLabel: 'X',
                      rightLabel: '2',
                      pLeft: p.pHome,
                      pMid: p.pDraw,
                      pRight: p.pAway,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.extras,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _predChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _miniBar({
    required String leftLabel,
    required String midLabel,
    required String rightLabel,
    required double pLeft,
    required double pMid,
    required double pRight,
  }) {
    final total = pLeft + pMid + pRight;
    final l = total > 0 ? pLeft / total : 0.33;
    final m = total > 0 ? pMid / total : 0.34;
    final r = total > 0 ? pRight / total : 0.33;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: (l * 100).round(),
              child: Container(
                height: 8,
                color: Colors.green,
              ),
            ),
            Expanded(
              flex: (m * 100).round(),
              child: Container(
                height: 8,
                color: Colors.orange,
              ),
            ),
            Expanded(
              flex: (r * 100).round(),
              child: Container(
                height: 8,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text('$leftLabel ${(pLeft * 100).toStringAsFixed(0)}%'),
            Text('$midLabel ${(pMid * 100).toStringAsFixed(0)}%'),
            Text('$rightLabel ${(pRight * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ],
    );
  }
}
