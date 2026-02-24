import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  /// 🔥 construiește query corect (repeat params pentru liste)
  Uri _buildUri(String path, Map<String, dynamic>? query) {
  final uri = Uri.parse('$baseUrl$path');

  if (query == null || query.isEmpty) {
    return uri;
  }

  final params = <String, String>{};
  final extra = <String>[];

  query.forEach((key, value) {
    if (value == null) return;

    if (value is List) {
      // ✅ repeat param
      for (final v in value) {
        extra.add(
          '${Uri.encodeQueryComponent(key)}='
          '${Uri.encodeQueryComponent(v.toString())}',
        );
      }
    } else {
      params[key] = value.toString();
    }
  });

  final base = uri.replace(queryParameters: params).toString();

  if (extra.isEmpty) return Uri.parse(base);

  return Uri.parse('$base&${extra.join('&')}');
  }
