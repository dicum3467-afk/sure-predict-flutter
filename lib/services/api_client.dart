import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client HTTP simplu pentru backend-ul tău.
/// - suportă query params normale
/// - suportă liste ca parametru repetat: league_ids=a&league_ids=b
/// - aruncă Exception pentru non-2xx
class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final normalizedPath = path.startsWith('/') ? path : '/$path';

    final uri = Uri.parse('$normalizedBase$normalizedPath');

    if (query == null || query.isEmpty) return uri;

    final qpAll = <String, List<String>>{};

    void addOne(String key, String value) {
      qpAll.putIfAbsent(key, () => <String>[]).add(value);
    }

    query.forEach((key, value) {
      if (value == null) return;

      // liste: league_ids=[a,b] => league_ids=a&league_ids=b
      if (value is Iterable) {
        for (final v in value) {
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isEmpty) continue;
          addOne(key, s);
        }
        return;
      }

      // simplu
      final s = value.toString().trim();
      if (s.isEmpty) return;
      addOne(key, s);
    });

    if (qpAll.isEmpty) return uri;
    return uri.replace(queryParametersAll: qpAll);
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);

    final res = await _http.get(
      uri,
      headers: <String, String>{
        'accept': 'application/json',
        ...?headers,
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  void close() => _http.close();
}
