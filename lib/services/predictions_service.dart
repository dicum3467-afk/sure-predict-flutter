import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/prediction_model.dart';

class PredictionsService {
  static const String baseUrl = 'https://sure-predict-backend.onrender.com';

  Future<List<PredictionItem>> fetchPredictions({int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/predictions?limit=$limit');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Eroare API: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = PredictionResponse.fromJson(data);
    return parsed.items;
  }

  Future<PredictionItem> fetchPredictionByFixture(String fixtureId) async {
    final uri = Uri.parse('$baseUrl/predictions/by-fixture/$fixtureId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Eroare API: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PredictionItem.fromJson(data);
  }
}
