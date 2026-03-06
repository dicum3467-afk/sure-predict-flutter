class FixtureUiModel {
  final int fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String leagueName;
  final String leagueCountry;
  final DateTime kickoffAt;
  final String status;

  const FixtureUiModel({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.leagueName,
    required this.leagueCountry,
    required this.kickoffAt,
    required this.status,
  });
}

class TopPickUiModel {
  final int fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String leagueName;
  final String market;
  final String selection;
  final double probability;
  final double? fairOdd;

  const TopPickUiModel({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.leagueName,
    required this.market,
    required this.selection,
    required this.probability,
    this.fairOdd,
  });
}
