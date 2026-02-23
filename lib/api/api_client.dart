import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? 'https://sure-predict-backend.onrender.com')
            .trim()
            .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String baseUrl;

  /// Construiește URI și suportă "repeat param" pentru liste:
  /// ex: league_ids=a&league_ids=b
  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$baseUrl$p');

    if (query == null || query.isEmpty) return base;

    final parts = <String>[];

    void addPair(String k, String v) {
      final kk = Uri.encodeQueryComponent(k);
      final vv = Uri.encodeQueryComponent(v);
      parts.add('$kk=$vv');
    }

    for (final e in query.entries) {
      final k = e.key;
      final v = e.value;

      if (v == null) continue;

      if (v is List) {
        for (final item in v) {
          if (item == null) continue;
          final s = item.toString().trim();
          if (s.isEmpty) continue;
          addPair(k, s);
        }
        continue;
      }

      final s = v.toString().trim();
      if (s.isEmpty) continue;
      addPair(k, s);
    }

    if (parts.isEmpty) return base;
    final qs = parts.join('&');
    return Uri.parse('${base.toString()}?$qs');
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
        // pentru 4xx/5xx nu are rost retry (poți schimba dacă vrei)
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
