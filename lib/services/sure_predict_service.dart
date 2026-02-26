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
  Future<List<Map<String, dynamic>>> getLeagues({bool force = false}) async {
    const path = '/leagues';
    const key = 'leagues';

    if (!force) {
      final cached = _cache.get<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
    }

    final data = await _api.getJson(path);

    // Backend returnează listă direct: [...]
    final list = (data is List)
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    _cache.put(key, list);
    return list;
  }

  // ------------- helpers cache key -------------
  String _stableEncodeQuery(Map<String, dynamic> query) {
    final keys = query.keys.toList()..sort();
    final out = <String, dynamic>{};

    for (final k in keys) {
      final v = query[k];
      if (v is Iterable) {
        final list = v.map((e) => e.toString()).toList()..sort();
        out[k] = list;
      } else {
        out[k] = v;
      }
    }
    return jsonEncode(out);
  }

  String _cacheKey(String path, Map<String, dynamic> query) {
    if (query.isEmpty) return path;
    return '$path#${_stableEncodeQuery(query)}';
  }

  // ---------------- FIXTURES ----------------
  Future<List<Map<String, dynamic>>> getFixtures({
    List<String>? leagueIds,        // OPTIONAL
    String? dateFrom,               // ISO string optional (ex: 2026-02-24 or 2026-02-24T00:00:00Z)
    String? dateTo,                 // ISO string optional
    String runType = 'initial',
    int limit = 200,
    int offset = 0,
    String status = 'all',          // all/scheduled/live/finished
    bool force = false,
  }) async {
    final query = <String, dynamic>{
      'run_type': runType,
      'limit': limit,
      'offset': offset,
    };

    // league_ids (repeat param) doar dacă există
    if (leagueIds != null && leagueIds.isNotEmpty) {
      query['league_ids'] = leagueIds;
    }

    // date filters doar dacă sunt setate
    if (dateFrom != null && dateFrom.trim().isNotEmpty) {
      query['date_from'] = dateFrom.trim();
    }
    if (dateTo != null && dateTo.trim().isNotEmpty) {
      query['date_to'] = dateTo.trim();
    }

    // status: pentru 'all' nu trimitem deloc
    final s = status.trim().toLowerCase();
    if (s.isNotEmpty && s != 'all') {
      query['status'] = s;
    }

    final key = _cacheKey('/fixtures', query);
    if (!force) {
      final cached = _cache.get<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
    }

    final data = await _api.getJson('/fixtures', queryParameters: query);

    // Backend returnează listă direct: [...]
    final list = (data is List)
        ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    _cache.put(key, list);
    return list;
  }

  // ---------------- PREDICTION ----------------
  Future<Map<String, dynamic>> getPrediction(String providerFixtureId) async {
    // Backend: GET /fixtures/{provider_fixture_id}/prediction
    final data = await _api.getJson('/fixtures/$providerFixtureId/prediction');
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ---------------- TOP PICKS ----------------
  Future<List<Map<String, dynamic>>> getTopPicks({
    List<String>? leagueIds,     // OPTIONAL
    required double threshold,
    bool topPerLeague = false,
    String runType = 'initial',
    String status = 'all',
    int limit = 200,
    bool force = false,
  }) async {
    final query = <String, dynamic>{
      'threshold': threshold,
      'topPerLeague': topPerLeague,
      'limit': limit,
      'run_type': runType,
    };

    if (leagueIds != null && leagueIds.isNotEmpty) {
      query['league_ids'] = leagueIds;
    }

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

  // ---------------- CACHE CONTROL ----------------
  Future<void> clearCache() async {
    await _cache.clearAll();
  }
}
