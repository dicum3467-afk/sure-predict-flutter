import 'dart:convert';
import './api/api_client.dart';

class SurePredictService {
  final ApiClient _api;
  SurePredictService(this._api);

  // ✅ Warm-up / verificare backend
  Future<void> health() async {
    await _api.getJson('/health');
  }

  Future<List<Map<String, dynamic>>> getLeagues() async {
    final data = await _api.getJson('/leagues');
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// ✅ ULTRA: leagueIds optional (dacă e gol => ALL leagues)
  Future<List<Map<String, dynamic>>> getFixtures({
    List<String>? leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String runType = 'initial',
    String? status,
  }) async {
    final query = <String, dynamic>{
      'from': from,
      'to': to,
      'limit': limit,
      'offset': offset,
      'run_type': runType,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };

    // ✅ doar dacă ai selectat ligi
    if (leagueIds != null && leagueIds.isNotEmpty) {
      query['league_ids'] = leagueIds; // LIST -> repeat param
    }

    final data = await _api.getJson('/fixtures', query: query);

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getPrediction({
    required String providerFixtureId,
  }) async {
    final data =
        await _api.getJson('/fixtures/$providerFixtureId/prediction');

    if (data is Map) return Map<String, dynamic>.from(data);

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
  }
}
