import 'dart:convert';
import '../core/cache/simple_cache.dart';
import 'api_client.dart';

class SurePredictService {
  final ApiClient _api;

  // cache general (15 minute)
  final SimpleCache _cache = SimpleCache(ttl: const Duration(minutes: 15));

  SurePredictService(this._api);

  Future<void> health() async {
    await _api.getJson('/health');
  }

  // ---------------- LEAGUES ----------------
  Future<List<Map<String, dynamic>>> getLeagues({bool active = true}) async {
    const key = 'leagues';
    final cached = _cache.get<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _api.getJson('/leagues', queryParameters: {
      'active': active.toString(), // backend primește bool; string merge ok
    });

    final list = (data is List) ? data : <dynamic>[];
    final out = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));

    _cache.put(key, out);
    return out;
  }

  // ---------------- FIXTURES ----------------
  Future<List<Map<String, dynamic>>> getFixtures({
    required Iterable<String> leagueIds,
    String? dateFrom, // ISO string, ex: "2026-02-24" sau "2026-02-24T00:00:00Z"
    String? dateTo,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String status = 'all', // all/scheduled/live/finished
    bool force = false,
  }) async {
    // backend-ul tău folosește: league_ids, date_from, date_to, run_type, status, limit, offset
    final query = <String, dynamic>{
      'league_ids': leagueIds.toList(),
      'run_type': runType,
      'limit': limit,
      'offset': offset,
    };

    if (dateFrom != null && dateFrom.trim().isNotEmpty) query['date_from'] = dateFrom.trim();
    if (dateTo != null && dateTo.trim().isNotEmpty) query['date_to'] = dateTo.trim();

    final s = status.trim().toLowerCase();
    if (s.isNotEmpty && s != 'all') {
      query['status'] = s;
    }

    final cacheKey = 'fixtures:${jsonEncode(query)}';
    if (!force) {
      final cached = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) return cached;
    }

    final data = await _api.getJson('/fixtures', queryParameters: query);

    final list = (data is List) ? data : <dynamic>[];
    final out = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));

    _cache.put(cacheKey, out);
    return out;
  }

  // ---------------- PREDICTION ----------------
  Future<Map<String, dynamic>> getPrediction({required String providerFixtureId}) async {
    final data = await _api.getJson('/fixtures/$providerFixtureId/prediction');
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // cache control
  Future<void> clearCache() async {
    await _cache.clearAll();
  }
}
