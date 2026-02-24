import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;
  final String leagueId;
  final String leagueName;

  const FixturesScreen({
    super.key,
    required this.service,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  // poți schimba intervalul cum vrei
  final String _from = '2026-02-01';
  final String _to = '2026-02-28';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return widget.service.getFixtures(
      leagueIds: [widget.leagueId], // IMPORTANT: listă
      from: _from,
      to: _to,
      runType: 'initial',
      limit: 50,
      offset: 0,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  String _fmtPct(dynamic v) {
    if (v == null) return '-';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '-';
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  void _openPrediction(BuildContext context, Map<String, dynamic> item) {
    final providerId = (item['provider_fixture_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: widget.service.getPrediction(providerFixtureId: providerId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snap.hasError) {
                  return SizedBox(
                    height: 220,
                    child: Center(child: Text('Eroare: ${snap.error}')),
                  );
                }

                final pred = snap.data ?? <String, dynamic>{};

                // backend-ul poate întoarce fie câmpuri direct, fie un obiect
                final pHome = pred['p_home'] ?? item['p_home'];
                final pDraw = pred['p_draw'] ?? item['p_draw'];
                final pAway = pred['p_away'] ?? item['p_away'];
                final pOver = pred['p_over25'] ?? item['p_over25'];
                final pUnder = pred['p_under25'] ?? item['p_under25'];

                final home = (item['home'] ?? '').toString();
                final away = (item['away'] ?? '').toString();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$home vs $away',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _PredRow(label: '1 (Home)', value: _fmtPct(pHome)),
                    _PredRow(label: 'X (Draw)', value: _fmtPct(pDraw)),
                    _PredRow(label: '2 (Away)', value: _fmtPct(pAway)),
                    const Divider(height: 24),
                    _PredRow(label: 'Over 2.5', value: _fmtPct(pOver)),
                    _PredRow(label: 'Under 2.5', value: _fmtPct(pUnder)),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fixtures • ${widget.leagueName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Eroare: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data ?? const <Map<String, dynamic>>[];
          if (data.isEmpty) {
            return const Center(child: Text('Nu există meciuri încă.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: data.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = data[i];

                final home = (item['home'] ?? '').toString();
                final away = (item['away'] ?? '').toString();
                final status = (item['status'] ?? '').toString();
                final kickoff = (item['kickoff_at'] ?? '').toString();

                final pHome = item['p_home'];
                final pDraw = item['p_draw'];
                final pAway = item['p_away'];

                return ListTile(
                  title: Text('$home vs $away'),
                  subtitle: Text('Status: $status\nKickoff: $kickoff'),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('1 ${_fmtPct(pHome)}'),
                      Text('X ${_fmtPct(pDraw)}'),
                      Text('2 ${_fmtPct(pAway)}'),
                    ],
                  ),
                  onTap: () => _openPrediction(context, item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PredRow extends StatelessWidget {
  final String label;
  final String value;

  const _PredRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
