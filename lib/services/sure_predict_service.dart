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
      // ✅ cache leagues 24h (nu se schimbă des)
      cacheTtl: const Duration(hours: 24),
      cacheFirst: true,
    );

    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// path complet cu query inclus (cum ai tu: /fixtures?league_ids=...&...)
  Future<List<FixtureItem>> getFixturesByUrl(String fullPathWithQuery) async {
    final data = await _api.getJson(
      fullPathWithQuery,
      // ✅ fixtures cache 5 minute (destul de safe)
      cacheTtl: const Duration(minutes: 5),
      cacheFirst: true,
    );

    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Prediction per meci: cache 1h (sau mai mult, cum vrei)
  Future<Prediction?> getPrediction(
    String providerFixtureId, {
    String runType = 'initial',
  }) async {
    final data = await _api.getJson(
      '/fixtures/$providerFixtureId/prediction',
      query: {'run_type': runType},
      cacheTtl: const Duration(hours: 1),
      cacheFirst: true,
    );

    if (data is Map) {
      return Prediction.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// (rămâne la fel) build url cu league_ids repetat
  String buildFixturesPath({
    required List<String> leagueIds,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) {
    final ids = leagueIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final parts = <String>[];
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
}
