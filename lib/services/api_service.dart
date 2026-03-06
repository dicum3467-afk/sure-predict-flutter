import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const baseUrl =
      "https://sure-predict-backend.onrender.com";

  static Future<List<dynamic>> getFixtures() async {

    final response =
        await http.get(Uri.parse("$baseUrl/fixtures"));

    if (response.statusCode == 200) {

      final data = json.decode(response.body);

      return data["items"];

    } else {
      throw Exception("API error");
    }
  }
}
