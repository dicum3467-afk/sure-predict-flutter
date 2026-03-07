class PredictionResponse {
  final int count;
  final List<PredictionItem> items;

  PredictionResponse({
    required this.count,
    required this.items,
  });

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? [];
    return PredictionResponse(
      count: json['count'] ?? 0,
      items: rawItems
          .map((e) => PredictionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PredictionItem {
  final String fixtureId;
  final dynamic providerFixtureId;
  final String kickoffAt;
  final String status;
  final dynamic round;
  final String leagueId;
  final String seasonId;
  final String leagueName;
  final String leagueCountry;
  final TeamInfo homeTeam;
  final TeamInfo awayTeam;
  final PredictionModel model;
  final PredictionMarkets markets;
  final TopPick topPick;
  final PredictionAnalysis analysis;

  PredictionItem({
    required this.fixtureId,
    required this.providerFixtureId,
    required this.kickoffAt,
    required this.status,
    required this.round,
    required this.leagueId,
    required this.seasonId,
    required this.leagueName,
    required this.leagueCountry,
    required this.homeTeam,
    required this.awayTeam,
    required this.model,
    required this.markets,
    required this.topPick,
    required this.analysis,
  });

  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      fixtureId: json['fixture_id']?.toString() ?? '',
      providerFixtureId: json['provider_fixture_id'],
      kickoffAt: json['kickoff_at']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      round: json['round'],
      leagueId: json['league_id']?.toString() ?? '',
      seasonId: json['season_id']?.toString() ?? '',
      leagueName: json['league_name']?.toString() ?? '',
      leagueCountry: json['league_country']?.toString() ?? '',
      homeTeam: TeamInfo.fromJson((json['home_team'] as Map?)?.cast<String, dynamic>() ?? {}),
      awayTeam: TeamInfo.fromJson((json['away_team'] as Map?)?.cast<String, dynamic>() ?? {}),
      model: PredictionModel.fromJson((json['model'] as Map?)?.cast<String, dynamic>() ?? {}),
      markets: PredictionMarkets.fromJson((json['markets'] as Map?)?.cast<String, dynamic>() ?? {}),
      topPick: TopPick.fromJson((json['top_pick'] as Map?)?.cast<String, dynamic>() ?? {}),
      analysis: PredictionAnalysis.fromJson((json['analysis'] as Map?)?.cast<String, dynamic>() ?? {}),
    );
  }
}

class TeamInfo {
  final String id;
  final String name;
  final String short;

  TeamInfo({
    required this.id,
    required this.name,
    required this.short,
  });

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      short: json['short']?.toString() ?? '',
    );
  }
}

class PredictionModel {
  final String type;
  final double homeXg;
  final double awayXg;
  final double avgHomeGoalsLeague;
  final double avgAwayGoalsLeague;
  final double homeElo;
  final double awayElo;
  final double eloDiff;

  PredictionModel({
    required this.type,
    required this.homeXg,
    required this.awayXg,
    required this.avgHomeGoalsLeague,
    required this.avgAwayGoalsLeague,
    required this.homeElo,
    required this.awayElo,
    required this.eloDiff,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    double num(dynamic v) => v is num ? v.toDouble() : 0.0;

    return PredictionModel(
      type: json['type']?.toString() ?? '',
      homeXg: num(json['home_xg']),
      awayXg: num(json['away_xg']),
      avgHomeGoalsLeague: num(json['avg_home_goals_league']),
      avgAwayGoalsLeague: num(json['avg_away_goals_league']),
      homeElo: num(json['home_elo']),
      awayElo: num(json['away_elo']),
      eloDiff: num(json['elo_diff']),
    );
  }
}

class PredictionMarkets {
  final Market1X2 oneXTwo;
  final DoubleChanceMarket doubleChance;
  final BttsMarket btts;
  final Ou25Market ou25;
  final Ht1X2Market ht1x2;
  final List<CorrectScore> correctScoreTop;

  PredictionMarkets({
    required this.oneXTwo,
    required this.doubleChance,
    required this.btts,
    required this.ou25,
    required this.ht1x2,
    required this.correctScoreTop,
  });

  factory PredictionMarkets.fromJson(Map<String, dynamic> json) {
    final rawScores = (json['correct_score_top'] as List?) ?? [];
    return PredictionMarkets(
      oneXTwo: Market1X2.fromJson((json['1x2'] as Map?)?.cast<String, dynamic>() ?? {}),
      doubleChance: DoubleChanceMarket.fromJson((json['double_chance'] as Map?)?.cast<String, dynamic>() ?? {}),
      btts: BttsMarket.fromJson((json['btts'] as Map?)?.cast<String, dynamic>() ?? {}),
      ou25: Ou25Market.fromJson((json['ou_2_5'] as Map?)?.cast<String, dynamic>() ?? {}),
      ht1x2: Ht1X2Market.fromJson((json['ht_1x2'] as Map?)?.cast<String, dynamic>() ?? {}),
      correctScoreTop: rawScores
          .map((e) => CorrectScore.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Market1X2 {
  final double home;
  final double draw;
  final double away;
  final FairOdds1X2 fairOdds;

  Market1X2({
    required this.home,
    required this.draw,
    required this.away,
    required this.fairOdds,
  });

  factory Market1X2.fromJson(Map<String, dynamic> json) {
    double num(dynamic v) => v is num ? v.toDouble() : 0.0;

    return Market1X2(
      home: num(json['1']),
      draw: num(json['X']),
      away: num(json['2']),
      fairOdds: FairOdds1X2.fromJson((json['fair_odds'] as Map?)?.cast<String, dynamic>() ?? {}),
    );
  }
}

class FairOdds1X2 {
  final double? home;
  final double? draw;
  final double? away;

  FairOdds1X2({
    required this.home,
    required this.draw,
    required this.away,
  });

  factory FairOdds1X2.fromJson(Map<String, dynamic> json) {
    double? numOrNull(dynamic v) => v is num ? v.toDouble() : null;

    return FairOdds1X2(
      home: numOrNull(json['1']),
      draw: numOrNull(json['X']),
      away: numOrNull(json['2']),
    );
  }
}

class DoubleChanceMarket {
  final double oneX;
  final double xTwo;
  final double oneTwo;

  DoubleChanceMarket({
    required this.oneX,
    required this.xTwo,
    required this.oneTwo,
  });

  factory DoubleChanceMarket.fromJson(Map<String, dynamic> json) {
    double num(dynamic v) => v is num ? v.toDouble() : 0.0;

    return DoubleChanceMarket(
      oneX: num(json['1X']),
      xTwo: num(json['X2']),
      oneTwo: num(json['12']),
    );
  }
}

class BttsMarket {
  final double gg;
  final double noGg;
  final double? fairGg;

  BttsMarket({
    required this.gg,
    required this.noGg,
    required this.fairGg,
  });

  factory BttsMarket.fromJson(Map<String, dynamic> json) {
    double num(dynamic v) => v is num ? v.toDouble() : 0.0;
    double? numOrNull(dynamic v) => v is num ? v.toDouble() : null;
    final fair = (json['fair_odds'] as Map?)?.cast<String, dynamic>() ?? {};

    return BttsMarket(
      gg: num(json['GG']),
      noGg: num(json['NO_GG']),
      fairGg: numOrNull(fair['GG']),
    );
  }
}

class Ou25Market {
  final double over25;
  final double under25;
  final double? fairOver25;

  Ou25Market({
    required this.over25,
    required this.under25,
    required this.fairOver25,
  });

  factory Ou25Market.fromJson(Map<String, dynamic> json) {
    double num(dynamic v) => v is num ? v.toDouble() : 0.0;
    double? numOrNull(dynamic v) => v is num ? v.toDouble() : null;
    final fair = (json['fair_odds'] as Map?)?.cast<String, dynamic>() ?? {};

    return Ou25Market(
      over25: num(json['OVER_2_5']),
      under25: num(json['UNDER_2_5']),
      fairOver25: numOrNull(fair['OVER_2_5']),
    );
  }
}

class Ht1X2Market {
  final double home;
  final double draw;
  final double away;

  Ht1X2Market({
    required this.home,
    required this.draw,
    required this.away,
  });

  factory Ht1X2Market.fromJson(Map<String, dynamic> json) {
    double num(dynamic v) => v is num ? v.toDouble() : 0.0;

    return Ht1X2Market(
      home: num(json['1']),
      draw: num(json['X']),
      away: num(json['2']),
    );
  }
}

class CorrectScore {
  final String score;
  final double probability;

  CorrectScore({
    required this.score,
    required this.probability,
  });

  factory CorrectScore.fromJson(Map<String, dynamic> json) {
    return CorrectScore(
      score: json['score']?.toString() ?? '',
      probability: json['probability'] is num ? (json['probability'] as num).toDouble() : 0.0,
    );
  }
}

class TopPick {
  final String market;
  final double confidence;

  TopPick({
    required this.market,
    required this.confidence,
  });

  factory TopPick.fromJson(Map<String, dynamic> json) {
    return TopPick(
      market: json['market']?.toString() ?? '',
      confidence: json['confidence'] is num ? (json['confidence'] as num).toDouble() : 0.0,
    );
  }
}

class PredictionAnalysis {
  final String summary;
  final List<String> notes;

  PredictionAnalysis({
    required this.summary,
    required this.notes,
  });

  factory PredictionAnalysis.fromJson(Map<String, dynamic> json) {
    final rawNotes = (json['notes'] as List?) ?? [];
    return PredictionAnalysis(
      summary: json['summary']?.toString() ?? '',
      notes: rawNotes.map((e) => e.toString()).toList(),
    );
  }
}
