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
    return data.whereType<Map>().map((e) => League.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// IMPORTANT: backend-ul tău așteaptă `league_ids` ca param repetat:
  /// /fixtures?league_ids=<uuid>&league_ids=<uuid2>...
  Future<List<FixtureItem>> getFixtures({
    required List<String> leagueIds,
    String? status,
    String? dateFrom, // "2026-02-19"
    String? dateTo,   // "2026-02-25"
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
  }) async {
    // Construim query manual ca să repetăm league_ids
    final base = Uri.parse('${_api.baseUrl}/fixtures');
    final params = <String, String>{
      'run_type': runType,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    };

    final repeated = <String>[];
    for (final id in leagueIds) {
      final v = id.trim();
      if (v.isNotEmpty) repeated.add(v);
    }

    final uri = base.replace(
      queryParameters: params,
    );

    // adăugăm league_ids repetat
    final finalUri = Uri.parse(
      uri.toString() +
          (uri.query.isEmpty ? '?' : '&') +
          repeated.map((e) => 'league_ids=$e').join('&'),
    );

    final data = await _api.getJson(finalUri.path, query: finalUri.queryParameters);

    // Observație: pentru că am folosit getJson(path, query), a reconstruit query-ul fără league_ids repetat.
    // Așa că facem un mic hack: apel direct pe ApiClient la URL complet nu există,
    // deci facem request prin path special:
    // => SOLUȚIA simplă: refacem apelul cu path complet (inclus query).
    // (ApiClient.getJson folosește Uri.parse(baseUrl + path). Dacă path include '?', e ok)
  }

  /// Variantă corectă pentru league_ids repetat:
  Future<List<FixtureItem>> getFixturesByUrl(String fullPathWithQuery) async {
    final data = await _api.getJson(fullPathWithQuery);

    if (data is! List) return [];
    return data.whereType<Map>().map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  String buildFixturesPath({
    required List<String> leagueIds,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) {
    final q = <String, String>{
      'run_type': runType,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    };

    final ids = leagueIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final leaguePart = ids.map((e) => 'league_ids=$e').join('&');
    final otherPart = q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');

    final all = [leaguePart, otherPart].where((e) => e.isNotEmpty).join('&');
    return '/fixtures?$all';
  }
}
