class FixtureLite {
  final int id;
  final String home;
  final String away;
  final String league;

  FixtureLite({
    required this.id,
    required this.home,
    required this.away,
    required this.league,
  });

  static FixtureLite fromApi(Map<String, dynamic> item) {
    final fixture = item['fixture'];
    final teams = item['teams'];
    final league = item['league'];

    return FixtureLite(
      id: fixture['id'],
      home: teams['home']['name'],
      away: teams['away']['name'],
      league: league['name'],
    );
  }
}
