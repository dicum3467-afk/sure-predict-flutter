// lib/api/api_client.dart
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
    final qp = <String, String>{}; // simple query (k=v)
    final qpa = <String, List<String>>{}; // repeat params (k=a&k=b)

    if (query != null) {
      for (final e in query.entries) {
        final k = e.key;
        final v = e.value;

        if (v == null) continue;

        // List => repeat param
        if (v is List) {
          final list = v
              .where((x) => x != null)
              .map((x) => x.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();

          if (list.isNotEmpty) {
            qpa[k] = list;
          }
          continue;
        }

        final s = v.toString().trim();
        if (s.isEmpty) continue;
        qp[k] = s;
      }
    }

    final u = Uri.parse('$baseUrl$path');

    // Build query manually to support repeat params
    final parts = <String>[];

    qp.forEach((k, v) {
      parts.add(
        '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}',
      );
    });

    qpa.forEach((k, list) {
      for (final v in list) {
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        parts.add(
          '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(s)}',
        );
      }
    });

    return u.replace(query: parts.isEmpty ? null : parts.join('&'));
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
    int retries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    Object? lastError;

    for (int attempt = 1; attempt <= retries + 1; attempt++) {
      try {
        final uri = _uri(path, query);

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
```0
