import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResult<T> {
  final bool isOk;
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResult.ok(this.data, {this.statusCode})
      : isOk = true,
        error = null;

  const ApiResult.err(this.error, {this.statusCode})
      : isOk = false,
        data = null;

  @override
  String toString() => isOk ? 'ApiResult.ok' : 'ApiResult.err($error)';
}

class ApiFootball {
  final String apiKey;
  final String baseUrl;

  ApiFootball({
    required this.apiKey,
    this.baseUrl = 'https://v3.football.api-sports.io',
  });

  /// --dart-define=APIFOOTBALL_KEY=....
  static ApiFootball fromDartDefine() {
    const k = String.fromEnvironment('APIFOOTBALL_KEY');
    return ApiFootball(apiKey: k);
  }

  Future<ApiResult<Map<String, dynamic>>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    if (apiKey.isEmpty) {
      return const ApiResult.err('APIFOOTBALL_KEY este EMPTY. Setează dart-define / env var în Codemagic.');
    }

    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    try {
      final res = await http.get(
        uri,
        headers: {
          'x-apisports-key': apiKey,
          'accept': 'application/json',
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return ApiResult.err('API error ${res.statusCode}: ${res.body}', statusCode: res.statusCode);
      }

      final jsonBody = jsonDecode(res.body);
      if (jsonBody is Map<String, dynamic>) {
        return ApiResult.ok(jsonBody, statusCode: res.statusCode);
      }
      return ApiResult.err('Invalid API response', statusCode: res.statusCode);
    } catch (e) {
      return ApiResult.err('Network/parse error: $e');
    }
  }

  /// Fixtures by date (pentru HomeScreen) – returnează direct listă de map-uri
  /// ca să fie ușor de convertit în FixtureLite.
  Future<List<Map<String, dynamic>>> fixturesByDate({
    required DateTime date,
    required String timezone,
  }) async {
    final r = await _get('/fixtures', query: {
      'date': _ymd(date),
      'timezone': timezone,
    });

    if (!r.isOk || r.data == null) return <Map<String, dynamic>>[];

    final resp = r.data!['response'];
    if (resp is! List) return <Map<String, dynamic>>[];

    return resp.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Predictions (MatchScreen / cache)
  Future<ApiResult<Map<String, dynamic>?>> getPredictions(int fixtureId) async {
    final r = await _get('/predictions', query: {
      'fixture': '$fixtureId',
    });

    if (!r.isOk || r.data == null) return ApiResult.err(r.error ?? 'Unknown error', statusCode: r.statusCode);

    final resp = r.data!['response'];
    if (resp is! List || resp.isEmpty) return const ApiResult.ok(null);

    final first = resp.first;
    if (first is Map) return ApiResult.ok(first.cast<String, dynamic>());
    return const ApiResult.ok(null);
  }

  /// ✅ Head-to-head – EXACT cum vrea prediction_cache.dart: ApiResult + data
  Future<ApiResult<List<Map<String, dynamic>>>> headToHead({
    required int homeTeamId,
    required int awayTeamId,
    int last = 5,
    String? timezone,
  }) async {
    final q = <String, String>{
      'h2h': '$homeTeamId-$awayTeamId',
      'last': '$last',
    };
    if (timezone != null && timezone.isNotEmpty) q['timezone'] = timezone;

    final r = await _get('/fixtures/headtohead', query: q);
    if (!r.isOk || r.data == null) return ApiResult.err(r.error ?? 'Unknown error', statusCode: r.statusCode);

    final resp = r.data!['response'];
    if (resp is! List) return const ApiResult.ok(<Map<String, dynamic>>[]);

    final list = resp.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return ApiResult.ok(list);
  }

  /// ✅ Ultimele meciuri ale unei echipe – necesar în prediction_cache.dart
  /// API-Football: /fixtures?team=ID&last=N&timezone=...
  Future<ApiResult<List<Map<String, dynamic>>>> lastFixturesForTeam({
    required int teamId,
    int last = 8,
    String? timezone,
  }) async {
    final q = <String, String>{
      'team': '$teamId',
      'last': '$last',
    };
    if (timezone != null && timezone.isNotEmpty) q['timezone'] = timezone;

    final r = await _get('/fixtures', query: q);
    if (!r.isOk || r.data == null) return ApiResult.err(r.error ?? 'Unknown error', statusCode: r.statusCode);

    final resp = r.data!['response'];
    if (resp is! List) return const ApiResult.ok(<Map<String, dynamic>>[]);

    final list = resp.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return ApiResult.ok(list);
  }

  String _ymd(DateTime d) {
    final dd = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dd.year}-${two(dd.month)}-${two(dd.day)}';
  }
}
