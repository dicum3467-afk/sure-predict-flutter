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

    final params = <String, String>{};
    final extra = <String>[];

    query.forEach((key, value) {
      if (value == null) return;

      if (value is List) {
        // ✅ repeat param pentru liste
        for (final v in value) {
          extra.add(
            '${Uri.encodeQueryComponent(key)}='
            '${Uri.encodeQueryComponent(v.toString())}',
          );
        }
      } else {
        params[key] = value.toString();
      }
    });

    final base = uri.replace(queryParameters: params).toString();

    if (extra.isEmpty) return Uri.parse(base);

    return Uri.parse('$base&${extra.join('&')}');
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final uri = _buildUri(path, query);

    final res = await http.get(
      uri,
      headers: const {
        'accept': 'application/json',
      },
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }

    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
