import '../api/api_client.dart';
import '../models/fixture_item.dart';
import '../models/league.dart';

class SurePredictService {
  SurePredictService(this._api);

  final ApiClient _api;

  Future<List<League>> getLeagues({bool? active}) async {
    final data = await _api.getJson('/leagues', query: {
      if (active != null) 'active': active.toString(),
    });

    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// IMPORTANT: backend-ul tău așteaptă `league_ids` ca param repetat:
  /// /fixtures?league_ids=<uuid1>&league_ids=<uuid2>&...
  Future<List<FixtureItem>> getFixtures({
    required List<String> leagueIds,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom, // "2026-02-19"
    String? dateTo, // "2026-02-25"
  }) async {
    // Construim query fără league_ids (le adăugăm manual repetat)
    final base = Uri.parse('${_api.baseUrl}/fixtures');

    final params = <String, String>{
      'run_type': runType,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty)
        'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    };

    final uri = base.replace(queryParameters: params);

    // repetăm league_ids: league_ids=a&league_ids=b...
    final cleanedIds = leagueIds.map((e) => e.trim()).where((e) => e.isNotEmpty);
    final leaguePart = cleanedIds.map((e) => 'league_ids=$e').join('&');

    final full =
        uri.toString() + (uri.query.isEmpty ? '?' : '&') + leaguePart;

    // apelăm pe varianta by-url (care păstrează parametrii repetați)
    return getFixturesByUrl(full);
  }

  /// Varianta corectă pentru query cu parametri repetați.
  /// `fullPathWithQuery` poate fi:
  /// - "/fixtures?league_ids=...&league_ids=..."
  /// - "https://sure-predict-backend.onrender.com/fixtures?..."
  Future<List<FixtureItem>> getFixturesByUrl(String fullPathWithQuery) async {
    final Uri u = Uri.parse(fullPathWithQuery);

    // dacă a venit URL complet, luăm doar path+query pentru ApiClient
    final String path = u.path; // ex: /fixtures
    final Map<String, String> qp = Map<String, String>.from(u.queryParameters);

    // Atenție: u.queryParameters NU păstrează valorile repetate (league_ids),
    // de aceea preferăm să trimitem totul în path, cu query inclus.
    // Soluția simplă: construim `pathWithQuery` manual și îl dăm la _api.getJson.
    final String pathWithQuery =
        u.hasQuery ? '$path?${u.query}' : path; // păstrează query raw

    final data = await _api.getJson(pathWithQuery);

    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Util pentru store: construiește un path cu league_ids repetat.
  String buildFixturesPath({
    required List<String> leagueIds,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) {
    final params = <String, String>{
      'run_type': runType,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty)
        'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    };

    final ids = leagueIds.map((e) => e.trim()).where((e) => e.isNotEmpty);
    final leaguePart = ids.map((e) => 'league_ids=$e').join('&');

    final otherPart = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final all = [leaguePart, otherPart].where((s) => s.isNotEmpty).join('&');

    return '/fixtures?$all';
  }
}
