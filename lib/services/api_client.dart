import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final Duration timeout;
  final int maxRetries;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 3,
  });

  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final uri = Uri.parse('$baseUrl$path');

    if (query == null || query.isEmpty) return uri;

    final params = <String, String>{};
    final extra = <String>[];

    query.forEach((key, value) {
      if (value == null) return;

      if (value is List) {
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

    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final res = await http
            .get(
              uri,
              headers: const {'accept': 'application/json'},
            )
            .timeout(timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.isEmpty) return null;
          return jsonDecode(res.body);
        }

        // retry only on 429/5xx
        if (res.statusCode == 429 || res.statusCode >= 500) {
          throw Exception('HTTP ${res.statusCode}: ${res.body}');
        }

        // for 4xx (except 429) don't retry
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());

        // backoff: 300ms, 700ms, 1200ms...
        final delayMs = attempt == 1 ? 300 : (attempt == 2 ? 700 : 1200);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw lastError ?? Exception('Request failed');
  }
}
