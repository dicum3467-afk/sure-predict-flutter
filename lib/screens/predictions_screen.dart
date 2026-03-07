import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prediction_model.dart';
import '../services/predictions_service.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  late Future<List<PredictionItem>> _future;
  final _service = PredictionsService();

  @override
  void initState() {
    super.initState();
    _future = _service.fetchPredictions(limit: 50);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.fetchPredictions(limit: 50);
    });
    await _future;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('finished')) return Colors.green;
    if (s.contains('live')) return Colors.redAccent;
    if (s.contains('scheduled') || s.contains('ns')) return Colors.blue;
    return Colors.grey;
  }

  Widget _percentBox(String label, double value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallMarketBox(String label, double value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectScores(List<CorrectScore> scores) {
    if (scores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Correct Score',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: scores
              .map(
                (s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '${s.score} • ${s.probability.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPredictionCard(PredictionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151A22),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.leagueName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 20,
            ),
          ),
          if (item.round != null) ...[
            const SizedBox(height: 4),
            Text(
              item.round.toString(),
              style: const TextStyle(color: Colors.white38),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.homeTeam.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'VS',
                  style: TextStyle(color: Colors.white60, fontSize: 20),
                ),
              ),
              Expanded(
                child: Text(
                  item.awayTeam.name,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(item.kickoffAt),
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    color: _statusColor(item.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'xG ${item.homeTeam.short.isNotEmpty ? item.homeTeam.short : item.homeTeam.name}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Text(
                  item.model.homeXg.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    'xG ${item.awayTeam.short.isNotEmpty ? item.awayTeam.short : item.awayTeam.name}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  item.model.awayXg.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '1X2',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _percentBox('1', item.markets.oneXTwo.home),
              const SizedBox(width: 10),
              _percentBox('X', item.markets.oneXTwo.draw),
              const SizedBox(width: 10),
              _percentBox('2', item.markets.oneXTwo.away),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _smallMarketBox('GG', item.markets.btts.gg),
              const SizedBox(width: 10),
              _smallMarketBox('Over 2.5', item.markets.ou25.over25),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _smallMarketBox('1X', item.markets.doubleChance.oneX),
              const SizedBox(width: 10),
              _smallMarketBox('X2', item.markets.doubleChance.xTwo),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Text(
                  '✨',
                  style: TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Top Pick: ${item.topPick.market} • ${item.topPick.confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildCorrectScores(item.markets.correctScoreTop),
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            collapsedIconColor: Colors.white70,
            iconColor: Colors.white70,
            title: const Text(
              'Detalii model',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              const SizedBox(height: 8),
              _detailRow('Model', item.model.type),
              _detailRow('League avg home goals', item.model.avgHomeGoalsLeague.toStringAsFixed(2)),
              _detailRow('League avg away goals', item.model.avgAwayGoalsLeague.toStringAsFixed(2)),
              _detailRow('Home ELO', item.model.homeElo.toStringAsFixed(1)),
              _detailRow('Away ELO', item.model.awayElo.toStringAsFixed(1)),
              _detailRow('ELO diff', item.model.eloDiff.toStringAsFixed(1)),
              if (item.analysis.summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.analysis.summary,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
              if (item.analysis.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...item.analysis.notes.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.white70)),
                        Expanded(
                          child: Text(
                            n,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        title: const Text('Sure Predict'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<PredictionItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 100),
                  const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
                  const SizedBox(height: 14),
                  const Text(
                    'A apărut o eroare',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _reload,
                    child: const Text('Reîncarcă'),
                  ),
                ],
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.sports_soccer, size: 52, color: Colors.white54),
                  SizedBox(height: 14),
                  Text(
                    'Nu există predicții momentan',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildPredictionCard(items[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
