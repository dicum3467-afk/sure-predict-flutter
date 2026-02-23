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
        baseUrl = (baseUrl ?? 'https://sure-predict-backend.onrender.com')
            .trim()
            .replaceAll(RegExp(r'/*$'), '') {
    // wake up Render server (cold start)
    getJson('/health').catchError((_) {});
  }

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    // Build a list of key/value pairs so we can support repeated params: k=a&k=b
    final pairs = <MapEntry<String, String>>[];

    if (query != null) {
      for (final entry in query.entries) {
        final k = entry.key;
        final v = entry.value;
        if (v == null) continue;

        if (v is List) {
          for (final x in v) {
            if (x == null) continue;
            final s = x.toString().trim();
            if (s.isEmpty) continue;
            pairs.add(MapEntry(k, s));
          }
          continue;
        }

        final s = v.toString().trim();
        if (s.isEmpty) continue;
        pairs.add(MapEntry(k, s));
      }
    }

    final base = Uri.parse('$baseUrl$path');

    if (pairs.isEmpty) return base;

    // Merge existing query (if any) + our pairs
    final all = <MapEntry<String, String>>[
      ...base.queryParameters.entries,
      ...pairs,
    ];

    // Build query string manually (supports repeated keys)
    final q = all
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    return base.replace(query: q);
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
    int retries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final uri = _uri(path, query);

    Object? lastError;

    for (int attempt = 1; attempt <= (retries + 1); attempt++) {
      try {
        final res = await _client
            .get(
              uri,
              headers: <String, String>{
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
      } on TimeoutException catch (e) {
        lastError = ApiException('Timeout: ${e.message ?? ''}');
      } on SocketException catch (e) {
        lastError = ApiException('No internet / DNS error: ${e.message}');
      } on HttpException catch (e) {
        lastError = ApiException('HTTP error: ${e.message}');
      } on FormatException {
        lastError = ApiException('Invalid JSON response');
      } on ApiException catch (e) {
        // 4xx/5xx - de obicei nu merită retry la 4xx
        lastError = e;
      } catch (e) {
        lastError = ApiException('Unknown error: $e');
      }

      if (attempt <= retries) {
        await Future.delayed(retryDelay * attempt);
        continue;
      }

      throw lastError ?? ApiException('Unexpected state');
    }

    throw ApiException('Unexpected state');
  }

  void dispose() {
    _client.close();
  }
}
