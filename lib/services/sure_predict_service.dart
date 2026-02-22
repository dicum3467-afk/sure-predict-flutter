import '../api/api_client.dart';
import '../cache/local_cache.dart';
import '../models/fixture_item.dart';
import '../models/league.dart';
import '../models/prediction.dart';

class SurePredictService {
  SurePredictService(this._api, {LocalCache? cache}) : _cache = cache;

  final ApiClient _api;
  final LocalCache? _cache;

  /// helper: cheie cache stabilă (include path+query)
  String _cacheKey(String pathWithQuery) => 'GET:$pathWithQuery';

  Future<List<League>> getLeagues({bool? active}) async {
    const path = '/leagues';
    final query = <String, dynamic>{
      if (active != null) 'active': active.toString(),
    };

    // pentru cheie cache: path + query sortat
    final qs = query.entries.map((e) => '${e.key}=${e.value}').join('&');
    final key = _cacheKey(qs.isEmpty ? path : '$path?$qs');

    // cacheFirst (rapid) – 6h
    final cached = _cache?.getJson(key, ttl: const Duration(hours: 6));
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final data = await _api.getJson(path, query: query);

    if (data is! List) return [];
    await _cache?.setJson(key, data);

    return data
        .whereType<Map>()
        .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Construieste query corect:
  /// /fixtures?league_ids=uuid1&league_ids=uuid2&run_type=initial&limit=50&offset=0...
  String buildFixturesPath({
    required List<String> leagueIds,
    String runType = 'initial',
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom, // YYYY-MM-DD
    String? dateTo, // YYYY-MM-DD
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

  /// GET fixtures folosind path complet cu query deja inclus
  /// cacheFirst: dacă e true, arată imediat din cache (dacă există), apoi tu poți da refresh din UI.
  Future<List<FixtureItem>> getFixturesByUrl(
    String fullPathWithQuery, {
    bool cacheFirst = true,
    Duration cacheTtl = const Duration(minutes: 10),
  }) async {
    final key = _cacheKey(fullPathWithQuery);

    if (cacheFirst) {
      final cached = _cache?.getJson(key, ttl: cacheTtl);
      if (cached is List) {
        return cached
            .whereType<Map>()
            .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    final data = await _api.getJson(
      fullPathWithQuery,
      // retry/timeout sunt in ApiClient deja
    );

    if (data is! List) return [];
    await _cache?.setJson(key, data);

    return data
        .whereType<Map>()
        .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Prediction?> getPrediction(
    String providerFixtureId, {
    String runType = 'initial',
    bool cacheFirst = true,
    Duration cacheTtl = const Duration(hours: 1),
  }) async {
    final path = '/fixtures/$providerFixtureId/prediction';
    final query = {'run_type': runType};
    final qs = query.entries.map((e) => '${e.key}=${e.value}').join('&');
    final key = _cacheKey('$path?$qs');

    if (cacheFirst) {
      final cached = _cache?.getJson(key, ttl: cacheTtl);
      if (cached is Map) {
        return Prediction.fromJson(Map<String, dynamic>.from(cached));
      }
    }

    final data = await _api.getJson(path, query: query);
    if (data is Map) {
      await _cache?.setJson(key, data);
      return Prediction.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }
}
