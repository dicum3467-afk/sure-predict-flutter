import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/fixture.dart';

class ApiResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResult.ok(this.data, {this.statusCode}) : error = null;
  const ApiResult.err(this.error, {this.statusCode}) : data = null;

  bool get isOk => error == null;
}

class ApiFootball {
  final String apiKey;
  final http.Client _client;

  /// API-SPORTS Football endpoint (v3)
  final String baseUrl;

  ApiFootball({
    required this.apiKey,
    http.Client? client,
    this.baseUrl = 'https://v3.football.api-sports.io',
  }) : _client = client ?? http.Client();

  /// Helper: citește din --dart-define=APIFOOTBALL_KEY=...
  factory ApiFootball.fromDartDefine({String baseUrl = 'https://v3.football.api-sports.io'}) {
    const k = String.fromEnvironment('APIFOOTBALL_KEY');
    return ApiFootball(apiKey: k, baseUrl: baseUrl);
  }

  Map<String, String> get _headers => {
        'x-apisports-key': apiKey,
        'Accept': 'application/json',
      };

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<ApiResult<Map<String, dynamic>>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    if (apiKey.isEmpty) {
      return const ApiResult.err('Missing APIFOOTBALL_KEY (empty).');
    }

    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    try {
      final resp = await _client.get(uri, headers: _headers);
      final code = resp.statusCode;

      final decoded = json.decode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return ApiResult.err('Invalid JSON response', statusCode: code);
      }

      // API-SPORTS structure: { get, parameters, errors, results, paging, response }
      final errors = decoded['errors'];
      if (code < 200 || code >= 300) {
        return ApiResult.err('HTTP $code: ${json.encode(errors ?? decoded)}', statusCode: code);
      }

      // uneori întoarce errors.token etc chiar cu 200; tratăm:
      if (errors is Map && errors.isNotEmpty) {
        return ApiResult.err('API errors: ${json.encode(errors)}', statusCode: code);
      }

      return ApiResult.ok(decoded, statusCode: code);
    } catch (e) {
      return ApiResult.err('Network/parse error: $e');
    }
  }

  /// Fixtures pentru o zi (IMPORTANT: DateTime, nu String)
  Future<ApiResult<List<FixtureLite>>> fixturesByDate({
    required DateTime date,
    String timezone = 'Europe/Bucharest',
  }) async {
    final res = await _get('/fixtures', query: {
      'date': _ymd(date),
      'timezone': timezone,
    });
    if (!res.isOk) return ApiResult.err(res.error, statusCode: res.statusCode);

    final root = res.data!;
    final resp = root['response'];
    if (resp is! List) return const ApiResult.ok(<FixtureLite>[]);

    final out = <FixtureLite>[];
    for (final item in resp) {
      if (item is Map<String, dynamic>) {
        out.add(FixtureLite.fromApiFootball(item));
      } else if (item is Map) {
        out.add(FixtureLite.fromApiFootball(item.cast<String, dynamic>()));
      }
    }
    return ApiResult.ok(out, statusCode: res.statusCode);
  }

  /// Fixtures între două date (inclusiv), cu limită externă impusă de UI (ex: 7 zile)
  Future<ApiResult<List<FixtureLite>>> fixturesBetween({
    required DateTime start,
    required DateTime end,
    String timezone = 'Europe/Bucharest',
  }) async {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);

    if (e.isBefore(s)) {
      return const ApiResult.err('Invalid range: end < start');
    }

    final days = e.difference(s).inDays + 1;
    final combined = <FixtureLite>[];

    for (int i = 0; i < days; i++) {
      final d = s.add(Duration(days: i));
      final r = await fixturesByDate(date: d, timezone: timezone);
      if (!r.isOk) return ApiResult.err(r.error, statusCode: r.statusCode);
      combined.addAll(r.data ?? const <FixtureLite>[]);
    }

    return ApiResult.ok(combined);
  }

  /// Predictions pentru un fixture id
  Future<ApiResult<Map<String, dynamic>>> getPredictions(int fixtureId) async {
    final res = await _get('/predictions', query: {
      'fixture': fixtureId.toString(),
    });
    if (!res.isOk) return ApiResult.err(res.error, statusCode: res.statusCode);

    final root = res.data!;
    final resp = root['response'];
    if (resp is List && resp.isNotEmpty) {
      final first = resp.first;
      if (first is Map<String, dynamic>) return ApiResult.ok(first, statusCode: res.statusCode);
      if (first is Map) return ApiResult.ok(first.cast<String, dynamic>(), statusCode: res.statusCode);
    }
    return ApiResult.err('Predictions not available', statusCode: res.statusCode);
  }

  /// H2H - folosit de prediction_cache.dart (ca să nu mai crape build-ul)
  Future<ApiResult<List<Map<String, dynamic>>>> headToHead({
    required int homeTeamId,
    required int awayTeamId,
    int last = 5,
  }) async {
    final res = await _get('/fixtures/headtohead', query: {
      'h2h': '$homeTeamId-$awayTeamId',
      'last': last.toString(),
    });
    if (!res.isOk) return ApiResult.err(res.error, statusCode: res.statusCode);

    final root = res.data!;
    final resp = root['response'];
    if (resp is! List) return const ApiResult.ok(<Map<String, dynamic>>[]);

    final out = <Map<String, dynamic>>[];
    for (final x in resp) {
      if (x is Map<String, dynamic>) out.add(x);
      if (x is Map) out.add(x.cast<String, dynamic>());
    }
    return ApiResult.ok(out, statusCode: res.statusCode);
  }

  /// Ultimele meciuri pentru o echipă - folosit de prediction_cache.dart
  Future<ApiResult<List<Map<String, dynamic>>>> lastFixturesForTeam({
    required int teamId,
    int last = 8,
    String timezone = 'Europe/Bucharest',
  }) async {
    final res = await _get('/fixtures', query: {
      'team': teamId.toString(),
      'last': last.toString(),
      'timezone': timezone,
    });
    if (!res.isOk) return ApiResult.err(res.error, statusCode: res.statusCode);

    final root = res.data!;
    final resp = root['response'];
    if (resp is! List) return const ApiResult.ok(<Map<String, dynamic>>[]);

    final out = <Map<String, dynamic>>[];
    for (final x in resp) {
      if (x is Map<String, dynamic>) out.add(x);
      if (x is Map) out.add(x.cast<String, dynamic>());
    }
    return ApiResult.ok(out, statusCode: res.statusCode);
  }
}
