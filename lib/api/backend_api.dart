import "dart:convert";
import "package:http/http.dart" as http;

import "../constants.dart";
import "../models/fixture_item.dart";

class BackendApi {
  final http.Client _client;

  BackendApi({http.Client? client}) : _client = client ?? http.Client();

  Future<List<FixtureItem>> getFixturesByLeague({
    required String leagueId,
    String? dateFrom, // YYYY-MM-DD
    String? dateTo,   // YYYY-MM-DD
    String? status,
    String? runType,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse("$kBaseUrl/fixtures/by-league").replace(
      queryParameters: <String, String>{
        "league_id": leagueId,
        if (dateFrom != null && dateFrom.isNotEmpty) "date_from": dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) "date_to": dateTo,
        if (status != null && status.isNotEmpty) "status": status,
        if (runType != null && runType.isNotEmpty) "run_type": runType,
        "limit": limit.toString(),
        "offset": offset.toString(),
      },
    );

    final res = await _client.get(uri, headers: {
      "accept": "application/json",
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Backend error ${res.statusCode}: ${res.body}");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! List) {
      throw Exception("Expected List from /fixtures/by-league, got: ${decoded.runtimeType}");
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(FixtureItem.fromJson)
        .toList();
  }
}
