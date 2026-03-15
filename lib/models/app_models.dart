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
    final ggMap = Map<String, dynamic>.from((json['gg'] ?? {}) as Map);
    final ou25 = Map<String, dynamic>.from((json['ou25'] ?? {}) as Map);

    return PredictionProbsUi(
      home: _asDouble(oneX2['1']),
      draw: _asDouble(oneX2['X']),
      away: _asDouble(oneX2['2']),
      gg: _asDouble(ggMap['GG']),
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
  final String selection;
  final double odd;
  final double impliedProbability;
  final double modelProbability;
  final double edge;
  final double expectedValue;
  final double? fairOdd;

  TopPickUiModel({
    required this.fixtureId,
    required this.leagueName,
    required this.homeTeam,
    required this.awayTeam,
    required this.market,
    required this.selection,
    required this.odd,
    required this.impliedProbability,
    required this.modelProbability,
    required this.edge,
    required this.expectedValue,
    required this.fairOdd,
  });

  factory TopPickUiModel.fromJson(Map<String, dynamic> json) {
    return TopPickUiModel(
      fixtureId: (json['fixture_id'] ?? '').toString(),
      leagueName: (json['league_name'] ?? '').toString(),
      homeTeam: (json['home_team'] ?? '').toString(),
      awayTeam: (json['away_team'] ?? '').toString(),
      market: (json['market'] ?? '').toString(),
      selection: (json['selection'] ?? '').toString(),
      odd: _asDouble(json['odd']),
      impliedProbability: _asDouble(json['implied_probability']),
      modelProbability: _asDouble(json['model_probability']),
      edge: _asDouble(json['edge']),
      expectedValue: _asDouble(json['expected_value']),
      fairOdd: json['fair_odd'] == null ? null : _asDouble(json['fair_odd']),
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
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
