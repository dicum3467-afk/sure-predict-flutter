import 'package:flutter/material.dart';
import '../models/match_analysis_models.dart';
import '../services/api_service.dart';

class MatchAnalysisScreen extends StatefulWidget {
  final FixtureUiModel fixture;

  const MatchAnalysisScreen({
    super.key,
    required this.fixture,
  });

  @override
  State<MatchAnalysisScreen> createState() => _MatchAnalysisScreenState();
}

class _MatchAnalysisScreenState extends State<MatchAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ApiService _apiService = ApiService();

  MatchPredictionResponse? prediction;
  ValuePicksResponse? valuePicks;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final pred =
          await _apiService.getPredictionByFixture(widget.fixture.fixtureId);
      final value =
          await _apiService.getValueByFixture(widget.fixture.fixtureId);

      if (!mounted) return;
      setState(() {
        prediction = pred;
        valuePicks = value;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  String _formatPercent(dynamic value) {
    final v = (value ?? 0).toDouble() * 100;
    return '${v.toStringAsFixed(1)}%';
  }

  String _formatDouble(dynamic value, {int digits = 2}) {
    return ((value ?? 0).toDouble()).toStringAsFixed(digits);
  }

  @override
  Widget build(BuildContext context) {
    final fixture = widget.fixture;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Analysis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Analysis'),
            Tab(text: 'Predictions'),
            Tab(text: 'Value Picks'),
          ],
        ),
      ),
      body: Column(
        children: [
          _MatchHeaderCard(fixture: fixture),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAnalysisTab(),
                          _buildPredictionsTab(),
                          _buildValueTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    final inputs = prediction?.inputs ?? {};
    final metrics = prediction?.metrics ?? {};
    final probs = prediction?.probs ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: 'Expected Goals'),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Home xG',
                value: _formatDouble(inputs['lambda_home']),
                icon: Icons.home_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Away xG',
                value: _formatDouble(inputs['lambda_away']),
                icon: Icons.flight_takeoff_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Model Confidence'),
        _ConfidenceCard(
          confidence: ((metrics['confidence_1x2'] ?? 0).toDouble()),
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Main Signals'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SignalChip(
              label: '1X2 Pick',
              value: prediction?.picks['1x2']?['pick']?.toString() ?? '-',
            ),
            _SignalChip(
              label: 'GG Pick',
              value: prediction?.picks['gg']?['pick']?.toString() ?? '-',
            ),
            _SignalChip(
              label: 'O/U 2.5',
              value: prediction?.picks['ou25']?['pick']?.toString() ?? '-',
            ),
            _SignalChip(
              label: 'HT Pick',
              value: prediction?.picks['ht']?['pick']?.toString() ?? '-',
            ),
            _SignalChip(
              label: 'HT/FT',
              value: prediction?.picks['htft']?['pick']?.toString() ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Top Scorelines'),
        _TopScorelinesCard(
          items: (probs['top_scorelines'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPredictionsTab() {
    final probs = prediction?.probs ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(title: '1X2'),
        _MarketCard(
          items: {
            '1': _formatPercent(probs['1x2']?['1']),
            'X': _formatPercent(probs['1x2']?['X']),
            '2': _formatPercent(probs['1x2']?['2']),
          },
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Double Chance'),
        _MarketCard(
          items: {
            '1X': _formatPercent(probs['double_chance']?['1X']),
            '12': _formatPercent(probs['double_chance']?['12']),
            'X2': _formatPercent(probs['double_chance']?['X2']),
          },
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'GG / NG'),
        _MarketCard(
          items: {
            'GG': _formatPercent(probs['gg']?['GG']),
            'NG': _formatPercent(probs['gg']?['NG']),
          },
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Over / Under 2.5'),
        _MarketCard(
          items: {
            'O2.5': _formatPercent(probs['ou25']?['O2.5']),
            'U2.5': _formatPercent(probs['ou25']?['U2.5']),
          },
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Half Time'),
        _MarketCard(
          items: {
            'HT1': _formatPercent(probs['ht']?['HT1']),
            'HTX': _formatPercent(probs['ht']?['HTX']),
            'HT2': _formatPercent(probs['ht']?['HT2']),
          },
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'HT / FT'),
        _MarketCard(
          items: Map<String, String>.from(
            (probs['htft'] as Map? ?? {}).map(
              (key, value) => MapEntry(key.toString(), _formatPercent(value)),
            ),
          ),
          columns: 3,
        ),
      ],
    );
  }

  Widget _buildValueTab() {
    final items = valuePicks?.items ?? [];

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No value bets available yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ValuePickCard(item: item);
      },
    );
  }
}

class _MatchHeaderCard extends StatelessWidget {
  final FixtureUiModel fixture;

  const _MatchHeaderCard({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          Text(
            fixture.leagueName,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  fixture.homeTeam,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'vs',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  fixture.awayTeam,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fixture.kickoffAt.toLocal().toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  final double confidence;

  const _ConfidenceCard({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final percent = confidence * 100;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(value: confidence),
            const SizedBox(height: 12),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Model confidence for 1X2'),
          ],
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  final String label;
  final String value;

  const _SignalChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopScorelinesCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _TopScorelinesCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: items.map((e) {
          final score = '${e['home']}-${e['away']}';
          final p = ((e['p'] ?? 0).toDouble() * 100).toStringAsFixed(1);
          return ListTile(
            title: Text(score),
            trailing: Text('$p%'),
          );
        }).toList(),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final Map<String, String> items;
  final int columns;

  const _MarketCard({
    required this.items,
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
    final entries = items.entries.toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: entries.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 2.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, index) {
            final entry = entries[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.key),
                  const SizedBox(height: 4),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ValuePickCard extends StatelessWidget {
  final ValuePickItem item;

  const _ValuePickCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.bookmaker} • ${item.market}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              item.selection,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _miniStat('Model', '${(item.modelProb * 100).toStringAsFixed(1)}%'),
                ),
                Expanded(
                  child: _miniStat('Fair Odd', item.fairOdd?.toStringAsFixed(2) ?? '-'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniStat('Book Odd', item.bookOdd.toStringAsFixed(2)),
                ),
                Expanded(
                  child: _miniStat('EV', '${(item.expectedValue * 100).toStringAsFixed(1)}%'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _miniStat('Edge', '${(item.edge * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
