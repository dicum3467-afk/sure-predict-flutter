import '../models/app_models.dart';

class MockData {
  static List<String> leagues = [
    'All',
    'Premier League',
    'LaLiga',
    'Serie A',
    'Bundesliga',
    'Ligue 1',
  ];

  static List<FixtureUiModel> fixtures = [
    FixtureUiModel(
      fixtureId: 101,
      homeTeam: 'Liverpool',
      awayTeam: 'Arsenal',
      leagueName: 'Premier League',
      leagueCountry: 'England',
      kickoffAt: DateTime.now().add(const Duration(hours: 5)),
      status: 'NS',
    ),
    FixtureUiModel(
      fixtureId: 102,
      homeTeam: 'Barcelona',
      awayTeam: 'Atletico Madrid',
      leagueName: 'LaLiga',
      leagueCountry: 'Spain',
      kickoffAt: DateTime.now().add(const Duration(hours: 8)),
      status: 'NS',
    ),
    FixtureUiModel(
      fixtureId: 103,
      homeTeam: 'Inter',
      awayTeam: 'Juventus',
      leagueName: 'Serie A',
      leagueCountry: 'Italy',
      kickoffAt: DateTime.now().add(const Duration(hours: 10)),
      status: 'NS',
    ),
    FixtureUiModel(
      fixtureId: 104,
      homeTeam: 'Bayern',
      awayTeam: 'Dortmund',
      leagueName: 'Bundesliga',
      leagueCountry: 'Germany',
      kickoffAt: DateTime.now().add(const Duration(hours: 12)),
      status: 'NS',
    ),
    FixtureUiModel(
      fixtureId: 105,
      homeTeam: 'PSG',
      awayTeam: 'Monaco',
      leagueName: 'Ligue 1',
      leagueCountry: 'France',
      kickoffAt: DateTime.now().add(const Duration(hours: 15)),
      status: 'NS',
    ),
  ];

  static List<TopPickUiModel> topPicks = [
    TopPickUiModel(
      fixtureId: 101,
      homeTeam: 'Liverpool',
      awayTeam: 'Arsenal',
      leagueName: 'Premier League',
      market: '1X2',
      selection: '1',
      probability: 0.58,
      fairOdd: 1.72,
    ),
    TopPickUiModel(
      fixtureId: 102,
      homeTeam: 'Barcelona',
      awayTeam: 'Atletico Madrid',
      leagueName: 'LaLiga',
      market: 'GG',
      selection: 'GG',
      probability: 0.61,
      fairOdd: 1.64,
    ),
    TopPickUiModel(
      fixtureId: 103,
      homeTeam: 'Inter',
      awayTeam: 'Juventus',
      leagueName: 'Serie A',
      market: 'O/U 2.5',
      selection: 'U2.5',
      probability: 0.57,
      fairOdd: 1.75,
    ),
  ];
}
