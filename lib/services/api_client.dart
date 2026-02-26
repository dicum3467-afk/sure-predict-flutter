import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Build URI with support for:
  /// - scalar query params
  /// - list query params (repeated key): k=v1&k=v2
  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse(baseUrl);

    // Ensure path joins correctly (avoid //)
    final cleanBasePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final cleanPath = path.startsWith('/') ? path : '/$path';

    final qp = <String, List<String>>{};

    if (query != null && query.isNotEmpty) {
      for (final entry in query.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value == null) continue;

        // List/Iterable => repeat param
        if (value is Iterable) {
          for (final item in value) {
            if (item == null) continue;
            final s = item.toString().trim();
            if (s.isEmpty) continue;
            qp.putIfAbsent(key, () => <String>[]).add(s);
          }
          continue;
        }

        // Normal scalar
        final s = value.toString().trim();
        if (s.isEmpty) continue;
        qp.putIfAbsent(key, () => <String>[]).add(s);
      }
    }

    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '$cleanBasePath$cleanPath',
      queryParametersAll: qp.isEmpty ? null : qp,
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);

    final res = await _http.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    // Dacă serverul întoarce listă, o împachetăm ca {'data': ...}
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }
}
