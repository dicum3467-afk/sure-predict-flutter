class FixtureItem {
  final String id;
  final String leagueId;
  final int apiFixtureId;

  final String homeTeam;
  final String awayTeam;

  final String fixtureDate; // ISO string
  final String status;

  final int? homeGoals;
  final int? awayGoals;

  final String? runType;

  FixtureItem({
    required this.id,
    required this.leagueId,
    required this.apiFixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.fixtureDate,
    required this.status,
    required this.homeGoals,
    required this.awayGoals,
    required this.runType,
  });

  factory FixtureItem.fromJson(Map<String, dynamic> json) {
    return FixtureItem(
      id: (json["id"] ?? "").toString(),
      leagueId: (json["league_id"] ?? "").toString(),
      apiFixtureId: (json["api_fixture_id"] ?? 0) is int
          ? (json["api_fixture_id"] as int)
          : int.tryParse((json["api_fixture_id"] ?? "0").toString()) ?? 0,
      homeTeam: (json["home_team"] ?? "").toString(),
      awayTeam: (json["away_team"] ?? "").toString(),
      fixtureDate: (json["fixture_date"] ?? "").toString(),
      status: (json["status"] ?? "").toString(),
      homeGoals: _toNullableInt(json["home_goals"]),
      awayGoals: _toNullableInt(json["away_goals"]),
      runType: json["run_type"]?.toString(),
    );
  }

  static int? _toNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
