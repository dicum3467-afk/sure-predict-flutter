import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class ApiService {
  static const String baseUrl = 'https://sure-predict-backend.onrender.com';

  Future<List<FixtureUiModel>> fetchFixtures({
    int page = 1,
    int perPage = 10,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/predictions?limit=$perPage',
    );

    final res = await http.get(
      uri,
      headers: {'accept': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Eroare fixtures: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);

    final items = (data['items'] as List?) ?? [];
    return items
        .map((e) => FixtureUiModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<FixtureUiModel>> fetchTodayPredictions({
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/predictions/today?limit=$limit',
    );

    final res = await http.get(
      uri,
      headers: {'accept': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Eroare predictions/today: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    final items = (data['items'] as List?) ?? [];

    return items
        .map((e) => FixtureUiModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<FixtureUiModel>> fetchTopPredictions({
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/predictions/top?limit=$limit',
    );

    final res = await http.get(
      uri,
      headers: {'accept': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Eroare predictions/top: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    final items = (data['items'] as List?) ?? [];

    return items
        .map((e) => FixtureUiModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<FixtureUiModel?> fetchPredictionByFixtureId(String fixtureId) async {
    final uri = Uri.parse('$baseUrl/predictions/by-fixture/$fixtureId');

    final res = await http.get(
      uri,
      headers: {'accept': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Eroare predictions/by-fixture: ${res.statusCode} ${res.body}',
      );
    }

    final data = jsonDecode(res.body);
    final item = data['item'];

    if (item == null) return null;

    return FixtureUiModel.fromJson(Map<String, dynamic>.from(item));
  }

  Future<List<TopPickUiModel>> getTopPicks({
    int limit = 10,
    int daysAhead = 2,
    double minEv = 0.03,
    double minEdge = 0.03,
    String modelVersion = 'engine_pro_pp',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/value/top'
      '?days_ahead=$daysAhead'
      '&min_ev=$minEv'
      '&min_edge=$minEdge'
      '&limit=$limit'
      '&model_version=$modelVersion',
    );

    final res = await http.get(
      uri,
      headers: {'accept': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Eroare value/top: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    final items = (data['items'] as List?) ?? [];

    return items
        .map((e) => TopPickUiModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
