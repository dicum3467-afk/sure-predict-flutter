import 'dart:convert';

import 'api_client.dart';
import '../core/cache/simple_cache.dart';

class CacheInfo {
  final int? ageSeconds;
  final bool isFresh;

  const CacheInfo({required this.ageSeconds, required this.isFresh});
}

class SurePredictService {
  final ApiClient _api;

  final SimpleCache _cache = const SimpleCache(ttl: Duration(minutes: 15));

  SurePredictService(this._api);

  Future<void> health() async {
    await _api.getJson('/health');
  }

  // ---------- cache key helpers ----------
  String _stableEncodeQuery(Map<String, dynamic> query) {
    final keys = query.keys.toList()..sort();
    final out = <String, dynamic>{};

    for (final k in keys) {
      final v = query[k];
      if (v is List) {
        final list = v.map((e) => e.toString()).toList()..sort();
        out[k] = list;
      } else {
        out[k] = v;
      }
    }

    return jsonEncode(out);
  }

  String _cacheKey(String path, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return path;
    return '$path?${_stableEncodeQuery(query)}';
  }

  // Exposed cache info (pentru badge UI)
  Future<CacheInfo> fixturesCacheInfo({
    required List<String> leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String runType = 'initial',
    String? status,
  }) async {
    final query = <String, dynamic>{
      if (leagueIds.isNotEmpty) 'league_ids': leagueIds,
      'date_from': from,
      'date_to': to,
      'limit': limit,
      'offset': offset,
      'run_type': runType,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };

    final key = _cacheKey('/fixtures', query);
    final age = await _cache.getAgeSeconds(key);
    final fresh = await _cache.isFresh(key);

    return CacheInfo(ageSeconds: age, isFresh: fresh);
  }

  // ---------- leagues (SWR cached) ----------
  Future<List<Map<String, dynamic>>> getLeagues() async {
    final key = _cacheKey('/leagues', const {});

    final data = await _cache.getSWR<dynamic>(
      key: key,
      fetcher: () async => await _api.getJson('/leagues'),
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  // ---------- fixtures (SWR cached) ----------
  Future<List<Map<String, dynamic>>> getFixtures({
    required List<String> leagueIds,
    required String from,
    required String to,
    int limit = 50,
    int offset = 0,
    String runType = 'initial',
    String? status,
  }) async {
    final query = <String, dynamic>{
      if (leagueIds.isNotEmpty) 'league_ids': leagueIds,
      'date_from': from,
      'date_to': to,
      'limit': limit,
      'offset': offset,
      'run_type': runType,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };

    final key = _cacheKey('/fixtures', query);

    final data = await _cache.getSWR<dynamic>(
      key: key,
      fetcher: () async => await _api.getJson('/fixtures', query: query),
    );

    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }
  // ================= TOP PICKS PRO =================

Future<List<Map<String, dynamic>>> getTopPicksPro({
  required List<String> leagueIds,
  required String from,
  required String to,
  String? status,
  String runType = 'initial',
  double threshold = 0.62,
  int maxPicks = 30,
  bool preferOver25 = true,
  bool force = false,
}) async {
  // ia fixtures (cache-ul tău de 15 min se aplică deja)
  final fixtures = await getFixtures(
    leagueIds: leagueIds,
    from: from,
    to: to,
    status: status,
    runType: runType,
    limit: 400,
    offset: 0,
    force: force,
  );

  // calculează pick pe fiecare meci
  final picks = <Map<String, dynamic>>[];

  for (final it in fixtures) {
    final enriched = Map<String, dynamic>.from(it);

    final p1 = _toD(enriched['p_home']);
    final px = _toD(enriched['p_draw']);
    final p2 = _toD(enriched['p_away']);
    final po = _toD(enriched['p_over25']);
    final pu = _toD(enriched['p_under25']);

    // dacă lipsesc probabilități, ignorăm
    if (p1 == null && px == null && p2 == null && po == null && pu == null) continue;

    // 1X2 best
    final oneXtwo = <String, double>{
      '1': p1 ?? 0,
      'X': px ?? 0,
      '2': p2 ?? 0,
    };
    var best1x2 = oneXtwo.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final best1x2Prob = best1x2.value;

    // O/U 2.5 best
    final ou = <String, double>{
      'O2.5': po ?? 0,
      'U2.5': pu ?? 0,
    };
    var bestOu = ou.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final bestOuProb = bestOu.value;

    // alege market
    String pickMarket;
    double pickProb;

    if (preferOver25 && bestOuProb > 0 && bestOuProb >= best1x2Prob + 0.02) {
      pickMarket = bestOu.key;
      pickProb = bestOuProb;
    } else {
      pickMarket = best1x2.key;
      pickProb = best1x2Prob;
    }

    // filtru threshold
    if (pickProb < threshold) continue;

    // PRO SCORE (edge față de a doua opțiune) + bonus pentru “claritate”
    //  - pentru 1X2: diferenta best vs secondBest
    //  - pentru OU: diferenta best vs other
    double edge = 0.0;

    if (pickMarket == '1' || pickMarket == 'X' || pickMarket == '2') {
      final sorted = oneXtwo.values.toList()..sort((a, b) => b.compareTo(a));
      final top = sorted.isNotEmpty ? sorted[0] : 0.0;
      final second = sorted.length > 1 ? sorted[1] : 0.0;
      edge = (top - second);
    } else {
      edge = (bestOuProb - ((pickMarket == 'O2.5') ? (pu ?? 0) : (po ?? 0)));
    }

    // score final: probabilitate + edge “agresiv” (tuning pentru monetizare)
    // scor tipic 0.10 - 0.40
    final score = (pickProb - 0.50) + (edge * 1.6);

    enriched['_pick_market'] = pickMarket;
    enriched['_pick_prob'] = pickProb;
    enriched['_pick_score'] = score;

    picks.add(enriched);
  }

  // sortare PRO: score desc, apoi probabilitate desc, apoi kickoff
  picks.sort((a, b) {
    final sa = _toD(a['_pick_score']) ?? 0;
    final sb = _toD(b['_pick_score']) ?? 0;
    final c1 = sb.compareTo(sa);
    if (c1 != 0) return c1;

    final pa = _toD(a['_pick_prob']) ?? 0;
    final pb = _toD(b['_pick_prob']) ?? 0;
    final c2 = pb.compareTo(pa);
    if (c2 != 0) return c2;

    final ka = (a['kickoff_at'] ?? a['kickoff'] ?? '').toString();
    final kb = (b['kickoff_at'] ?? b['kickoff'] ?? '').toString();
    return ka.compareTo(kb);
  });

  if (picks.length > maxPicks) {
    return picks.take(maxPicks).toList();
  }
  return picks;
}

double? _toD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
} 
  // ---------- prediction (NU cache by default) ----------
  Future<Map<String, dynamic>> getPrediction({
    required String providerFixtureId,
  }) async {
    final data = await _api.getJson('/fixtures/$providerFixtureId/prediction');

    if (data is Map) return Map<String, dynamic>.from(data);

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
  }
}
