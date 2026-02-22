import '../api/api_client.dart';
import '../models/fixture_item.dart';
import '../models/league.dart';
import '../models/prediction.dart';

class SurePredictService {
  SurePredictService(this._api);

  final ApiClient _api;

  Future<List<League>> getLeagues({bool? active}) async {
    final data = await _api.getJson(
      '/leagues',
      query: {
        if (active != null) 'active': active.toString(),
      },
    );

    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Construiește query corect:
  /// /fixtures?league_ids=uuid&league_ids=uuid2&run_type=initial&limit=50&offset=0...
  String buildFixturesPath({
    required List<String> leagueIds,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom, // "YYYY-MM-DD"
    String? dateTo,   // "YYYY-MM-DD"
  }) {
    final ids = leagueIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final parts = <String>[];

    // league_ids repetat (repeat param)
    for (final id in ids) {
      parts.add('league_ids=${Uri.encodeQueryComponent(id)}');
    }

    parts.add('run_type=${Uri.encodeQueryComponent(runType)}');
    parts.add('limit=${Uri.encodeQueryComponent(limit.toString())}');
    parts.add('offset=${Uri.encodeQueryComponent(offset.toString())}');

    if (status != null && status.trim().isNotEmpty) {
      parts.add('status=${Uri.encodeQueryComponent(status.trim())}');
    }
    if (dateFrom != null && dateFrom.trim().isNotEmpty) {
      parts.add('date_from=${Uri.encodeQueryComponent(dateFrom.trim())}');
    }
    if (dateTo != null && dateTo.trim().isNotEmpty) {
      parts.add('date_to=${Uri.encodeQueryComponent(dateTo.trim())}');
    }

    return '/fixtures?${parts.join('&')}';
  }

  /// Cere fixtures folosind path complet ce include query deja.
  Future<List<FixtureItem>> getFixturesByUrl(String fullPathWithQuery) async {
    final data = await _api.getJson(fullPathWithQuery);

    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// ✅ Pasul 2: ia prediction pentru un fixture (provider_fixture_id)
  Future<Prediction?> getPrediction(String providerFixtureId, {String runType = 'initial'}) async {
    final data = await _api.getJson(
      '/fixtures/$providerFixtureId/prediction',
      query: {'run_type': runType},
    );

    if (data is Map) {
      return Prediction.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }
}
