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
  Future<List<Map<String, dynamic>>> getLeagues() async {
    const key = 'leagues';
    final cached = _cache.get<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _api.getJson('/leagues');
    final list = List<Map<String, dynamic>>.from(data['items'] ?? data ?? []);
    _cache.put(key, list);
    return list;
  }

  // ---------------- FIXTURES ----------------
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
    return '$path?${_stableEncodeQuery(query)}';
  }

  Future<List<Map<String, dynamic>>> getFixtures({
    required Iterable<String> leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String status = 'all', // all/scheduled/live/finished
    bool force = false,
  }) async {
    final query = <String, dynamic>{
      'leagueIds': leagueIds.map((e) => e.toString()).toList(),
      'from': from,
      'to': to,
      'limit': limit,
      'offset': offset,
    };

    // IMPORTANT: backend-ul tău NU acceptă status=all.
    // Pentru "all", NU trimitem parametrul status deloc.
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
    final list = List<Map<String, dynamic>>.from(data['items'] ?? data ?? []);
    _cache.put(key, list);
    return list;
  }

  // ---------------- PREDICTION ----------------
  Future<Map<String, dynamic>> getPrediction({required String providerFixtureId}) async {
    final data = await _api.getJson(
      '/prediction',
      queryParameters: {'provider_fixture_id': providerFixtureId},
    );
    return Map<String, dynamic>.from(data ?? const {});
  }

  // ---------------- TOP PICKS ----------------
  Future<List<Map<String, dynamic>>> getTopPicks({
    required Iterable<String> leagueIds,
    required double threshold,
    bool topPerLeague = false,
    String status = 'all',
    bool force = false,
    int limit = 200,
  }) async {
    final query = <String, dynamic>{
      'leagueIds': leagueIds.map((e) => e.toString()).toList(),
      'threshold': threshold,
      'topPerLeague': topPerLeague,
      'limit': limit,
    };

    // La fel: pentru "all" NU trimitem status.
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
    final list = List<Map<String, dynamic>>.from(data['items'] ?? data ?? []);
    _cache.put(key, list);
    return list;
  }

  // ---------------- CACHE CONTROL ----------------
  Future<void> clearCache() async {
    await _cache.clearAll();
  }
}
