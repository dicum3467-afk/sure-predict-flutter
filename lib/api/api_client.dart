import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;

  const ApiClient({required this.baseUrl});

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters:
          query?.map((k, v) => MapEntry(k, v.toString())),
    );

    final res = await http.get(uri);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
