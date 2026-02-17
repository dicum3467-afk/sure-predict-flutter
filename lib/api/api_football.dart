import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiFootball {
  final String apiKey;
  final String baseUrl;

  ApiFootball({
    required this.apiKey,
    this.baseUrl = 'https://v3.football.api-sports.io',
  });

  /// Folosește --dart-define=APIFOOTBALL_KEY=....
  static ApiFootball fromDartDefine() {
    const k = String.fromEnvironment('APIFOOTBALL_KEY');
    return ApiFootball(apiKey: k);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('APIFOOTBALL_KEY este EMPTY. Setează dart-define / env var în Codemagic.');
    }

    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(
      uri,
      headers: {
        'x-apisports-key': apiKey,
        'accept': 'application/json',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }

    final jsonBody = jsonDecode(res.body);
    if (jsonBody is Map<String, dynamic>) return jsonBody;
    throw Exception('Invalid API response');
  }

  /// Returnează List<Map<String,dynamic>> (fixture items)
  Future<List<Map<String, dynamic>>> fixturesByDate({
    required DateTime date,
    required String timezone,
  }) async {
    final j = await _get('/fixtures', query: {
      'date': _ymd(date),
      'timezone': timezone,
    });

    final resp = j['response'];
    if (resp is! List) return <Map<String, dynamic>>[];

    return resp.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Returnează obiectul brut de la /predictions (primul element din response)
  Future<Map<String, dynamic>?> getPredictions(int fixtureId) async {
    final j = await _get('/predictions', query: {
      'fixture': '$fixtureId',
    });

    final resp = j['response'];
    if (resp is! List || resp.isEmpty) return null;

    final first = resp.first;
    if (first is Map) return first.cast<String, dynamic>();
    return null;
  }

  /// ✅ Head-to-Head: folosit de prediction_cache.dart
  /// API-Football: GET /fixtures/headtohead?h2h=HOME-AWAY&last=5
  Future<List<Map<String, dynamic>>> headToHead({
    required int homeTeamId,
    required int awayTeamId,
    int last = 5,
    String? timezone,
  }) async {
    final q = <String, String>{
      'h2h': '$homeTeamId-$awayTeamId',
      'last': '$last',
    };
    if (timezone != null && timezone.isNotEmpty) {
      q['timezone'] = timezone;
    }

    final j = await _get('/fixtures/headtohead', query: q);

    final resp = j['response'];
    if (resp is! List) return <Map<String, dynamic>>[];

    return resp.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  String _ymd(DateTime d) {
    final dd = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dd.year}-${two(dd.month)}-${two(dd.day)}';
  }
}
