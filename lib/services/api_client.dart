import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // 🔥 pune aici URL-ul tău de Render (fără slash la final)
  static const String baseUrl = 'https://sure-predict-backend.onrender.com';

  static final http.Client _client = http.Client();

  static String _encodeQuery(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return '';
    final params = <String, String>{};
    for (final e in query.entries) {
      if (e.value == null) continue;
      params[e.key] = e.value.toString();
    }
    return Uri(queryParameters: params).query;
  }

  static Uri _uri(String path, Map<String, dynamic>? query) {
    // acceptă path cu sau fără "/"
    final p = path.startsWith('/') ? path : '/$path';

    final base = Uri.parse('$baseUrl$p');
    final q = _encodeQuery(query);

    // reconstruim uri (fără queryParametersAll)
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

  static Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
    int retries = 2,
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
          throw Exception(msg);
        }

        if (res.body.isEmpty) return null;
        return jsonDecode(res.body);
      } catch (e) {
        lastError = e;
        if (attempt <= retries) {
          await Future.delayed(retryDelay);
          continue;
        }
        rethrow;
      }
    }

    throw Exception(lastError?.toString() ?? 'Unknown error');
  }

  // ---------------------------
  // ✅ Endpoints specifice app
  // ---------------------------

  static Future<Map<String, dynamic>> health() async {
    final data = await getJson('/health');
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getLeagues() async {
    final data = await getJson('/leagues');
    final list = (data as List).cast<dynamic>();
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<List<Map<String, dynamic>>> getFixtures({
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? leagueId, // dacă vrei filtrare pe liga (UUID intern)
  }) async {
    final data = await getJson(
      '/fixtures',
      query: {
        'run_type': runType,
        'limit': limit,
        'offset': offset,
        if (leagueId != null) 'league_id': leagueId,
      },
    );

    final list = (data as List).cast<dynamic>();
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> getPrediction(String providerFixtureId) async {
    final data = await getJson('/fixtures/$providerFixtureId/prediction');
    return (data as Map).cast<String, dynamic>();
  }

  static void dispose() {
    _client.close();
  }
}
