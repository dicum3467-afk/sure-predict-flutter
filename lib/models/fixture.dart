class Fixture {

  final String home;
  final String away;
  final String league;
  final String kickoff;

  Fixture({
    required this.home,
    required this.away,
    required this.league,
    required this.kickoff,
  });

  factory Fixture.fromJson(Map<String, dynamic> json) {

    return Fixture(
      home: json["home_team"]["name"],
      away: json["away_team"]["name"],
      league: json["league_name"],
      kickoff: json["kickoff_at"],
    );
  }
}
