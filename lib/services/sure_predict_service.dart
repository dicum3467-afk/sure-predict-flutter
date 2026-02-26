import 'dart:convert';

import '../services/api_client.dart';
import '../core/cache/simple_cache.dart';

class SurePredictService {
  final ApiClient _api;

  // Cache general (15 minute)
  final SimpleCache _cache = SimpleCache(ttl: const Duration(minutes: 15));

  SurePredictService(this._api);

  Future<void> health() async {
    await _api.getJson('/health');
  }

  // ---------------- LEAGUES ----------------
  Future<List<Map<String, dynamic>>> getLeagues({bool active = true, bool force = false}) async {
    final key = 'leagues?active=$active';
    if (!force) {
      final cached = _cache.get<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
    }

    final data = await _api.getJson(
      '/leagues',
      queryParameters: {'active': active},
    );

    // backend-ul tău pare să returneze listă direct
    final list = (data is List)
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    _cache.put(key, list);
    return list;
  }

  // ---------------- FIXTURES ----------------
  String _stableEncodeQuery(Map<String, dynamic> query) {
    // sortăm cheile + sortăm listele ca să avem cheie de cache stabilă
    final keys = query.keys.toList()..sort();
    final out = <String, dynamic>{};

    for (final k in keys) {
      final v = query[k];
      if (v is Iterable) {
        final l = v.map((e) => e.toString()).toList()..sort();
        out[k] = l;
      } else {
        out[k] = v;
      }
    }
    return jsonEncode(out);
  }

  String _cacheKey(String path, Map<String, dynamic> query) {
    if (query.isEmpty) return path;
    return '$path?${_stableEncodeQuery(query)}';
  }

  Future<List<Map<String, dynamic>>> getFixtures({
    required Iterable<String> leagueIds,
    String? dateFrom, // ISO: "2026-02-24" sau "2026-02-24T00:00:00Z"
    String? dateTo,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String status = 'all', // all/scheduled/live/finished
    bool force = false,
  }) async {
    final query = <String, dynamic>{
      // IMPORTANT: snake_case pentru backend:
      'league_ids': leagueIds.map((e) => e.toString()).toList(),
      'run_type': runType,
      'limit': limit,
      'offset': offset,
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    };

    final s = status.trim().toLowerCase();
    // IMPORTANT: pentru "all" NU trimitem status deloc
    if (s.isNotEmpty && s != 'all') {
      query['status'] = s;
    }

    final key = _cacheKey('/fixtures', query);

    if (!force) {
      final cached = _cache.get<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
    }

    final data = await _api.getJson('/fixtures', queryParameters: query);

    final list = (data is List)
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    _cache.put(key, list);
    return list;
  }

  // ---------------- PREDICTION ----------------
  Future<Map<String, dynamic>> getPrediction({required String providerFixtureId}) async {
    final data = await _api.getJson('/fixtures/$providerFixtureId/prediction');
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ---------------- TOP PICKS ----------------
  Future<List<Map<String, dynamic>>> getTopPicks({
    required Iterable<String> leagueIds,
    required double threshold,
    bool topPerLeague = false,
    String status = 'all',
    int limit = 200,
    bool force = false,
  }) async {
    final query = <String, dynamic>{
      'league_ids': leagueIds.map((e) => e.toString()).toList(),
      'threshold': threshold,
      'topPerLeague': topPerLeague,
      'limit': limit,
    };

    final s = status.trim().toLowerCase();
    if (s.isNotEmpty && s != 'all') {
      query['status'] = s;
    }

    final key = _cacheKey('/top-picks', query);

    if (!force) {
      final cached = _cache.get<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
    }

    final data = await _api.getJson('/top-picks', queryParameters: query);

    final list = (data is List)
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    _cache.put(key, list);
    return list;
  }

  // Cache control
  Future<void> clearCache() async {
    _cache.clearAll();
  }
}
