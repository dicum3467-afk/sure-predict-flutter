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
            .replaceAll(RegExp(r'/+$'), '') {
    // 🔥 wake up Render server
    getJson('/health').catchError((_) {});
  }

  final http.Client _client;
  final String baseUrl;

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

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 25), // ✅ IMPORTANT
    int retries = 5,
    Duration retryDelay = const Duration(seconds: 3),
  }) async {
    final uri = _uri(path, query);

    Object? lastError;

    for (int attempt = 1; attempt <= retries + 1; attempt++) {
      try {
        final res = await _client
            .get(
              uri,
              headers: {
                'accept': 'application/json',
                if (headers != null) ...headers,
              },
            )
            .timeout(timeout);

        if (res.statusCode < 200 || res.statusCode >= 300) {
          String msg = 'HTTP ${res.statusCode}';
          try {
            final decoded = jsonDecode(res.body);
            if (decoded is Map && decoded['detail'] != null) {
              msg = decoded['detail'].toString();
            }
          } catch (_) {}
          throw ApiException(msg, statusCode: res.statusCode);
        }

        if (res.body.isEmpty) return null;
        return jsonDecode(utf8.decode(res.bodyBytes));
      } on TimeoutException catch (e) {
        lastError = ApiException('Timeout: ${e.message ?? ''}');
      } on SocketException catch (e) {
        lastError = ApiException('No internet / DNS error: ${e.message}');
      } on HttpException catch (e) {
        lastError = ApiException('HTTP error: ${e.message}');
      } on FormatException {
        lastError = ApiException('Invalid JSON response');
      } on ApiException catch (e) {
        rethrow;
      } catch (e) {
        lastError = ApiException('Unknown error: $e');
      }

      if (attempt <= retries) {
        await Future.delayed(retryDelay * attempt);
        continue;
      }

      throw lastError!;
    }

    throw ApiException('Unexpected state');
  }

  void dispose() {
    _client.close();
  }
}
