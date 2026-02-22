import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? 'https://sure-predict-backend.onrender.com')
            .replaceAll(RegExp(r'\/+$'), ''); // taie "/" la final

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');
    return query == null ? uri : uri.replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
  }

  Future<Map<String, dynamic>> getJsonMap(String path, {Map<String, dynamic>? query}) async {
    final res = await _client.get(
      _uri(path, query),
      headers: {'Accept': 'application/json'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;

    throw ApiException(res.statusCode, 'Expected JSON object but got: ${decoded.runtimeType}');
  }

  Future<List<dynamic>> getJsonList(String path, {Map<String, dynamic>? query}) async {
    final res = await _client.get(
      _uri(path, query),
      headers: {'Accept': 'application/json'},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.body);
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;

    throw ApiException(res.statusCode, 'Expected JSON list but got: ${decoded.runtimeType}');
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
