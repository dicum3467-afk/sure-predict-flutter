import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

/// Cache local simplu (SharedPreferences) pentru GET.
/// - salvează body + timestamp
/// - TTL: 10 minute (poți schimba)
class _SimpleHttpCache {
  _SimpleHttpCache(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'http_cache_v1::';

  String _key(String url) => '$_prefix$url';
  String _tsKey(String url) => '${_key(url)}::ts';

  Future<void> put(String url, String body) async {
    await _prefs.setString(_key(url), body);
    await _prefs.setInt(_tsKey(url), DateTime.now().millisecondsSinceEpoch);
  }

  String? getIfFresh(String url, {Duration ttl = const Duration(minutes: 10)}) {
    final ts = _prefs.getInt(_tsKey(url));
    final body = _prefs.getString(_key(url));
    if (ts == null || body == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > ttl.inMilliseconds) return null;

    return body;
  }

  String? getAny(String url) => _prefs.getString(_key(url));
}

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    Duration? timeout,
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 600),
    Duration cacheTtl = const Duration(minutes: 10),
    bool enableCache = true,
  })  : _client = client ?? http.Client(),
        baseUri = (baseUrl ?? 'https://sure-predict-backend.onrender.com')
            .trim()
            .replaceAll(RegExp(r'\/$'), ''),
        _timeout = timeout ?? const Duration(seconds: 12),
        _maxRetries = maxRetries,
        _baseDelay = baseDelay,
        _cacheTtl = cacheTtl,
        _enableCache = enableCache;

  final http.Client _client;
  final String baseUri;

  final Duration _timeout;
  final int _maxRetries;
  final Duration _baseDelay;

  final Duration _cacheTtl;
  final bool _enableCache;

  _SimpleHttpCache? _cache;

  Future<void> _ensureCache() async {
    if (!_enableCache) return;
    _cache ??= _SimpleHttpCache(await SharedPreferences.getInstance());
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};

    if (query != null) {
      for (final entry in query.entries) {
        final v = entry.value;
        if (v == null) continue;

        // NOTE: listele (repeat param) sunt construite în service.
        if (v is List) continue;

        final s = v.toString().trim();
        if (s.isEmpty) continue;

        q[entry.key] = s;
      }
    }

    return Uri.parse('$baseUri$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  bool _isRetriable(Object e) =>
      e is SocketException ||
      e is HttpException ||
      e is TimeoutException ||
      (e is ApiException && (e.statusCode == null || e.statusCode! >= 500));

  Duration _backoff(int attempt) {
    // attempt: 1..N
    final ms = _baseDelay.inMilliseconds * attempt * attempt; // 1x,4x,9x...
    return Duration(milliseconds: ms.clamp(300, 6000));
  }

  Future<http.Response> _getWithRetry(Uri uri, Map<String, String> headers) async {
    Object? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final res = await _client.get(uri, headers: headers).timeout(_timeout);
        return res;
      } catch (e) {
        lastError = e;

        if (attempt == _maxRetries || !_isRetriable(e)) {
          rethrow;
        }

        await Future.delayed(_backoff(attempt));
      }
    }

    // n-ar trebui să ajungă aici
    throw lastError ?? ApiException('Unknown network error');
  }

  dynamic _decodeJsonBody(String body) {
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    await _ensureCache();

    final uri = _uri(path, query);
    final url = uri.toString();

    final mergedHeaders = <String, String>{
      'accept': 'application/json',
      if (headers != null) ...headers,
    };

    // 1) dacă avem cache fresh, îl putem folosi când rețeaua e instabilă
    // (nu-l returnăm direct, doar îl păstrăm ca fallback)
    final cachedFresh = _enableCache ? _cache?.getIfFresh(url, ttl: _cacheTtl) : null;

    try {
      final res = await _getWithRetry(uri, mergedHeaders);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = 'HTTP ${res.statusCode}';
        try {
          final decoded = _decodeJsonBody(res.body);
          if (decoded is Map && decoded['detail'] != null) {
            msg = decoded['detail'].toString();
          } else if (res.body.trim().isNotEmpty) {
            msg = res.body.toString();
          }
        } catch (_) {
          if (res.body.trim().isNotEmpty) msg = res.body.toString();
        }
        throw ApiException(msg, statusCode: res.statusCode);
      }

      // salvează în cache
      if (_enableCache) {
        await _cache?.put(url, res.body);
      }

      return _decodeJsonBody(utf8.decode(res.bodyBytes));
    } on SocketException catch (e) {
      // DNS / no internet
      if (cachedFresh != null) return _decodeJsonBody(cachedFresh);

      final any = _enableCache ? _cache?.getAny(url) : null;
      if (any != null) {
        // dacă ești ok să arăți date vechi când nu e net:
        return _decodeJsonBody(any);
      }

      throw ApiException('No internet / DNS error: ${e.message}');
    } on TimeoutException catch (_) {
      if (cachedFresh != null) return _decodeJsonBody(cachedFresh);
      throw ApiException('Request timeout after ${_timeout.inSeconds}s');
    } on HttpException catch (e) {
      if (cachedFresh != null) return _decodeJsonBody(cachedFresh);
      throw ApiException('HTTP error: ${e.message}');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (cachedFresh != null) return _decodeJsonBody(cachedFresh);
      throw ApiException('Unexpected error: $e');
    }
  }

  void dispose() => _client.close();
}
