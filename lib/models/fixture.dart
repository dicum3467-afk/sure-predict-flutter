class FixtureLite {
  final int id;

  final int homeId;
  final int awayId;

  final String home;
  final String away;

  final String? league;       // ex: "Liga 1"
  final int? leagueId;        // ex: 283
  final String? country;      // ex: "Romania"

  final DateTime? date;       // kickoff
  final String? statusShort;  // NS / FT / 1H / HT etc.

  // opțional (nu e folosit obligatoriu)
  final int? goalsHome;
  final int? goalsAway;

  const FixtureLite({
    required this.id,
    required this.homeId,
    required this.awayId,
    required this.home,
    required this.away,
    this.league,
    this.leagueId,
    this.country,
    this.date,
    this.statusShort,
    this.goalsHome,
    this.goalsAway,
  });

  /// Parser robust pentru obiectul din API-Football (fixture item).
  /// Acceptă map-uri cu structura:
  /// { fixture: { id, date, status:{short} }, league:{id,name,country}, teams:{home:{id,name},away:{...}}, goals:{home,away} }
  factory FixtureLite.fromApiFootball(Map<String, dynamic> m) {
    final fixture = (m['fixture'] is Map) ? (m['fixture'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final league = (m['league'] is Map) ? (m['league'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final teams = (m['teams'] is Map) ? (m['teams'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final homeT = (teams['home'] is Map) ? (teams['home'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final awayT = (teams['away'] is Map) ? (teams['away'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    final status = (fixture['status'] is Map) ? (fixture['status'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    final goals = (m['goals'] is Map) ? (m['goals'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    int asInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      return int.tryParse('$v') ?? fallback;
    }

    String asStr(dynamic v, {String fallback = ''}) {
      if (v is String) return v;
      if (v == null) return fallback;
      return '$v';
    }

    DateTime? asDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse('$v');
      } catch (_) {
        return null;
      }
    }

    return FixtureLite(
      id: asInt(fixture['id']),
      homeId: asInt(homeT['id']),
      awayId: asInt(awayT['id']),
      home: asStr(homeT['name'], fallback: 'Home'),
      away: asStr(awayT['name'], fallback: 'Away'),
      league: asStr(league['name'], fallback: ''),
      leagueId: league['id'] == null ? null : asInt(league['id']),
      country: asStr(league['country'], fallback: ''),
      date: asDate(fixture['date']),
      statusShort: asStr(status['short'], fallback: ''),
      goalsHome: goals['home'] == null ? null : asInt(goals['home']),
      goalsAway: goals['away'] == null ? null : asInt(goals['away']),
    );
  }

  /// Helper pentru filtre simple
  String leagueTextLower() => (league ?? '').toLowerCase();

  /// Status safe
  String statusSafe() => (statusShort == null || statusShort!.isEmpty) ? 'NS' : statusShort!;
}
