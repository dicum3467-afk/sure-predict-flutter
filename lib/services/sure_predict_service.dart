import 'dart:convert';

import '../api/api_client.dart';
import '../core/cache/simple_cache.dart';

class SurePredictService {
  final ApiClient _api;

  // ✅ cache 15 min + SWR
  final SimpleCache _cache = const SimpleCache(ttl: Duration(minutes: 15));

  SurePredictService(this._api);

  Future<void> health() async {
    await _api.getJson('/health');
  }

  // ---------- cache key helpers ----------
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

  // ---------- leagues (SWR cached) ----------
  Future<List<Map<String, dynamic>>> getLeagues() async {
    final key = _cacheKey('/leagues', const {});

    final data = await _cache.getSWR<dynamic>(
      key: key,
      fetcher: () async => await _api.getJson('/leagues'),
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  // ---------- fixtures (SWR cached) ----------
  /// leagueIds: dacă e listă goală => ALL leagues (nu trimitem league_ids)
  Future<List<Map<String, dynamic>>> getFixtures({
    required List<String> leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String runType = 'initial',
    String? status,
  }) async {
    final query = <String, dynamic>{
      if (leagueIds.isNotEmpty) 'league_ids': leagueIds,
      'date_from': from,
      'date_to': to,
      'limit': limit,
      'offset': offset,
      'run_type': runType,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };

    final key = _cacheKey('/fixtures', query);

    final data = await _cache.getSWR<dynamic>(
      key: key,
      fetcher: () async => await _api.getJson('/fixtures', query: query),
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  // ---------- prediction (NU cache by default) ----------
  Future<Map<String, dynamic>> getPrediction({
    required String providerFixtureId,
  }) async {
    final data = await _api.getJson('/fixtures/$providerFixtureId/prediction');

    if (data is Map) return Map<String, dynamic>.from(data);

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
  }
}
