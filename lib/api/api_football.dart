import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiFootball {
  static const _base = 'https://v3.football.api-sports.io';
  final String apiKey;

  ApiFootball(this.apiKey);

  Map<String, String> get _headers => {
        'x-apisports-key': apiKey,
      };

  bool get hasKey => apiKey.trim().isNotEmpty;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<_ApiResult<List<Map<String, dynamic>>>> fixturesByDate({
    required DateTime date,
    String? timezone, // ex: "Europe/Bucharest"
    int? leagueId, // ex: 283 = Romania SuperLiga (Liga 1) in API-Football
    int? season,
  }) async {
    if (!hasKey) {
      return _ApiResult.err('Lipsește cheia API (APIFOOTBALL_KEY).');
    }

    final q = <String, String>{
      'date': _fmtDate(date),
    };
    if (timezone != null && timezone.trim().isNotEmpty) q['timezone'] = timezone.trim();
    if (leagueId != null) q['league'] = leagueId.toString();
    if (season != null) q['season'] = season.toString();

    final uri = Uri.parse('$_base/fixtures').replace(queryParameters: q);
    final res = await http.get(uri, headers: _headers);

    if (res.statusCode != 200) {
      return _ApiResult.err('HTTP ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      return _ApiResult.err('API errors: $errors');
    }

    final resp = (data['response'] as List).cast<Map<String, dynamic>>();
    return _ApiResult.ok(resp);
  }

  Future<_ApiResult<Map<String, dynamic>?>> getPredictions(int fixtureId) async {
    if (!hasKey) {
      return _ApiResult.err('Lipsește cheia API (APIFOOTBALL_KEY).');
    }

    final uri = Uri.parse('$_base/predictions').replace(queryParameters: {
      'fixture': fixtureId.toString(),
    });

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      return _ApiResult.err('HTTP ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      return _ApiResult.err('API errors: $errors');
    }

    final resp = (data['response'] as List);
    if (resp.isEmpty) return _ApiResult.ok(null);

    return _ApiResult.ok(resp.first as Map<String, dynamic>);
  }
}

class _ApiResult<T> {
  final T? data;
  final String? error;
  const _ApiResult._(this.data, this.error);
  factory _ApiResult.ok(T data) => _ApiResult._(data, null);
  factory _ApiResult.err(String msg) => _ApiResult._(null, msg);
  bool get isOk => error == null;
}
