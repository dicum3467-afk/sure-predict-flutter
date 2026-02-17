import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/fixture.dart';
import '../models/prediction_lite.dart';

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
  final String baseUrl;

  ApiFootball({
    required this.apiKey,
    http.Client? client,
    this.baseUrl = 'https://v3.football.api-sports.io',
  }) : _client = client ?? http.Client();

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

      final errors = decoded['errors'];
      if (code < 200 || code >= 300) {
        return ApiResult.err('HTTP $code: ${json.encode(errors ?? decoded)}', statusCode: code);
      }
      if (errors is Map && errors.isNotEmpty) {
        return ApiResult.err('API errors: ${json.encode(errors)}', statusCode: code);
      }

      return ApiResult.ok(decoded, statusCode: code);
    } catch (e) {
      return ApiResult.err('Network/parse error: $e');
    }
  }

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
      if (item is Map<String, dynamic>) out.add(FixtureLite.fromApiFootball(item));
      if (item is Map) out.add(FixtureLite.fromApiFootball(item.cast<String, dynamic>()));
    }
    return ApiResult.ok(out, statusCode: res.statusCode);
  }

  Future<ApiResult<List<FixtureLite>>> fixturesBetween({
    required DateTime start,
    required DateTime end,
    String timezone = 'Europe/Bucharest',
  }) async {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    if (e.isBefore(s)) return const ApiResult.err('Invalid range: end < start');

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

  Future<ApiResult<Map<String, dynamic>>> getPredictionsRaw(int fixtureId) async {
    final res = await _get('/predictions', query: {'fixture': fixtureId.toString()});
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

  Future<ApiResult<PredictionLite>> getPredictionLite(int fixtureId) async {
    final raw = await getPredictionsRaw(fixtureId);
    if (!raw.isOk || raw.data == null) return ApiResult.err(raw.error, statusCode: raw.statusCode);

    try {
      final p = PredictionLite.fromApiFootballPrediction(
        fixtureId: fixtureId,
        obj: raw.data!,
      );
      return ApiResult.ok(p, statusCode: raw.statusCode);
    } catch (e) {
      return ApiResult.err('Prediction parse error: $e', statusCode: raw.statusCode);
    }
  }
}
