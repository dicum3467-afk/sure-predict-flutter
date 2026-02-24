import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';

class TopPicksScreen extends StatefulWidget {
  final SurePredictService service;
  final List<String> leagueIds;
  final Map<String, String> leagueNamesById;

  const TopPicksScreen({
    super.key,
    required this.service,
    required this.leagueIds,
    required this.leagueNamesById,
  });

  @override
  State<TopPicksScreen> createState() => _TopPicksScreenState();
}

class _TopPicksScreenState extends State<TopPicksScreen> {
  // default: next 7 days
  late String _from;
  late String _to;

  String _runType = 'initial';
  String? _status;

  bool _onlyStrong = true;
  double _threshold = 0.60;

  int _topN = 20;

  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _from = _fmt(today);
    _to = _fmt(today.add(const Duration(days: 7)));

    _load();
  }

  String _leagueTitle(String leagueId) {
    return widget.leagueNamesById[leagueId] ?? leagueId;
  }

  double _num(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  ({String label, double p}) _bestPick(Map<String, dynamic> it) {
    final pHome = _num(it['p_home']);
    final pDraw = _num(it['p_draw']);
    final pAway = _num(it['p_away']);
    final pOver = _num(it['p_over25']);
    final pUnder = _num(it['p_under25']);

    final candidates = <String, double>{
      '1': pHome,
      'X': pDraw,
      '2': pAway,
      'Over 2.5': pOver,
      'Under 2.5': pUnder,
    };

    String bestLabel = '—';
    double best = 0.0;
    candidates.forEach((k, v) {
      if (v > best) {
        best = v;
        bestLabel = k;
      }
    });

    return (label: bestLabel, p: best);
  }

  double _sortScore(Map<String, dynamic> it) {
    final best = _bestPick(it).p;

    final pHome = _num(it['p_home']);
    final pDraw = _num(it['p_draw']);
    final pAway = _num(it['p_away']);
    final pOver = _num(it['p_over25']);
    final pUnder = _num(it['p_under25']);

    final max1x2 = [pHome, pDraw, pAway].reduce((a, b) => a > b ? a : b);
    final maxOU = [pOver, pUnder].reduce((a, b) => a > b ? a : b);

    return best * 1000 + max1x2 * 100 + maxOU * 10;
  }

  bool _isStrong(Map<String, dynamic> it) => _bestPick(it).p >= _threshold;

  String _fmtPct(dynamic v) => '${(_num(v) * 100).toStringAsFixed(0)}%';

  String _fmt(DateTime d) {
    String two(int x) => x < 10 ? '0$x' : '$x';
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _pickFrom() async {
    final initial = _parseDate(_from) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _from = _fmt(picked));
  }

  Future<void> _pickTo() async {
    final initial = _parseDate(_to) ?? DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _to = _fmt(picked));
  }

  DateTime? _parseDate(String s) {
    try {
      final p = s.split('-');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  void _presetNext7() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _from = _fmt(today);
      _to = _fmt(today.add(const Duration(days: 7)));
    });
  }

  void _presetToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _from = _fmt(today);
      _to = _fmt(today);
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      // luăm un batch mare ca să putem selecta top
      final data = await widget.service.getFixtures(
        leagueIds: widget.leagueIds,
        from: _from,
        to: _to,
        limit: 300,
        offset: 0,
        runType: _runType,
        status: _status,
      );

      data.sort((a, b) => _sortScore(b).compareTo(_sortScore(a)));

      var filtered = data;
      if (_onlyStrong) {
        filtered = data.where(_isStrong).toList();
      }

      if (filtered.length > _topN) {
        filtered = filtered.take(_topN).toList();
      }

      setState(() => _items = filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPrediction(BuildContext context, Map<String, dynamic> item) {
    final providerId = (item['provider_fixture_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    final best = _bestPick(item);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
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

              final pred = snap.data ?? {};
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
                  Text('$home vs $away', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('BEST: ${best.label}', 'CONF ${_fmtPct(best.p)}'),
                      if (_isStrong(item)) _chip('STRONG', '≥ ${(_threshold * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _row('1 (Home)', _fmtPct(pHome)),
                  _row('X (Draw)', _fmtPct(pDraw)),
                  _row('2 (Away)', _fmtPct(pAway)),
                  const Divider(height: 22),
                  _row('Over 2.5', _fmtPct(pOver)),
                  _row('Under 2.5', _fmtPct(pUnder)),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _chip(String title, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(sub),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Picks'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _presetToday,
                      child: const Text('Today'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _presetNext7,
                      child: const Text('Next 7'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Load'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFrom,
                        icon: const Icon(Icons.date_range),
                        label: Text('From: $_from'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTo,
                        icon: const Icon(Icons.event),
                        label: Text('To: $_to'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilterChip(
                      selected: _onlyStrong,
                      onSelected: (v) => setState(() => _onlyStrong = v),
                      label: const Text('Only strong'),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<double>(
                      value: _threshold,
                      items: const [
                        DropdownMenuItem(value: 0.60, child: Text('60%')),
                        DropdownMenuItem(value: 0.65, child: Text('65%')),
                        DropdownMenuItem(value: 0.70, child: Text('70%')),
                      ],
                      onChanged: (v) => setState(() => _threshold = v ?? 0.60),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _topN,
                      items: const [
                        DropdownMenuItem(value: 20, child: Text('Top 20')),
                        DropdownMenuItem(value: 50, child: Text('Top 50')),
                        DropdownMenuItem(value: 100, child: Text('Top 100')),
                      ],
                      onChanged: (v) => setState(() => _topN = v ?? 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Default: Next 7 days • run_type=$_runType',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No picks for current settings.'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          final best = _bestPick(it);

                          final leagueId = (it['league_id'] ?? '').toString();
                          final leagueName = _leagueTitle(leagueId);

                          final home = (it['home'] ?? '').toString();
                          final away = (it['away'] ?? '').toString();
                          final kickoff = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();

                          return ListTile(
                            title: Text('$home vs $away'),
                            subtitle: Text('$leagueName\nKickoff: $kickoff'),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('BEST ${best.label}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(_fmtPct(best.p), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            onTap: () => _openPrediction(context, it),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
