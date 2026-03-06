import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/match_analysis_models.dart';

class ApiService {
  static const String baseUrl = 'https://sure-predict-backend.onrender.com';

  Future<MatchPredictionResponse> getPredictionByFixture(int fixtureId) async {
    final uri = Uri.parse('$baseUrl/predictions/by-fixture/$fixtureId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Prediction request failed: ${response.statusCode}');
    }

    return MatchPredictionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ValuePicksResponse> getValueByFixture(int fixtureId) async {
    final uri = Uri.parse('$baseUrl/value/by-fixture/$fixtureId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Value picks request failed: ${response.statusCode}');
    }

    return ValuePicksResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
