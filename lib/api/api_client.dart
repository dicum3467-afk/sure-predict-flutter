import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = (baseUrl ??
                'https://sure-predict-backend.onrender.com')
            .trim()
            .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};

    if (query != null) {
      for (final e in query.entries) {
        final v = e.value;
        if (v == null) continue;
        if (v is List) continue; // listele se tratează în service
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        q[e.key] = s;
      }
    }

    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  /// 🔥 GET cu timeout + retry (pentru Render cold start)
  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path, query);

    int attempts = 0;
    const maxAttempts = 3;

    while (true) {
      attempts++;

      try {
        final res = await _client
            .get(
              uri,
              headers: {
                'accept': 'application/json',
                if (headers != null) ...headers,
              },
            )
            .timeout(const Duration(seconds: 25));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          String msg = 'HTTP ${res.statusCode}';
          try {
            final decoded = jsonDecode(res.body);
            if (decoded is Map && decoded['detail'] != null) {
              msg = decoded['detail'].toString();
            } else {
              msg = res.body.toString();
            }
          } catch (_) {
            msg = res.body.toString();
          }
          throw ApiException(msg, statusCode: res.statusCode);
        }

        if (res.body.isEmpty) return null;
        return jsonDecode(utf8.decode(res.bodyBytes));
      } on SocketException catch (e) {
        if (attempts >= maxAttempts) {
          throw ApiException('No internet / DNS error: ${e.message}');
        }
        await Future.delayed(const Duration(seconds: 2));
      } on TimeoutException {
        if (attempts >= maxAttempts) {
          throw ApiException('Request timeout');
        }
        await Future.delayed(const Duration(seconds: 2));
      } on http.ClientException catch (e) {
        if (attempts >= maxAttempts) {
          throw ApiException('HTTP client error: ${e.message}');
        }
        await Future.delayed(const Duration(seconds: 2));
      } on FormatException {
        throw ApiException('Invalid JSON response');
      }
    }
  }

  void dispose() {
    _client.close();
  }
}
