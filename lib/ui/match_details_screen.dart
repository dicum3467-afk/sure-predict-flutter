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
  late final SurePredictService _service;
  bool loading = true;
  String? error;
  Prediction? prediction;

  @override
  void initState() {
    super.initState();
    final api = ApiClient();
    _service = SurePredictService(api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final pfid = (widget.fixture.providerFixtureId ?? '').toString();
      if (pfid.trim().isEmpty) {
        throw Exception('provider_fixture_id lipsă în fixture_item');
      }

      prediction = await _service.getPrediction(pfid);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _fmtKickoff(dynamic kickoffAt) {
    try {
      if (kickoffAt == null) return '-';
      final s = kickoffAt.toString();
      final dt = DateTime.parse(s).toLocal();
      return DateFormat('EEE, dd MMM yyyy • HH:mm', 'ro_RO').format(dt);
    } catch (_) {
      return kickoffAt?.toString() ?? '-';
    }
  }

  String _pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';

  Widget _chip(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: highlight ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: highlight ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

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
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : (error != null)
                ? Center(child: Text('Error:\n$error'))
                : _content(f),
      ),
    );
  }

  Widget _content(FixtureItem f) {
    final p = prediction;

    final best = p?.bestIndex; // 0 home, 1 draw, 2 away

    return ListView(
      children: [
        Text(
          '${f.home} vs ${f.away}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${_fmtKickoff(f.kickoffAt)} • ${f.status ?? '-'} • run: ${f.runType ?? '-'}',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),

        const Text('1X2 Prediction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip('H', _pct(p?.pHome), highlight: best == 0),
            _chip('D', _pct(p?.pDraw), highlight: best == 1),
            _chip('A', _pct(p?.pAway), highlight: best == 2),
          ],
        ),

        const SizedBox(height: 18),
        const Text('Extra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip('BTTS', _pct(p?.pBtts)),
            _chip('Over 2.5', _pct(p?.pOver25)),
            _chip('Under 2.5', _pct(p?.pUnder25)),
          ],
        ),

        const SizedBox(height: 18),
        if (p?.computedAt != null)
          Text(
            'Computed: ${p!.computedAt}',
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }
}
