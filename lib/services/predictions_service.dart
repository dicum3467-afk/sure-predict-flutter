import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/prediction_model.dart';

class PredictionsService {

  static const String baseUrl =
      'https://sure-predict-backend.onrender.com';

  Future<List<PredictionItem>> fetchPredictions({int limit = 50}) async {

    final uri = Uri.parse('$baseUrl/predictions?limit=$limit');

    try {

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      final parsed = PredictionResponse.fromJson(data);

      return parsed.items;

    } on TimeoutException {

      throw Exception("Serverul a răspuns prea lent");

    } catch (e) {

      throw Exception("Nu se poate conecta la server");

    }
  }

  Future<PredictionItem> fetchPredictionByFixture(String fixtureId) async {

    final uri = Uri.parse(
        '$baseUrl/predictions/by-fixture/$fixtureId');

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    return PredictionItem.fromJson(data);
  }
}
