import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({
    this.baseUrl = 'https://sure-predict-backend.onrender.com',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  // =========================
  // GET JSON CU RETRY + TIMEOUT
  // =========================
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 15),
    Duration? cacheTtl, // ✅ IMPORTANT (fix)
  }) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);

    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await _http.get(uri).timeout(timeout);

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          return jsonDecode(resp.body);
        }

        throw ApiException(resp.statusCode, resp.body);
      } on SocketException catch (e) {
        if (attempt == maxAttempts) {
          throw ApiException(null, 'No internet / DNS error: $e');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } on HttpException catch (e) {
        if (attempt == maxAttempts) {
          throw ApiException(null, 'HTTP error: $e');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } on FormatException catch (e) {
        throw ApiException(null, 'Bad response format: $e');
      } on Exception catch (_) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw ApiException(null, 'Unknown error');
  }
}
