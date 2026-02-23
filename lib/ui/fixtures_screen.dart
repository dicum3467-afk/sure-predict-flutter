import 'package:flutter/material.dart';

import '../services/sure_predict_service.dart';
import '../widgets/modal_sheet_presentation.dart';
import 'prediction_sheet.dart';
import 'fixture_ui.dart';

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
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _fixtures = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).toIso8601String();
      final to = DateTime(now.year, now.month, now.day + 7).toIso8601String();

      final data = await widget.service.getFixtures(
        leagueId: widget.leagueId,
        from: from,
        to: to,
      );

      setState(() {
        _fixtures = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openPrediction(Map<String, dynamic> fixture) async {
    try {
      final providerFixtureId = fixture['provider_fixture_id']?.toString() ?? '';
      if (providerFixtureId.isEmpty) return;

      final pred = await widget.service.getPrediction(providerFixtureId: providerFixtureId);

      if (!mounted) return;

      await showModalSheet(
        context,
        content: PredictionSheet(
          fixture: fixture,
          prediction: pred,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leagueName),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, i) {
                    final f = _fixtures[i];
                    final home = (f['home'] ?? '').toString();
                    final away = (f['away'] ?? '').toString();
                    final status = (f['status'] ?? 'scheduled').toString();
                    final kickoffRaw = f['kickoff'] ?? f['date'] ?? f['utcDate'];
                    DateTime? kickoff;
                    try {
                      if (kickoffRaw != null) kickoff = DateTime.parse(kickoffRaw.toString());
                    } catch (_) {}

                    final st = statusStyle(status);

                    return InkWell(
                      onTap: () => _openPrediction(f),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$home vs $away',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: st.bg,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          st.text,
                                          style: TextStyle(
                                            color: st.fg,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        kickoff == null ? '' : formatKickoff(kickoff),
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _fixtures.length,
                ),
    );
  }
}
