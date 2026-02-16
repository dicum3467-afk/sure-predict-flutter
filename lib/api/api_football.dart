import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiFootball {
  static const _base = 'https://v3.football.api-sports.io';
  final String apiKey;

  ApiFootball(this.apiKey);

  bool get hasKey => apiKey.trim().isNotEmpty;

  Map<String, String> get _headers => {
        'x-apisports-key': apiKey,
      };

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Fixtures pentru o zi.
  /// Parametrii utili:
  /// - timezone: ex. "Europe/Bucharest"
  /// - leagueId: ex. 283 (România SuperLiga) — poate diferi în funcție de API.
  /// - season: ex. 2025
  Future<ApiResult<List<Map<String, dynamic>>>> fixturesByDate({
    required DateTime date,
    String? timezone,
    int? leagueId,
    int? season,
  }) async {
    if (!hasKey) {
      return ApiResult.err('Lipsește cheia API (APIFOOTBALL_KEY).');
    }

    final qp = <String, String>{
      'date': _fmtDate(date),
    };

    if (timezone != null && timezone.trim().isNotEmpty) {
      qp['timezone'] = timezone.trim();
    }
    if (leagueId != null) qp['league'] = leagueId.toString();
    if (season != null) qp['season'] = season.toString();

    final uri = Uri.parse('$_base/fixtures').replace(queryParameters: qp);

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      return ApiResult.err('HTTP ${res.statusCode}: ${_short(res.body)}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;

    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      return ApiResult.err('API errors: $errors');
    }

    final resp = (data['response'] as List).cast<Map<String, dynamic>>();
    return ApiResult.ok(resp);
  }

  /// Fixtures pentru interval: ultimele [daysBack] zile + azi.
  /// Exemplu: daysBack=3 -> (acum-3 zile ... azi)
  Future<ApiResult<List<Map<String, dynamic>>>> fixturesLastDays({
    required int daysBack,
    String? timezone,
    int? leagueId,
    int? season,
  }) async {
    if (!hasKey) {
      return ApiResult.err('Lipsește cheia API (APIFOOTBALL_KEY).');
    }

    final all = <Map<String, dynamic>>[];

    for (int i = daysBack; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final r = await fixturesByDate(
        date: d,
        timezone: timezone,
        leagueId: leagueId,
        season: season,
      );
      if (!r.isOk) return ApiResult.err(r.error!);
      all.addAll(r.data!);
    }

    // sortare după kick-off
    all.sort((a, b) {
      final da = _fixtureDate(a);
      final db = _fixtureDate(b);
      return da.compareTo(db);
    });

    return ApiResult.ok(all);
  }

  /// Predictions pentru un fixture.
  Future<ApiResult<Map<String, dynamic>?>> getPredictions(int fixtureId) async {
    if (!hasKey) {
      return ApiResult.err('Lipsește cheia API (APIFOOTBALL_KEY).');
    }

    final uri = Uri.parse('$_base/predictions').replace(queryParameters: {
      'fixture': fixtureId.toString(),
    });

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      return ApiResult.err('HTTP ${res.statusCode}: ${_short(res.body)}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;

    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      return ApiResult.err('API errors: $errors');
    }

    final resp = (data['response'] as List);
    if (resp.isEmpty) return ApiResult.ok(null);

    return ApiResult.ok(resp.first as Map<String, dynamic>);
  }

  DateTime _fixtureDate(Map<String, dynamic> item) {
    final fixture = (item['fixture'] ?? {}) as Map<String, dynamic>;
    final ds = (fixture['date'] ?? '').toString();
    return DateTime.tryParse(ds) ?? DateTime(1970);
  }

  String _short(String s) {
    if (s.length <= 240) return s;
    return '${s.substring(0, 240)}…';
  }
}

class ApiResult<T> {
  final T? data;
  final String? error;

  const ApiResult._(this.data, this.error);

  factory ApiResult.ok(T data) => ApiResult._(data, null);
  factory ApiResult.err(String msg) => ApiResult._(null, msg);

  bool get isOk => error == null;
}
