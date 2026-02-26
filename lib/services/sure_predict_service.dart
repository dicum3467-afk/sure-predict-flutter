import 'dart:convert';

import '../core/cache/simple_cache.dart';
import 'api_client.dart';

class SurePredictService {
  final ApiClient _api;

  // Cache general (15 minute)
  final SimpleCache _cache = SimpleCache(ttl: const Duration(minutes: 15));

  SurePredictService(this._api);

  Future<void> health() async {
    await _api.getJson('/health');
  }

  // -------- LEAGUES --------
  Future<List<Map<String, dynamic>>> getLeagues({bool force = false}) async {
    const key = 'leagues';

    if (!force) {
      final cached = _cache.get<List<Map<String, dynamic>>>(key);
      if (cached != null) return cached;
    }

    final data = await _api.getJson('/leagues', queryParameters: {
      'active': 'true',
    });

    final list =
        List<Map<String, dynamic>>.from(data['items'] ?? data ?? []);

    _cache.put(key, list);
    return list;
  }

  // -------- helpers cache key --------
  String _stableEncodeQuery(Map<String, dynamic> query) {
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

  // -------- FIXTURES --------
  Future<List<Map<String, dynamic>>> getFixtures({
    Iterable<String>? leagueIds,
    int limit = 50,
    int offset = 0,
    String status = 'all',
    String runType = 'initial',
    bool force = false,
  }) async {
    final query = <String, dynamic>{
      'run_type': runType,
      'limit': limit,
      'offset': offset,
    };

    if (leagueIds != null && leagueIds.isNotEmpty) {
      query['league_ids'] = leagueIds.map((e) => e.toString()).toList();
    }

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

    final list =
        List<Map<String, dynamic>>.from(data['items'] ?? data ?? []);

    _cache.put(key, list);
    return list;
  }

  // -------- PREDICTION --------
  Future<Map<String, dynamic>> getPrediction({
    required String providerFixtureId,
  }) async {
    final data = await _api.getJson(
      '/fixtures/$providerFixtureId/prediction',
    );
    return Map<String, dynamic>.from(data['prediction'] ?? data ?? const {});
  }

  // -------- TOP PICKS --------
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

    final list =
        List<Map<String, dynamic>>.from(data['items'] ?? data ?? []);

    _cache.put(key, list);
    return list;
  }

  Future<void> clearCache() async {
    await _cache.clearAll();
  }
}
