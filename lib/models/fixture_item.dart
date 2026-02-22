class FixtureItem {
  final String id; // UUID intern fixture
  final String providerFixtureId; // "123" sau "api_fix_1001"
  final String leagueId; // UUID liga
  final DateTime? kickoffAt;
  final String status;
  final String home;
  final String away;

  // prediction
  final String? runType;
  final DateTime? computedAt;
  final double? pHome;
  final double? pDraw;
  final double? pAway;
  final double? pGg;
  final double? pOver25;
  final double? pUnder25;

  FixtureItem({
    required this.id,
    required this.providerFixtureId,
    required this.leagueId,
    required this.status,
    required this.home,
    required this.away,
    this.kickoffAt,
    this.runType,
    this.computedAt,
    this.pHome,
    this.pDraw,
    this.pAway,
    this.pGg,
    this.pOver25,
    this.pUnder25,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return DateTime.tryParse(s);
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory FixtureItem.fromJson(Map<String, dynamic> json) {
    return FixtureItem(
      id: (json['id'] ?? '').toString(),
      providerFixtureId: (json['provider_fixture_id'] ?? '').toString(),
      leagueId: (json['league_id'] ?? '').toString(),
      kickoffAt: _parseDate(json['kickoff_at']),
      status: (json['status'] ?? '').toString(),
      home: (json['home'] ?? '').toString(),
      away: (json['away'] ?? '').toString(),
      runType: json['run_type']?.toString(),
      computedAt: _parseDate(json['computed_at']),
      pHome: _parseDouble(json['p_home']),
      pDraw: _parseDouble(json['p_draw']),
      pAway: _parseDouble(json['p_away']),
      pGg: _parseDouble(json['p_gg']),
      pOver25: _parseDouble(json['p_over25']),
      pUnder25: _parseDouble(json['p_under25']),
    );
  }
}
