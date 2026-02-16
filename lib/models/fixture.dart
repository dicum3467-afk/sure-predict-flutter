class FixtureLite {
  final int id;
  final String home;
  final String away;
  final int homeId;
  final int awayId;
  final String league;

  final DateTime date;
  final String statusShort;
  final int? goalsHome;
  final int? goalsAway;

  FixtureLite({
    required this.id,
    required this.home,
    required this.away,
    required this.homeId,
    required this.awayId,
    required this.league,
    required this.date,
    required this.statusShort,
    required this.goalsHome,
    required this.goalsAway,
  });

  bool get isFinished => statusShort == 'FT' || statusShort == 'AET' || statusShort == 'PEN';
  bool get isLive => const {'1H', '2H', 'HT', 'ET', 'P', 'LIVE'}.contains(statusShort);

  static FixtureLite fromApi(Map<String, dynamic> item) {
    final fixture = item['fixture'] as Map<String, dynamic>;
    final teams = item['teams'] as Map<String, dynamic>;
    final league = item['league'] as Map<String, dynamic>;
    final goals = (item['goals'] ?? {}) as Map<String, dynamic>;
    final status = (fixture['status'] ?? {}) as Map<String, dynamic>;

    final dateStr = (fixture['date'] ?? '').toString();
    final date = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();

    return FixtureLite(
      id: fixture['id'] as int,
      home: (teams['home']['name'] ?? '').toString(),
      away: (teams['away']['name'] ?? '').toString(),
      homeId: teams['home']['id'] as int,
      awayId: teams['away']['id'] as int,
      league: (league['name'] ?? '').toString(),
      date: date,
      statusShort: (status['short'] ?? '').toString(),
      goalsHome: goals['home'] is int ? goals['home'] as int : int.tryParse('${goals['home']}'),
      goalsAway: goals['away'] is int ? goals['away'] as int : int.tryParse('${goals['away']}'),
    );
  }
}
