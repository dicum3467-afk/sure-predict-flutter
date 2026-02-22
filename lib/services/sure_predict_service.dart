import 'dart:convert';
import '../api/api_client.dart';

class SurePredictService {
  final ApiClient _api;
  SurePredictService(this._api);

  Future<List<Map<String, dynamic>>> getLeagues() async {
    final data = await _api.getJson('/leagues');
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> getFixtures({
    required String leagueId,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _api.getJson(
      '/fixtures',
      query: {
        'league_id': leagueId,
        'from': from,
        'to': to,
        'limit': limit,
        'offset': offset,
      },
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// IMPORTANT: întoarce Map (nu clasă Prediction)
  Future<Map<String, dynamic>> getPrediction({required String providerFixtureId}) async {
    final data = await _api.getJson('/fixtures/$providerFixtureId/prediction');
    if (data is Map) return Map<String, dynamic>.from(data);
    // uneori API poate întoarce string json
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }
}
