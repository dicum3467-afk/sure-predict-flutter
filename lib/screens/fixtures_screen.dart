import 'package:flutter/material.dart';
import '../services/sure_predict_service.dart';

class FixturesScreen extends StatefulWidget {
  final SurePredictService service;
  final List<String> leagueIds;

  /// id -> name
  final Map<String, String> leagueNamesById;

  final String title;

  const FixturesScreen({
    super.key,
    required this.service,
    required this.leagueIds,
    required this.leagueNamesById,
    required this.title,
  });

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  // date / filters
  String _from = '2026-02-01';
  String _to = '2026-02-28';
  String _runType = 'initial';
  String? _status;

  // strong filter
  bool _onlyStrong = false;
  double _strongThreshold = 0.60; // 60% default

  // pagination
  static const int _limit = 50;
  int _offset = 0;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true;

  // data
  final List<Map<String, dynamic>> _items = [];

  // scroll
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _offset = 0;
      _hasMore = true;
      _items.clear();
      _isLoading = true;
    });

    try {
      final data = await widget.service.getFixtures(
        leagueIds: widget.leagueIds,
        from: _from,
        to: _to,
        limit: _limit,
        offset: _offset,
        runType: _runType,
        status: _status,
      );

      setState(() {
        _items.addAll(data);
        _offset += data.length;
        _hasMore = data.length == _limit;
      });
    } catch (e) {
      _showSnack('Eroare load: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final data = await widget.service.getFixtures(
        leagueIds: widget.leagueIds,
        from: _from,
        to: _to,
        limit: _limit,
        offset: _offset,
        runType: _runType,
        status: _status,
      );

      setState(() {
        _items.addAll(data);
        _offset += data.length;
        _hasMore = data.length == _limit;
      });
    } catch (e) {
      _showSnack('Eroare load more: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _loadInitial();
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _leagueTitle(String leagueId) {
    return widget.leagueNamesById[leagueId] ?? leagueId;
  }

  // =========================
  // PRO: scoring + best pick
  // =========================

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

  bool _isStrong(Map<String, dynamic> it) {
    return _bestPick(it).p >= _strongThreshold;
  }

  String _fmtPct(dynamic v) {
    final n = _num(v);
    return '${(n * 100).toStringAsFixed(0)}%';
  }

  // =========================
  // Group by league
  // =========================
  Map<String, List<Map<String, dynamic>>> _groupByLeague(List<Map<String, dynamic>> list) {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final it in list) {
      final lid = (it['league_id'] ?? 'unknown').toString();
      out.putIfAbsent(lid, () => []);
      out[lid]!.add(it);
    }
    return out;
  }

  // =========================
  // Modal prediction
  // =========================
  void _openPrediction(BuildContext context, Map<String, dynamic> item) {
    final providerId = (item['provider_fixture_id'] ?? '').toString();
    if (providerId.isEmpty) return;

    final best = _bestPick(item);

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
                  return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return SizedBox(height: 220, child: Center(child: Text('Eroare: ${snap.error}')));
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
                        if (_isStrong(item)) _chip('STRONG', '≥ ${(_strongThreshold * 100).toStringAsFixed(0)}%'),
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
        );
      },
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

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    // ✅ apply strong filter BEFORE grouping
    final visible = _onlyStrong ? _items.where(_isStrong).toList() : _items;

    final grouped = _groupByLeague(visible);

    final leagueIds = grouped.keys.toList()
      ..sort((a, b) => _leagueTitle(a).compareTo(_leagueTitle(b)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          _FiltersBarPro(
            from: _from,
            to: _to,
            runType: _runType,
            status: _status,
            onlyStrong: _onlyStrong,
            threshold: _strongThreshold,
            onChanged: (vFrom, vTo, vRun, vStatus, vOnlyStrong, vThreshold) {
              setState(() {
                _from = vFrom;
                _to = vTo;
                _runType = vRun;
                _status = vStatus.trim().isEmpty ? null : vStatus.trim();
                _onlyStrong = vOnlyStrong;
                _strongThreshold = vThreshold;
              });
              _loadInitial();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _isLoading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : (leagueIds.isEmpty)
                      ? Center(
                          child: Text(
                            _onlyStrong
                                ? 'Nu există meciuri peste pragul ales.'
                                : 'Nu există meciuri pentru selecția curentă.',
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: leagueIds.length + 1,
                          itemBuilder: (context, idx) {
                            if (idx == leagueIds.length) {
                              if (_isLoading) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              if (!_hasMore) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(child: Text('End')),
                                );
                              }
                              return const SizedBox(height: 70);
                            }

                            final leagueId = leagueIds[idx];
                            final items = (grouped[leagueId] ?? []).toList();

                            // ✅ sort PRO în ligă
                            items.sort((a, b) => _sortScore(b).compareTo(_sortScore(a)));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _leagueTitle(leagueId),
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      Text('${items.length}'),
                                    ],
                                  ),
                                ),
                                ...items.map((it) {
                                  final home = (it['home'] ?? '').toString();
                                  final away = (it['away'] ?? '').toString();
                                  final status = (it['status'] ?? '').toString();
                                  final kickoff = (it['kickoff_at'] ?? it['kickoff'] ?? '').toString();

                                  final best = _bestPick(it);
                                  final strong = _isStrong(it);

                                  return InkWell(
                                    onTap: () => _openPrediction(context, it),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.white12)),
                                      ),
                                      color: strong ? Colors.white10 : null,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('$home vs $away',
                                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Status: $status • Kickoff: $kickoff',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('BEST ${best.label}',
                                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                                              Text(
                                                _fmtPct(best.p),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: strong ? Colors.greenAccent : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Filters Bar PRO: DatePicker + Presets + OnlyStrong + Threshold
// ------------------------------------------------------------
class _FiltersBarPro extends StatefulWidget {
  final String from;
  final String to;
  final String runType;
  final String? status;

  final bool onlyStrong;
  final double threshold;

  /// (from, to, runType, status, onlyStrong, threshold)
  final void Function(
    String from,
    String to,
    String runType,
    String status,
    bool onlyStrong,
    double threshold,
  ) onChanged;

  const _FiltersBarPro({
    required this.from,
    required this.to,
    required this.runType,
    required this.status,
    required this.onlyStrong,
    required this.threshold,
    required this.onChanged,
  });

  @override
  State<_FiltersBarPro> createState() => _FiltersBarProState();
}

class _FiltersBarProState extends State<_FiltersBarPro> {
  late DateTime _from;
  late DateTime _to;
  String _runType = 'initial';
  late final TextEditingController _statusCtrl;

  bool _onlyStrong = false;
  double _threshold = 0.60;

  @override
  void initState() {
    super.initState();
    _from = _parseDate(widget.from) ?? DateTime.now();
    _to = _parseDate(widget.to) ?? DateTime.now().add(const Duration(days: 7));
    _runType = widget.runType;
    _statusCtrl = TextEditingController(text: widget.status ?? '');
    _onlyStrong = widget.onlyStrong;
    _threshold = widget.threshold;
  }

  @override
  void dispose() {
    _statusCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String s) {
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  String _fmt(DateTime d) {
    String two(int x) => x < 10 ? '0$x' : '$x';
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.year, picked.month, picked.day);
      if (_to.isBefore(_from)) _to = _from;
    });
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _to = DateTime(picked.year, picked.month, picked.day);
      if (_to.isBefore(_from)) _from = _to;
    });
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      switch (preset) {
        case 'today':
          _from = today;
          _to = today;
          break;
        case 'next7':
          _from = today;
          _to = today.add(const Duration(days: 7));
          break;
        case 'next30':
          _from = today;
          _to = today.add(const Duration(days: 30));
          break;
        case 'month':
          _from = DateTime(today.year, today.month, 1);
          _to = DateTime(today.year, today.month + 1, 0);
          break;
      }
    });
  }

  void _submit() {
    widget.onChanged(
      _fmt(_from),
      _fmt(_to),
      _runType,
      _statusCtrl.text.trim(),
      _onlyStrong,
      _threshold,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          // Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton(onPressed: () => _applyPreset('today'), child: const Text('Today')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => _applyPreset('next7'), child: const Text('Next 7 days')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => _applyPreset('next30'), child: const Text('Next 30 days')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => _applyPreset('month'), child: const Text('This month')),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Date pickers
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFrom,
                  icon: const Icon(Icons.date_range),
                  label: Text('From: ${_fmt(_from)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.event),
                  label: Text('To: ${_fmt(_to)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // run_type + status
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _runType,
                  items: const [
                    DropdownMenuItem(value: 'initial', child: Text('run_type: initial')),
                    DropdownMenuItem(value: 'latest', child: Text('run_type: latest')),
                  ],
                  onChanged: (v) => setState(() => _runType = v ?? 'initial'),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _statusCtrl,
                  decoration: const InputDecoration(
                    labelText: 'status (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // strong toggle + threshold + load
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
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Load'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
