import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  // 🔥 CONFIG
  static const _timeout = Duration(seconds: 12);
  static const _maxRetries = 3;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};

    if (query != null) {
      for (final e in query.entries) {
        final v = e.value;
        if (v == null) continue;
        if (v is List) continue;
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        q[e.key] = s;
      }
    }

    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  /// 🚀 GET cu retry + exponential backoff
  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path, query);

    int attempt = 0;
    Object? lastError;

    while (attempt < _maxRetries) {
      attempt++;

      try {
        final res = await _client
            .get(
              uri,
              headers: {
                'accept': 'application/json',
                if (headers != null) ...headers,
              },
            )
            .timeout(_timeout);

        // ✅ HTTP OK
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.isEmpty) return null;
          return jsonDecode(utf8.decode(res.bodyBytes));
        }

        // ❌ HTTP error
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

      // 🌐 DNS / network
      on SocketException catch (e) {
        lastError = ApiException(
          'Network error (attempt $attempt/$_maxRetries): ${e.message}',
        );
      }

      // ⏱️ timeout
      on TimeoutException catch (_) {
        lastError = ApiException(
          'Server slow (attempt $attempt/$_maxRetries)',
        );
      }

      // ❌ HTTP exception
      on HttpException catch (e) {
        lastError = ApiException('HTTP error: ${e.message}');
        rethrow; // nu are sens retry
      }

      // ❌ JSON invalid
      on FormatException {
        throw ApiException('Invalid JSON response');
      }

      // 🔁 exponential backoff
      if (attempt < _maxRetries) {
        final delaySeconds = attempt * 2; // 2s, 4s, 6s
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    throw lastError ??
        ApiException('Request failed after $_maxRetries attempts');
  }

  void dispose() {
    _client.close();
  }
}
