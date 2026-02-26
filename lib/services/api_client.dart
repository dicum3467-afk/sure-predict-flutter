import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Construiește URL corect + query params
  /// - suportă listă => repeat param: league_ids=a&league_ids=b
  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    final url = '$base$p';

    if (query == null || query.isEmpty) {
      return Uri.parse(url);
    }

    final uri = Uri.parse(url);

    final pairs = <MapEntry<String, String>>[];

    query.forEach((key, value) {
      if (value == null) return;

      if (value is Iterable) {
        for (final v in value) {
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isEmpty) continue;
          pairs.add(MapEntry(key, s));
        }
      } else {
        final s = value.toString().trim();
        if (s.isEmpty) return;
        pairs.add(MapEntry(key, s));
      }
    });

    // reconstrucție query string cu repeat keys
    final q = pairs
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    return uri.replace(query: q);
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);

    final res = await _http.get(uri, headers: {
      'accept': 'application/json',
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    // dacă e gol
    if (res.body.trim().isEmpty) return null;

    final decoded = jsonDecode(res.body);
    return decoded;
  }
}
