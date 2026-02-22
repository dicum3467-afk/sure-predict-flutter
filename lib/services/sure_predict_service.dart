import '../api/api_client.dart';
import '../cache/local_cache.dart';
import '../models/fixture_item.dart';
import '../models/league.dart';
import '../models/prediction.dart';

class SurePredictService {
  SurePredictService(this._api, {LocalCache? cache}) : _cache = cache;

  final ApiClient _api;
  LocalCache? _cache;

  Future<void> initCache() async {
    _cache ??= await LocalCache.create();
  }

  String _key(String path, Map<String, dynamic>? query) {
    final q = (query ?? {}).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final qs = q.map((e) => '${e.key}=${e.value}').join('&');
    return 'sp::$path?$qs';
  }

  /// cacheFirst=true: dacă există cache valid, îl returnează imediat.
  /// apoi poți face refresh din UI (force network).
  Future<List<League>> getLeagues({bool? active, bool cacheFirst = true}) async {
    await initCache();
    final path = '/leagues';
    final query = <String, dynamic>{
      if (active != null) 'active': active.toString(),
    };

    final cacheKey = _key(path, query);
    if (cacheFirst) {
      final cached = _cache!.getJson(cacheKey, ttl: const Duration(hours: 24));
      if (cached is List) {
        return cached
            .whereType<Map>()
            .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    final data = await _api.getJson(path, query: query);
    if (data is List) {
      await _cache!.setJson(cacheKey, data);
      return data
          .whereType<Map>()
          .map((e) => League.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Construiește query corect:
  /// /fixtures?league_ids=a&league_ids=b&run_type=initial&limit=50&offset=0&date_from=YYYY-MM-DD&date_to=YYYY-MM-DD
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

  Future<List<FixtureItem>> getFixturesByUrl(
    String fullPathWithQuery, {
    bool cacheFirst = true,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    await initCache();

    final cacheKey = 'sp::$fullPathWithQuery';
    if (cacheFirst) {
      final cached = _cache!.getJson(cacheKey, ttl: ttl);
      if (cached is List) {
        return cached
            .whereType<Map>()
            .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    final data = await _api.getJson(fullPathWithQuery);
    if (data is List) {
      await _cache!.setJson(cacheKey, data);
      return data
          .whereType<Map>()
          .map((e) => FixtureItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<Prediction?> getPrediction(
    String providerFixtureId, {
    String runType = 'initial',
    bool cacheFirst = true,
  }) async {
    await initCache();

    final path = '/fixtures/$providerFixtureId/prediction';
    final query = {'run_type': runType};

    final cacheKey = _key(path, query);
    if (cacheFirst) {
      final cached = _cache!.getJson(cacheKey, ttl: const Duration(hours: 2));
      if (cached is Map) {
        return Prediction.fromJson(Map<String, dynamic>.from(cached));
      }
    }

    final data = await _api.getJson(path, query: query);
    if (data is Map) {
      await _cache!.setJson(cacheKey, data);
      return Prediction.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }
}
