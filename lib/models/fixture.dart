class FixtureLite {
  final int id;
  final DateTime date; // UTC
  final String statusShort;

  final int leagueId;
  final String leagueName;
  final String leagueCountry;

  final int homeId;
  final String homeName;

  final int awayId;
  final String awayName;

  final int? goalsHome;
  final int? goalsAway;

  FixtureLite({
    required this.id,
    required this.date,
    required this.statusShort,
    required this.leagueId,
    required this.leagueName,
    required this.leagueCountry,
    required this.homeId,
    required this.homeName,
    required this.awayId,
    required this.awayName,
    required this.goalsHome,
    required this.goalsAway,
  });

  bool get isFinished => statusShort == 'FT' || statusShort == 'AET' || statusShort == 'PEN';
  bool get isNotStarted => statusShort == 'NS';

  String get scoreText {
    if (goalsHome == null || goalsAway == null) return '—';
    return '$goalsHome-$goalsAway';
  }

  String leagueLabel() {
    if (leagueCountry.isEmpty) return leagueName;
    return '$leagueName • $leagueCountry';
  }

  factory FixtureLite.fromApiFootball(Map<String, dynamic> item) {
    final fixture = (item['fixture'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final league = (item['league'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final teams = (item['teams'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final home = (teams['home'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final away = (teams['away'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final goals = (item['goals'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final status = (fixture['status'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final id = (fixture['id'] as num?)?.toInt() ?? 0;
    final dateStr = fixture['date'] as String?;
    final parsed = dateStr != null ? DateTime.tryParse(dateStr) : null;

    return FixtureLite(
      id: id,
      date: (parsed?.toUtc()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      statusShort: (status['short'] as String?) ?? '',
      leagueId: (league['id'] as num?)?.toInt() ?? 0,
      leagueName: (league['name'] as String?) ?? '',
      leagueCountry: (league['country'] as String?) ?? '',
      homeId: (home['id'] as num?)?.toInt() ?? 0,
      homeName: (home['name'] as String?) ?? '',
      awayId: (away['id'] as num?)?.toInt() ?? 0,
      awayName: (away['name'] as String?) ?? '',
      goalsHome: (goals['home'] as num?)?.toInt(),
      goalsAway: (goals['away'] as num?)?.toInt(),
    );
  }
}
