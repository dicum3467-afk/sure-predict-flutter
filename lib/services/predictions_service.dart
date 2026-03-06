import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionsService {
  static const String baseUrl =
      "https://sure-predict-backend.onrender.com";

  static Future<List<dynamic>> fetchPredictions() async {
    final response = await http.get(
      Uri.parse("$baseUrl/predictions?limit=50"),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data["items"] as List<dynamic>? ?? []);
    } else {
      throw Exception(
        "Failed to load predictions: ${response.statusCode}",
      );
    }
  }
}
