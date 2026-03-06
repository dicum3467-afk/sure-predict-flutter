import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/api_models.dart';
import '../models/app_models.dart';

class ApiService {
  static const String baseUrl = 'https://sure-predict-backend.onrender.com';

  Future<List<FixtureUiModel>> getFixtures({
    int page = 1,
    int perPage = 50,
    String? providerLeagueId,
    String? search,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'order': 'asc',
    };

    if (providerLeagueId != null &&
        providerLeagueId.isNotEmpty &&
        providerLeagueId != 'All') {
      query['provider_league_id'] = providerLeagueId;
    }

    final uri = Uri.parse('$baseUrl/fixtures').replace(queryParameters: query);

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Fixtures request failed: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = FixtureApiResponse.fromJson(json);

    var items = parsed.items.map(_mapFixtureItemToUi).toList();

    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase().trim();
      items = items.where((f) {
        return f.homeTeam.toLowerCase().contains(q) ||
            f.awayTeam.toLowerCase().contains(q) ||
            f.leagueName.toLowerCase().contains(q) ||
            f.leagueCountry.toLowerCase().contains(q);
      }).toList();
    }

    return items;
  }

  Future<PredictionResponse> getPredictionByFixture(int fixtureId) async {
    final uri = Uri.parse('$baseUrl/predictions/by-fixture/$fixtureId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Prediction request failed: ${response.statusCode}');
    }

    return PredictionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ValuePicksResponse> getValueByFixture(int fixtureId) async {
    final uri = Uri.parse('$baseUrl/value/by-fixture/$fixtureId');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Value picks request failed: ${response.statusCode}');
    }

    return ValuePicksResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<TopPickUiModel>> getTopPicksFromPredictions({
    int limit = 10,
  }) async {
    final fixtures = await getFixtures(page: 1, perPage: limit);

    final List<TopPickUiModel> picks = [];

    for (final fixture in fixtures) {
      try {
        final pred = await getPredictionByFixture(fixture.fixtureId);
        if (!pred.exists) continue;

        final pick = pred.picks['1x2'];
        final probs1x2 = pred.probs['1x2'];

        if (pick is Map && probs1x2 is Map) {
          final selection = (pick['pick'] ?? '-').toString();
          final probability = ((pick['prob'] ?? 0).toDouble());

          picks.add(
            TopPickUiModel(
              fixtureId: fixture.fixtureId,
              homeTeam: fixture.homeTeam,
              awayTeam: fixture.awayTeam,
              leagueName: fixture.leagueName,
              market: '1X2',
              selection: selection,
              probability: probability,
              fairOdd: probability > 0 ? (1 / probability) : null,
            ),
          );
        }
      } catch (_) {}
    }

    picks.sort((a, b) => b.probability.compareTo(a.probability));
    return picks.take(limit).toList();
  }

  FixtureUiModel _mapFixtureItemToUi(FixtureItem item) {
    return FixtureUiModel(
      fixtureId: item.id,
      homeTeam: item.homeTeam ?? 'Home',
      awayTeam: item.awayTeam ?? 'Away',
      leagueName: item.leagueName ?? 'League',
      leagueCountry: item.leagueCountry ?? '',
      kickoffAt: item.kickoffAt ?? DateTime.now(),
      status: item.status ?? 'NS',
    );
  }
}
