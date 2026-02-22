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

    if (data is! List) return <League>[];
    return data
        .whereType<Map>()
        .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// IMPORTANT:
  /// Backend-ul vrea `league_ids` ca parametru repetat:
  /// /fixtures?league_ids=uuid&league_ids=uuid2&run_type=initial&limit=50&offset=0
  ///
  /// De asta construim URL-ul complet (path+query) și apelăm getFixturesByUrl().
  String buildFixturesPath({
    required List<String> leagueUids,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) {
    final ids = leagueUids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final otherParams = <String, String>{
      'run_type': runType,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    };

    final leaguePart = ids.map((e) => 'league_ids=${Uri.encodeQueryComponent(e)}').join('&');
    final otherPart = otherParams.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final all = [leaguePart, otherPart].where((s) => s.isNotEmpty).join('&');
    return '/fixtures?$all';
  }

  /// APEL CORECT pentru query cu `league_ids` repetat:
  /// îi dăm path complet care include deja `?query`
  Future<List<FixtureItem>> getFixturesByUrl(String fullPathWithQuery) async {
    // ApiClient.getJson acceptă un path. În ApiClient-ul tău, dacă path include '?',
    // va funcționa pentru că uriString(path, query) nu strică.
    final data = await _api.getJson(fullPathWithQuery);

    if (data is! List) return <FixtureItem>[];
    return data
        .whereType<Map>()
        .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
