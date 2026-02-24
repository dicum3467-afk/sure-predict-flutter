import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  /// 🔥 construiește query corect (repeat params pentru liste)
  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final uri = Uri.parse('$baseUrl$path');

    if (query == null || query.isEmpty) {
      return uri;
    }

    final qp = <String, List<String>>{};

    query.forEach((key, value) {
      if (value == null) return;

      // ✅ LISTĂ → repeat param
      if (value is List) {
        qp[key] = value.map((e) => e.toString()).toList();
      } else {
        qp[key] = [value.toString()];
      }
    });

    return uri.replace(queryParameters: {
      for (final e in qp.entries) e.key: e.value.join(',')
    });
  }

  /// 🔥 GET JSON
  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final uri = _buildUri(path, query);

    final res = await http.get(uri);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }

    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
