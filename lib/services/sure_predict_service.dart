import 'dart:convert';

import '../api/api_client.dart';

class SurePredictService {
  final ApiClient _api;

  SurePredictService(this._api);

  /// ✅ Warm-up / verificare backend
  Future<void> health() async {
    await _api.getJson('/health');
  }

  /// ✅ Lista ligilor (cu country / tier etc, dacă backend le returnează)
  Future<List<Map<String, dynamic>>> getLeagues() async {
    final data = await _api.getJson('/leagues');
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// ✅ Fixtures + ultimele predicții (run_type)
  /// leagueIds: dacă e listă goală => ia din TOATE ligile (nu trimitem league_ids)
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
      if (leagueIds.isNotEmpty) 'league_ids': leagueIds, // ✅ LIST (repeat params)
      'date_from': from,
      'date_to': to,
      'limit': limit,
      'offset': offset,
      'run_type': runType,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };

    final data = await _api.getJson('/fixtures', query: query);

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// ✅ Predicție pentru fixture (provider_fixture_id)
  Future<Map<String, dynamic>> getPrediction({
    required String providerFixtureId,
  }) async {
    final data = await _api.getJson('/fixtures/$providerFixtureId/prediction');

    // backend-ul tău poate returna Map sau uneori String JSON -> suportăm ambele
    if (data is Map) return Map<String, dynamic>.from(data);

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
  }
}
