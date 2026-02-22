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
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = _parseBase(
          baseUrl ?? 'https://sure-predict-backend.onrender.com',
        );

  final http.Client _client;
  final Uri _base;

  static Uri _parseBase(String baseUrl) {
    final s = baseUrl.trim().replaceAll(RegExp(r'/*$'), '');
    final uri = Uri.parse(s);

    if (uri.scheme.isEmpty || uri.host.isEmpty) {
      throw ArgumentError('Invalid baseUrl: "$baseUrl" (parsed: $uri)');
    }
    return uri;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    // Dacă cineva trimite URL complet
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final u = Uri.parse(path);
      if (u.host.isEmpty) {
        throw ApiException('Bad URL (host empty): $u');
      }
      return u.replace(queryParameters: _cleanQuery(query));
    }

    final cleanPath = path.startsWith('/') ? path : '/$path';

    return _base.replace(
      path: cleanPath,
      queryParameters: _cleanQuery(query),
    );
  }

  Map<String, String>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;

    final q = <String, String>{};

    for (final e in query.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is List) continue;

      final s = v.toString().trim();
      if (s.isEmpty) continue;

      q[e.key] = s;
    }

    return q.isEmpty ? null : q;
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, query);

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
    } on TimeoutException {
      throw ApiException('Timeout (server slow / sleeping)');
    } on SocketException catch (e) {
      throw ApiException('No internet / DNS error: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiException('ClientException: ${e.message}');
    } on FormatException {
      throw ApiException('Invalid JSON response');
    }
  }

  void dispose() => _client.close();
}
