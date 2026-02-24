import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$baseUrl$p');

    if (query == null || query.isEmpty) return base;

    final qp = <String, String>{};
    for (final e in query.entries) {
      if (e.value == null) continue;
      qp[e.key] = e.value.toString();
    }

    return base.replace(queryParameters: qp);
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
  }) async {
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
      throw Exception(msg);
    }

    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  // --------- Endpoints backend ---------

  Future<Map<String, dynamic>> health() async {
    final data = await getJson('/health');
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getLeagues() async {
    final data = await getJson('/leagues');
    final list = (data as List).cast<dynamic>();
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> getFixtures({
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? leagueId,
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

  Future<Map<String, dynamic>> getPrediction(String providerFixtureId) async {
    final data = await getJson('/fixtures/$providerFixtureId/prediction');
    return (data as Map).cast<String, dynamic>();
  }

  void dispose() => _client.close();
}
