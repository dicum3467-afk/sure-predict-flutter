import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../cache/local_cache.dart';

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
            .replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String baseUrl;

  static const _timeout = Duration(seconds: 12);
  static const _maxRetries = 3;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};

    if (query != null) {
      for (final e in query.entries) {
        final v = e.value;
        if (v == null) continue;
        if (v is List) continue; // listele le tratezi separat în service
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        q[e.key] = s;
      }
    }

    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  /// GET JSON cu:
  /// - timeout
  /// - retry + backoff
  /// - cache local (save pe succes; fallback pe eroare)
  ///
  /// cacheKey: dacă nu e dat, se folosește uri.toString()
  /// cacheTtl: cât timp e "fresh"
  /// cacheFallbackOnError: dacă pică netul, returnează cache-ul (stale ok)
  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? cacheKey,
    Duration? cacheTtl,
    bool cacheFallbackOnError = true,
    bool cacheFirst = false,
  }) async {
    final uri = _uri(path, query);
    final key = cacheKey ?? uri.toString();

    // 1) Cache-first (pentru ecrane ca Leagues: apare instant)
    if (cacheFirst && cacheTtl != null) {
      final cached = await LocalCache.getJson(key, ttl: cacheTtl);
      if (cached != null) return cached;
    }

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

        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.isEmpty) return null;

          final decoded = jsonDecode(utf8.decode(res.bodyBytes));

          // 2) Cache pe succes
          if (cacheTtl != null) {
            await LocalCache.setJson(key, decoded);
          }

          return decoded;
        }

        // HTTP error
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
      } on SocketException catch (e) {
        lastError = ApiException(
          'Network error (attempt $attempt/$_maxRetries): ${e.message}',
        );
      } on TimeoutException catch (_) {
        lastError = ApiException(
          'Server slow (attempt $attempt/$_maxRetries)',
        );
      } on FormatException {
        throw ApiException('Invalid JSON response');
      } on ApiException catch (e) {
        // pentru 4xx, nu prea are sens retry
        if (e.statusCode != null &&
            e.statusCode! >= 400 &&
            e.statusCode! < 500) {
          rethrow;
        }
        lastError = e;
      } catch (e) {
        lastError = e;
      }

      // backoff
      if (attempt < _maxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2)); // 2s,4s,6s
      }
    }

    // 3) Fallback la cache dacă e eroare (DNS / cold start / etc.)
    if (cacheFallbackOnError && cacheTtl != null) {
      final stale = await LocalCache.getJsonStale(key);
      if (stale != null) return stale;
    }

    throw lastError ??
        ApiException('Request failed after $_maxRetries attempts');
  }

  void dispose() {
    _client.close();
  }
}
