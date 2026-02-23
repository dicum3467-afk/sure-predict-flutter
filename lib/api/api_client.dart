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
            .replaceAll(RegExp(r'/*$'), '') {
    // warm up Render (cold start)
    getJson('/health').catchError((_) {});
  }

  final http.Client _client;
  final String baseUrl;

  /// Construieste query string cu suport pt. liste:
  /// { league_ids: [a,b], limit: 50 } -> league_ids=a&league_ids=b&limit=50
  String _encodeQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return '';

    final parts = <String>[];

    void addPair(String k, String v) {
      if (k.trim().isEmpty) return;
      if (v.trim().isEmpty) return;
      parts.add('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}');
    }

    for (final entry in query.entries) {
      final k = entry.key;
      final v = entry.value;
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

    return parts.join('&');
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse('$baseUrl$path');
    final q = _encodeQuery(query);

    // reconstruim uri (fara queryParametersAll)
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
      query: q.isEmpty ? null : q,
      fragment: base.fragment.isEmpty ? null : base.fragment,
    );
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

        if (res.bodyBytes.isEmpty) return null;

        final body = utf8.decode(res.bodyBytes);
        return jsonDecode(body);
      } on TimeoutException catch (e) {
        lastError = ApiException('Timeout: ${e.message ?? ''}');
      } on SocketException catch (e) {
        lastError = ApiException('No internet / DNS error: ${e.message}');
      } on HttpException catch (e) {
        lastError = ApiException('HTTP error: ${e.message}');
      } on FormatException {
        lastError = ApiException('Invalid JSON response');
      } on ApiException catch (e) {
        // 4xx/5xx: nu are rost retry in general (dar tu poti decide)
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
