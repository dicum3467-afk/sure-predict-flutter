import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // IMPORTANT: fără slash la final
  static const String baseUrl = "https://sure-predict-backend.onrender.com";

  static Future<List<dynamic>> getFixtures({
    String runType = "initial",
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/fixtures?run_type=$runType&limit=$limit&offset=$offset",
    );

    final resp = await http.get(uri, headers: {
      "accept": "application/json",
    });

    if (resp.statusCode != 200) {
      throw Exception("Fixtures error: ${resp.statusCode} ${resp.body}");
    }

    return jsonDecode(resp.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getPrediction({
    required String providerFixtureId,
    String runType = "initial",
  }) async {
    final uri = Uri.parse(
      "$baseUrl/fixtures/$providerFixtureId/prediction?run_type=$runType",
    );

    final resp = await http.get(uri, headers: {
      "accept": "application/json",
    });

    if (resp.statusCode != 200) {
      throw Exception("Prediction error: ${resp.statusCode} ${resp.body}");
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
