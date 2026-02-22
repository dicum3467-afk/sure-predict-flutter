// lib/services/sure_predict_service.dart
import 'dart:convert';

import '../api/api_client.dart';

/// Service layer peste ApiClient.
/// - normalizează parametrii
/// - parsează răspunsuri
/// - oferă metode clare pentru UI / store
class SurePredictService {
  final ApiClient api;

  SurePredictService(this.api);

  // --------------------------
  // Health
  // --------------------------
  Future<HealthResponse> health() async {
    final data = await api.getJson('/health');
    // backend returnează: {"status":"ok"}
    if (data is Map<String, dynamic>) {
      return HealthResponse.fromJson(data);
    }
    // fallback dacă backend-ul returnează string/alt format
    return HealthResponse(status: 'unknown');
  }

  // --------------------------
  // Leagues
  // --------------------------
  Future<List<League>> getLeagues() async {
    final data = await api.getJson('/leagues');
    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => League.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  // --------------------------
  // Fixtures list
  // --------------------------
  /// Important:
  /// - backend-ul tău folosește `league_id` (UUID) pentru filtrare.
  /// - `provider_league_id` (ex: "api_39") e doar informativ.
  ///
  /// from/to acceptă fie YYYY-MM-DD, fie ISO DateTime; aici trimitem YYYY-MM-DD.
  Future<List<Fixture>> getFixtures({
    required String leagueId, // UUID din backend (League.id)
    required DateTime from,
    required DateTime to,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'league_id': leagueId, // CHEIA CORECTĂ
      'from': _ymd(from),
      'to': _ymd(to),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final data = await api.getJson('/fixtures', query: query);

    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => Fixture.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  /// Variantă “la liber” (dacă vrei să ceri fixtures fără league_id)
  Future<List<Fixture>> getFixturesAny({
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      if (from != null) 'from': _ymd(from),
      if (to != null) 'to': _ymd(to),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final data = await api.getJson('/fixtures', query: query);

    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => Fixture.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  // --------------------------
  // Prediction
  // --------------------------
  /// Endpoint: /fixtures/{provider_fixture_id}/prediction
  ///
  /// providerFixtureId = ex: "123" (cum apare în JSON: provider_fixture_id)
  Future<Prediction> getPrediction({
    required String providerFixtureId,
  }) async {
    final data = await api.getJson('/fixtures/$providerFixtureId/prediction');
    if (data is Map) {
      return Prediction.fromJson(Map<String, dynamic>.from(data));
    }
    // dacă backend-ul returnează alt format (rare), încercăm să-l interpretăm
    return const Prediction.empty();
  }

  // --------------------------
  // Helpers
  // --------------------------
  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

// ============================================================================
// Models (simple, fără dependențe extra)
// ============================================================================

class HealthResponse {
  final String status;
  const HealthResponse({required this.status});

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(status: (json['status'] ?? '').toString());
  }
}

class League {
  final String id; // UUID din backend
  final String providerLeagueId; // ex: "api_39"
  final String name;
  final String country;
  final int tier;
  final bool isActive;

  const League({
    required this.id,
    required this.providerLeagueId,
    required this.name,
    required this.country,
    required this.tier,
    required this.isActive,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: (json['id'] ?? '').toString(),
      providerLeagueId: (json['provider_league_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      tier: _toInt(json['tier']),
      isActive: _toBool(json['is_active']),
    );
  }
}

class Fixture {
  final String id; // UUID din backend
  final String providerFixtureId; // ex: "123"
  final String leagueId; // UUID (League.id)
  final DateTime kickoffAt;
  final String status;

  final String home;
  final String away;

  // Probabilități (pot lipsi)
  final double? pHome;
  final double? pDraw;
  final double? pAway;
  final double? pGG; // both teams to score
  final double? pOver25;
  final double? pUnder25;

  // meta
  final String? runType;
  final DateTime? computedAt;

  const Fixture({
    required this.id,
    required this.providerFixtureId,
    required this.leagueId,
    required this.kickoffAt,
    required this.status,
    required this.home,
    required this.away,
    this.pHome,
    this.pDraw,
    this.pAway,
    this.pGG,
    this.pOver25,
    this.pUnder25,
    this.runType,
    this.computedAt,
  });

  factory Fixture.fromJson(Map<String, dynamic> json) {
    return Fixture(
      id: (json['id'] ?? '').toString(),
      providerFixtureId: (json['provider_fixture_id'] ?? '').toString(),
      leagueId: (json['league_id'] ?? '').toString(),
      kickoffAt: _toDateTime(json['kickoff_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: (json['status'] ?? '').toString(),
      home: (json['home'] ?? '').toString(),
      away: (json['away'] ?? '').toString(),
      runType: json['run_type']?.toString(),
      computedAt: _toDateTime(json['computed_at']),
      pHome: _toDoubleNullable(json['p_home']),
      pDraw: _toDoubleNullable(json['p_draw']),
      pAway: _toDoubleNullable(json['p_away']),
      pGG: _toDoubleNullable(json['p_gg']),
      pOver25: _toDoubleNullable(json['p_over25']),
      pUnder25: _toDoubleNullable(json['p_under25']),
    );
  }
}

class Prediction {
  final String providerFixtureId;
  final double? pHome;
  final double? pDraw;
  final double? pAway;
  final double? pGG;
  final double? pOver25;
  final double? pUnder25;

  // opțional: orice extra vine din backend (păstrăm brut)
  final Map<String, dynamic>? raw;

  const Prediction({
    required this.providerFixtureId,
    this.pHome,
    this.pDraw,
    this.pAway,
    this.pGG,
    this.pOver25,
    this.pUnder25,
    this.raw,
  });

  const Prediction.empty()
      : providerFixtureId = '',
        pHome = null,
        pDraw = null,
        pAway = null,
        pGG = null,
        pOver25 = null,
        pUnder25 = null,
        raw = null;

  factory Prediction.fromJson(Map<String, dynamic> json) {
    // În funcție de implementarea ta, prediction poate veni:
    // - direct ca map cu cheile de probabilități
    // - sau wrapped într-un "prediction"
    final Map<String, dynamic> data = _unwrapPrediction(json);

    return Prediction(
      providerFixtureId: (data['provider_fixture_id'] ?? data['providerFixtureId'] ?? '').toString(),
      pHome: _toDoubleNullable(data['p_home']),
      pDraw: _toDoubleNullable(data['p_draw']),
      pAway: _toDoubleNullable(data['p_away']),
      pGG: _toDoubleNullable(data['p_gg']),
      pOver25: _toDoubleNullable(data['p_over25']),
      pUnder25: _toDoubleNullable(data['p_under25']),
      raw: json,
    );
  }
}

// ============================================================================
// Parsing helpers
// ============================================================================

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  final s = v.toString().toLowerCase().trim();
  return s == 'true' || s == '1' || s == 'yes';
}

double? _toDoubleNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

Map<String, dynamic> _unwrapPrediction(Map<String, dynamic> json) {
  // dacă backend-ul returnează { "prediction": {...} }
  final pred = json['prediction'];
  if (pred is Map) return Map<String, dynamic>.from(pred);

  // dacă backend-ul returnează string json
  final raw = json['raw'];
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }

  return json;
}
