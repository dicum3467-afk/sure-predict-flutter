import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen>
    with SingleTickerProviderStateMixin {
  static const String baseUrl = 'https://sure-predict-backend.onrender.com';

  late TabController _tabController;

  bool _loadingAll = false;
  bool _loadingToday = false;
  bool _loadingTop = false;

  String? _errorAll;
  String? _errorToday;
  String? _errorTop;

  List<dynamic> _allItems = [];
  List<dynamic> _todayItems = [];
  List<dynamic> _topItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
    _loadToday();
    _loadTop();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingAll = true;
      _errorAll = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/predictions?limit=50');
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body);
      setState(() {
        _allItems = (data['items'] as List?) ?? [];
      });
    } catch (e) {
      setState(() {
        _errorAll = e.toString();
      });
    } finally {
      setState(() {
        _loadingAll = false;
      });
    }
  }

  Future<void> _loadToday() async {
    setState(() {
      _loadingToday = true;
      _errorToday = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/predictions/today?limit=50');
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body);
      setState(() {
        _todayItems = (data['items'] as List?) ?? [];
      });
    } catch (e) {
      setState(() {
        _errorToday = e.toString();
      });
    } finally {
      setState(() {
        _loadingToday = false;
      });
    }
  }

  Future<void> _loadTop() async {
    setState(() {
      _loadingTop = true;
      _errorTop = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/predictions/top?limit=20');
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body);
      setState(() {
        _topItems = (data['items'] as List?) ?? [];
      });
    } catch (e) {
      setState(() {
        _errorTop = e.toString();
      });
    } finally {
      setState(() {
        _loadingTop = false;
      });
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dd.$mm.$yy  $hh:$min';
    } catch (_) {
      return iso;
    }
  }

  String _predictionText(Map<String, dynamic> item) {
    final model = item['model'];
    if (model is Map<String, dynamic>) {
      final topPick = model['top_pick'];
      if (topPick is Map<String, dynamic>) {
        final market = topPick['market']?.toString() ?? '';
        final pick = topPick['pick']?.toString() ?? '';
        if (market.isNotEmpty || pick.isNotEmpty) {
          return '$market $pick'.trim();
        }
      }

      final summary = model['summary']?.toString();
      if (summary != null && summary.isNotEmpty) return summary;
    }

    final prediction = item['prediction'];
    if (prediction is Map<String, dynamic>) {
      final summary = prediction['summary']?.toString();
      if (summary != null && summary.isNotEmpty) return summary;
    }

    return 'No prediction summary';
  }

  double? _confidenceValue(Map<String, dynamic> item) {
    final confidence = item['confidence'];
    if (confidence is num) return confidence.toDouble();

    final model = item['model'];
    if (model is Map<String, dynamic>) {
      final c = model['confidence'];
      if (c is num) return c.toDouble();
    }

    final prediction = item['prediction'];
    if (prediction is Map<String, dynamic>) {
      final c = prediction['confidence'];
      if (c is num) return c.toDouble();
    }

    return null;
  }

  Widget _buildPredictionCard(Map<String, dynamic> item) {
    final homeTeam = (item['home_team']?['name'] ?? item['fixture']?['home_team_name'] ?? 'Home').toString();
    final awayTeam = (item['away_team']?['name'] ?? item['fixture']?['away_team_name'] ?? 'Away').toString();

    final kickoffAt = item['kickoff_at']?.toString() ??
        item['fixture']?['kickoff_at']?.toString();

    final leagueName = item['league_name']?.toString() ??
        item['fixture']?['league_name']?.toString() ??
        '-';

    final confidence = _confidenceValue(item);
    final predictionText = _predictionText(item);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$homeTeam vs $awayTeam',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              leagueName,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(kickoffAt),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              predictionText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            if (confidence != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Confidence: ${confidence.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required bool loading,
    required String? error,
    required List<dynamic> items,
    required Future<void> Function() onReload,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A apărut o eroare',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onReload,
                child: const Text('Reîncarcă'),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onReload,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(
              child: Text(
                'Nu există date',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onReload,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final raw = items[index];
          if (raw is Map<String, dynamic>) {
            return _buildPredictionCard(raw);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predictions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Today'),
            Tab(text: 'Top'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(
            loading: _loadingAll,
            error: _errorAll,
            items: _allItems,
            onReload: _loadAll,
          ),
          _buildTabContent(
            loading: _loadingToday,
            error: _errorToday,
            items: _todayItems,
            onReload: _loadToday,
          ),
          _buildTabContent(
            loading: _loadingTop,
            error: _errorTop,
            items: _topItems,
            onReload: _loadTop,
          ),
        ],
      ),
    );
  }
}
