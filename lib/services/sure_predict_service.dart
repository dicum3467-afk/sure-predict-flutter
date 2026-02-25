// lib/services/sure_predict_service.dart
import 'dart:convert';

import '../api/api_client.dart';
import '../core/cache/simple_cache.dart';

class CacheInfo {
  final int ageSeconds;
  final bool isFresh;

  const CacheInfo({required this.ageSeconds, required this.isFresh});
}

class SurePredictService {
  final ApiClient _api;

  // Cache global (15 min) pentru endpoints “grele”
  final SimpleCache _cache = const SimpleCache(ttl: Duration(minutes: 15));

  SurePredictService(this._api);

  Future<void> health() async {
    await _api.getJson('/health');
  }

  // --------------------------
  // Helpers cache key
  // --------------------------
  String _stableEncodeQuery(Map<String, dynamic> query) {
    final keys = query.keys.toList()..sort();
    final out = <String, dynamic>{};

    for (final k in keys) {
      final v = query[k];
      if (v is List) {
        final list = v.map((e) => e.toString()).toList()..sort();
        out[k] = list;
      } else {
        out[k] = v;
      }
    }
    return jsonEncode(out);
  }

  String _cacheKey(String path, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return path;
    return '$path?${_stableEncodeQuery(query)}';
  }

  // --------------------------
  // Cache info (pentru badge UI)
  // --------------------------
  Future<CacheInfo> fixturesCacheInfo({
    required List<String> leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String runType = 'initial',
  }) async {
    final query = <String, dynamic>{
      'league_ids': leagueIds,
      'from': from,
      'to': to,
      'limit': limit,
      'offset': offset,
      'run_type': runType,
    };

    final key = _cacheKey('/fixtures', query);
    final info = _cache.info(key);

    if (info == null) {
      return const CacheInfo(ageSeconds: 0, isFresh: false);
    }

    return CacheInfo(
      ageSeconds: info.ageSeconds,
      isFresh: info.isFresh,
    );
  }

  Future<void> clearCache() async {
    await _cache.clearAll();
  }

  // --------------------------
  // API calls
  // --------------------------

  Future<List<Map<String, dynamic>>> getLeagues() async {
    // leagues se schimbă rar -> cache OK
    final key = _cacheKey('/leagues', const {});
    final cached = _cache.get(key);
    if (cached != null) {
      return (cached as List).cast<Map<String, dynamic>>();
    }

    final data = await _api.getJson('/leagues');
    final list = (data as List).cast<Map<String, dynamic>>();
    _cache.put(key, list);
    return list;
  }

  Future<List<Map<String, dynamic>>> getFixtures({
    required List<String> leagueIds,
    required String from,
    required String to,
    int limit = 200,
    int offset = 0,
    String runType = 'initial',
    bool useCache = true,
  }) async {
    final query = <String, dynamic>{
      'league_ids': leagueIds,
      'from': from,
      'to': to,
      'limit': limit,
      'offset': offset,
      'run_type': runType,
    };

    final key = _cacheKey('/fixtures', query);

    if (useCache) {
      final cached = _cache.get(key);
      if (cached != null) {
        return (cached as List).cast<Map<String, dynamic>>();
      }
    }

    final data = await _api.getJson('/fixtures', query: query);
    final list = (data as List).cast<Map<String, dynamic>>();

    if (useCache) {
      _cache.put(key, list);
    }
    return list;
  }

  Future<Map<String, dynamic>> getPrediction({
    required String providerFixtureId,
  }) async {
    // prediction se poate schimba -> cache mic/optional.
    // Îl lăsăm fără cache ca să fie mereu fresh.
    final data = await _api.getJson(
      '/prediction',
      query: {'provider_fixture_id': providerFixtureId},
    );
    return (data as Map).cast<String, dynamic>();
  }
}
