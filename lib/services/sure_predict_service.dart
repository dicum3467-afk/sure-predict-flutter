import 'dart:convert';
import 'api_client.dart';

class SurePredictService {
  final ApiClient _api;

  SurePredictService(this._api);

  // =======================
  // CACHE (in-memory)
  // =======================
  List<Map<String, dynamic>>? _leaguesCache;

  final Map<String, List<Map<String, dynamic>>> _fixturesCache = {};
  final Map<String, DateTime> _fixturesCacheTime = {};

  // cache ttl
  final Duration fixturesTtl = const Duration(minutes: 2);

  // =======================
  // LEAGUES
  // =======================
  Future<List<Map<String, dynamic>>> getLeagues({bool force = false}) async {
    if (!force && _leaguesCache != null) return _leaguesCache!;

    final data = await _api.getJson('/leagues');

    if (data is List) {
      _leaguesCache = data.map((e) => Map<String, dynamic>.from(e)).toList();
      return _leaguesCache!;
    }

    _leaguesCache = const [];
    return const [];
  }

  // =======================
  // FIXTURES (cached)
  // =======================
  String _fixturesKey({
    required List<String> leagueIds,
    required String from,
    required String to,
    required int limit,
    required int offset,
    required String runType,
    required String? status,
  }) {
    final sorted = [...leagueIds]..sort();
    return [
      'leagues=${sorted.join(",")}',
      'from=$from',
      'to=$to',
      'limit=$limit',
      'offset=$offset',
      'run=$runType',
      'status=${status ?? ""}',
    ].join('|');
  }

  Future<List<Map<String, dynamic>>> getFixtures({
    required List<String> leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String runType = 'initial',
    String? status,
    bool force = false,
  }) async {
    final key = _fixturesKey(
      leagueIds: leagueIds,
      from: from,
      to: to,
      limit: limit,
      offset: offset,
      runType: runType,
      status: status,
    );

    if (!force && _fixturesCache.containsKey(key)) {
      final t = _fixturesCacheTime[key];
      if (t != null && DateTime.now().difference(t) < fixturesTtl) {
        return _fixturesCache[key]!;
      }
    }

    final data = await _api.getJson(
      '/fixtures',
      query: {
        'league_ids': leagueIds,
        'date_from': from,
        'date_to': to,
        'limit': limit,
        'offset': offset,
        'run_type': runType,
        if (status != null && status.trim().isNotEmpty) 'status': status,
      },
    );

    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _fixturesCache[key] = list;
      _fixturesCacheTime[key] = DateTime.now();
      return list;
    }

    _fixturesCache[key] = const [];
    _fixturesCacheTime[key] = DateTime.now();
    return const [];
  }

  // =======================
  // PREDICTION
  // =======================
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
