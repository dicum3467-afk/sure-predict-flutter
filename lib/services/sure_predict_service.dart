import 'dart:convert';
import '../api/api_client.dart';

class SurePredictService {
  final ApiClient _api;
  SurePredictService(this._api);

  /// ✅ Warm-up / verificare backend
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

  /// ✅ FIX: trimite league_ids ca listă (repeat param)
  Future<List<Map<String, dynamic>>> getFixtures({
    required List<String> leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String runType = 'initial',
    String? status,
  }) async {
    final data = await _api.getJson(
      '/fixtures',
      query: {
        'league_ids': leagueId, //LIST, nu STRING
        'from': from,
        'to': to,
        'limit': limit,
        'offset': offset,
        'run_type': runType,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// IMPORTANT: întoarce Map (nu clasă Prediction)
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
