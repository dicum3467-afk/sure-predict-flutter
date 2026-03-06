import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionsService {
  static const baseUrl =
      "https://sure-predict-backend.onrender.com";

  static Future<List<dynamic>> fetchPredictions() async {
    final response = await http.get(
      Uri.parse("$baseUrl/predictions?limit=50"),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["items"];
    } else {
      throw Exception("Failed to load predictions");
    }
  }
}
