import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/fixture_item.dart';
import '../models/prediction.dart';
import '../services/sure_predict_service.dart';

class MatchDetailsScreen extends StatefulWidget {
  const MatchDetailsScreen({super.key, required this.fixture});

  final FixtureItem fixture;

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  late final ApiClient _api;
  late final SurePredictService _service;

  bool loading = true;
  String? error;
  Prediction? prediction;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _service = SurePredictService(_api);
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final pfid = widget.fixture.providerFixtureId.trim();
      if (pfid.isEmpty) {
        throw Exception('providerFixtureId lipsă');
      }

      prediction = await _service.getPrediction(pfid, runType: 'initial');
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('EEE, dd MMM yyyy • HH:mm').format(dt.toLocal());
  }

  String _pct(double? v) {
    if (v == null) return '-';
    return '${(v * 100).toStringAsFixed(0)}%';
  }

  int? _bestIndex(Prediction? p) {
    if (p == null) return null;
    final a = p.pHome;
    final b = p.pDraw;
    final c = p.pAway;
    if (a == null && b == null && c == null) return null;

    final va = a ?? -1;
    final vb = b ?? -1;
    final vc = c ?? -1;

    if (va >= vb && va >= vc) return 0;
    if (vb >= va && vb >= vc) return 1;
    return 2;
  }

  Widget _probTile({
    required String label,
    required double? value,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _pct(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(
          t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;

    return Scaffold(
      appBar: AppBar(
        title: Text('${f.home} vs ${f.away}'),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : (error != null)
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error:\n$error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _content(f),
      ),
    );
  }

  Widget _content(FixtureItem f) {
    final p = prediction;
    final best = _bestIndex(p);

    return ListView(
      children: [
        Text(
          '${f.home} vs ${f.away}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          '${_formatDate(f.kickoffAt)} • ${f.status} • run: ${f.runType ?? "-"}',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'provider_fixture_id: ${f.providerFixtureId}',
          style: const TextStyle(fontSize: 12),
        ),

        _sectionTitle('1X2 Prediction'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _probTile(label: 'H', value: p?.pHome, highlight: best == 0),
            _probTile(label: 'D', value: p?.pDraw, highlight: best == 1),
            _probTile(label: 'A', value: p?.pAway, highlight: best == 2),
          ],
        ),

        _sectionTitle('Markets'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _probTile(label: 'BTTS', value: p?.pBtts, highlight: false),
            _probTile(label: 'Over 2.5', value: p?.pOver25, highlight: false),
            _probTile(label: 'Under 2.5', value: p?.pUnder25, highlight: false),
          ],
        ),

        if (p?.computedAt != null) ...[
          _sectionTitle('Info'),
          Text(
            'Computed at: ${p!.computedAt}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }
}
