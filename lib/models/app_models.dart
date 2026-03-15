class FixtureUiModel {
  final String fixtureId;
  final String providerFixtureId;
  final String kickoffAt;
  final String status;
  final String? round;
  final String leagueId;
  final int? season;
  final String leagueName;
  final String leagueCountry;

  final TeamUiModel homeTeam;
  final TeamUiModel awayTeam;

  final PredictionModelUi? model;

  FixtureUiModel({
    required this.fixtureId,
    required this.providerFixtureId,
    required this.kickoffAt,
    required this.status,
    required this.round,
    required this.leagueId,
    required this.season,
    required this.leagueName,
    required this.leagueCountry,
    required this.homeTeam,
    required this.awayTeam,
    required this.model,
  });

  factory FixtureUiModel.fromJson(Map<String, dynamic> json) {
    return FixtureUiModel(
      fixtureId: (json['fixture_id'] ?? json['id'] ?? '').toString(),
      providerFixtureId: (json['provider_fixture_id'] ?? '').toString(),
      kickoffAt: (json['kickoff_at'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      round: json['round']?.toString(),
      leagueId: (json['league_id'] ?? '').toString(),
      season: _asInt(json['season']),
      leagueName: (json['league_name'] ?? '').toString(),
      leagueCountry: (json['league_country'] ?? '').toString(),
      homeTeam: TeamUiModel.fromJson(
        Map<String, dynamic>.from((json['home_team'] ?? {}) as Map),
      ),
      awayTeam: TeamUiModel.fromJson(
        Map<String, dynamic>.from((json['away_team'] ?? {}) as Map),
      ),
      model: json['model'] == null
          ? null
          : PredictionModelUi.fromJson(
              Map<String, dynamic>.from((json['model']) as Map),
            ),
    );
  }
}

class TeamUiModel {
  final String id;
  final String name;
  final String short;

  TeamUiModel({
    required this.id,
    required this.name,
    required this.short,
  });

  factory TeamUiModel.fromJson(Map<String, dynamic> json) {
    return TeamUiModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      short: (json['short'] ?? '').toString(),
    );
  }
}

class PredictionModelUi {
  final String type;
  final double homeExpected;
  final double awayExpected;
  final double avgGoalsLeague;
  final PredictionProbsUi probs;

  PredictionModelUi({
    required this.type,
    required this.homeExpected,
    required this.awayExpected,
    required this.avgGoalsLeague,
    required this.probs,
  });

  factory PredictionModelUi.fromJson(Map<String, dynamic> json) {
    return PredictionModelUi(
      type: (json['type'] ?? '').toString(),
      homeExpected: _asDouble(json['home_xg']),
      awayExpected: _asDouble(json['away_xg']),
      avgGoalsLeague: _asDouble(json['avg_goals_league']),
      probs: PredictionProbsUi.fromJson(
        Map<String, dynamic>.from((json['probs'] ?? {}) as Map),
      ),
    );
  }
}

class PredictionProbsUi {
  final double home;
  final double draw;
  final double away;
  final double gg;
  final double over25;

  PredictionProbsUi({
    required this.home,
    required this.draw,
    required this.away,
    required this.gg,
    required this.over25,
  });

  factory PredictionProbsUi.fromJson(Map<String, dynamic> json) {
    final oneX2 = Map<String, dynamic>.from((json['1x2'] ?? {}) as Map);
    final gg = Map<String, dynamic>.from((json['gg'] ?? {}) as Map);
    final ou25 = Map<String, dynamic>.from((json['ou25'] ?? {}) as Map);

    return PredictionProbsUi(
      home: _asDouble(oneX2['1']),
      draw: _asDouble(oneX2['X']),
      away: _asDouble(oneX2['2']),
      gg: _asDouble(gg['GG']),
      over25: _asDouble(ou25['O2.5']),
    );
  }
}

class TopPickUiModel {
  final String fixtureId;
  final String leagueName;
  final String homeTeam;
  final String awayTeam;
  final String market;
  final double probability;
  final double? fairOdd;

  TopPickUiModel({
    required this.fixtureId,
    required this.leagueName,
    required this.homeTeam,
    required this.awayTeam,
    required this.market,
    required this.probability,
    this.fairOdd,
  });

  factory TopPickUiModel.fromJson(Map<String, dynamic> json) {
    return TopPickUiModel(
      fixtureId: json['fixture_id'] ?? '',
      leagueName: json['league_name'] ?? '',
      homeTeam: json['home_team'] ?? '',
      awayTeam: json['away_team'] ?? '',
      market: json['market'] ?? '',
      probability: (json['probability'] ?? 0).toDouble(),
      fairOdd: json['fair_odd'] != null
          ? (json['fair_odd'] as num).toDouble()
          : null,
    );
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
