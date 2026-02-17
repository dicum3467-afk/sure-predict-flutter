// lib/models/fixture.dart
class FixtureLite {
  final int id;

  final DateTime dateUtc; // API-Football returns ISO date (UTC)
  final int timestamp;

  final String statusShort; // NS, FT, 1H, HT etc.

  final int leagueId;
  final String leagueName;
  final String leagueCountry;

  final int homeId;
  final String home;
  final int awayId;
  final String away;

  final int? goalsHome;
  final int? goalsAway;

  FixtureLite({
    required this.id,
    required this.dateUtc,
    required this.timestamp,
    required this.statusShort,
    required this.leagueId,
    required this.leagueName,
    required this.leagueCountry,
    required this.homeId,
    required this.home,
    required this.awayId,
    required this.away,
    required this.goalsHome,
    required this.goalsAway,
  });

  // -------- Derived UI helpers --------
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

  static FixtureLite fromApiFootball(Map<String, dynamic> j) {
    final fixture = (j['fixture'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final league = (j['league'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final teams = (j['teams'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final homeTeam = (teams['home'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final awayTeam = (teams['away'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final goals = (j['goals'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final status = (fixture['status'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final id = (fixture['id'] as num?)?.toInt() ?? 0;
    final ts = (fixture['timestamp'] as num?)?.toInt() ?? 0;
    final dateStr = (fixture['date'] as String?) ?? '';
    final date = DateTime.tryParse(dateStr)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);

    return FixtureLite(
      id: id,
      dateUtc: date,
      timestamp: ts,
      statusShort: (status['short'] as String?) ?? '',
      leagueId: (league['id'] as num?)?.toInt() ?? 0,
      leagueName: (league['name'] as String?) ?? '',
      leagueCountry: (league['country'] as String?) ?? '',
      homeId: (homeTeam['id'] as num?)?.toInt() ?? 0,
      home: (homeTeam['name'] as String?) ?? '',
      awayId: (awayTeam['id'] as num?)?.toInt() ?? 0,
      away: (awayTeam['name'] as String?) ?? '',
      goalsHome: (goals['home'] as num?)?.toInt(),
      goalsAway: (goals['away'] as num?)?.toInt(),
    );
  }
}
