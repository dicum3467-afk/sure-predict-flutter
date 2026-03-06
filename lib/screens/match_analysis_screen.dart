import 'package:flutter/material.dart';
import '../models/api_models.dart';
import '../models/app_models.dart';
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

  PredictionResponse? prediction;
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

  String _formatKickoff(DateTime dt) {
    final local = dt.toLocal();
    return "${local.day}.${local.month}.${local.year} "
        "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
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
          _MatchHeaderCard(
            leagueName: fixture.leagueName,
            homeTeam: fixture.homeTeam,
            awayTeam: fixture.awayTeam,
            kickoffText: _formatKickoff(fixture.kickoffAt),
          ),
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
        _sectionTitle('Expected Goals'),
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'Home xG',
                value: _formatDouble(inputs['lambda_home']),
                icon: Icons.home_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                title: 'Away xG',
                value: _formatDouble(inputs['lambda_away']),
                icon: Icons.flight_takeoff_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Confidence'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: ((metrics['confidence_1x2'] ?? 0).toDouble()),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatPercent(metrics['confidence_1x2']),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Main Picks'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _pickChip(
              '1X2',
              prediction?.picks['1x2']?['pick']?.toString() ?? '-',
            ),
            _pickChip(
              'GG',
              prediction?.picks['gg']?['pick']?.toString() ?? '-',
            ),
            _pickChip(
              'O/U 2.5',
              prediction?.picks['ou25']?['pick']?.toString() ?? '-',
            ),
            _pickChip(
              'HT',
              prediction?.picks['ht']?['pick']?.toString() ?? '-',
            ),
            _pickChip(
              'HT/FT',
              prediction?.picks['htft']?['pick']?.toString() ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Top Scorelines'),
        Card(
          child: Column(
            children: (probs['top_scorelines'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e))
                .map(
                  (e) => ListTile(
                    title: Text('${e['home']}-${e['away']}'),
                    trailing: Text(_formatPercent(e['p'])),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsTab() {
    final probs = prediction?.probs ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('1X2'),
        _marketCard({
          '1': _formatPercent(probs['1x2']?['1']),
          'X': _formatPercent(probs['1x2']?['X']),
          '2': _formatPercent(probs['1x2']?['2']),
        }, columns: 3),
        const SizedBox(height: 16),
        _sectionTitle('Double Chance'),
        _marketCard({
          '1X': _formatPercent(probs['double_chance']?['1X']),
          '12': _formatPercent(probs['double_chance']?['12']),
          'X2': _formatPercent(probs['double_chance']?['X2']),
        }, columns: 3),
        const SizedBox(height: 16),
        _sectionTitle('GG / NG'),
        _marketCard({
          'GG': _formatPercent(probs['gg']?['GG']),
          'NG': _formatPercent(probs['gg']?['NG']),
        }),
        const SizedBox(height: 16),
        _sectionTitle('Over / Under 2.5'),
        _marketCard({
          'O2.5': _formatPercent(probs['ou25']?['O2.5']),
          'U2.5': _formatPercent(probs['ou25']?['U2.5']),
        }),
        const SizedBox(height: 16),
        _sectionTitle('Half Time'),
        _marketCard({
          'HT1': _formatPercent(probs['ht']?['HT1']),
          'HTX': _formatPercent(probs['ht']?['HTX']),
          'HT2': _formatPercent(probs['ht']?['HT2']),
        }, columns: 3),
      ],
    );
  }

  Widget _buildValueTab() {
    final items = valuePicks?.items ?? [];

    if (items.isEmpty) {
      return const Center(
        child: Text('No value picks available.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final item = items[index];
        return Card(
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
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Model: ${(item.modelProb * 100).toStringAsFixed(1)}%'),
                Text('Fair odd: ${item.fairOdd?.toStringAsFixed(2) ?? '-'}'),
                Text('Book odd: ${item.bookOdd.toStringAsFixed(2)}'),
                Text('EV: ${(item.expectedValue * 100).toStringAsFixed(1)}%'),
                Text('Edge: ${(item.edge * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
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

  Widget _pickChip(String label, String value) {
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

  Widget _marketCard(Map<String, String> items, {int columns = 2}) {
    final entries = items.entries.toList();
    return Card(
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
            final e = entries[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(e.key),
                  const SizedBox(height: 4),
                  Text(
                    e.value,
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

class _MatchHeaderCard extends StatelessWidget {
  final String leagueName;
  final String homeTeam;
  final String awayTeam;
  final String kickoffText;

  const _MatchHeaderCard({
    required this.leagueName,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoffText,
  });

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
          Text(leagueName),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  homeTeam,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('vs'),
              ),
              Expanded(
                child: Text(
                  awayTeam,
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
            kickoffText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
