class MatchPredictionResponse {
  final bool ok;
  final bool exists;
  final int fixtureId;
  final String modelVersion;
  final String? computedAt;
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> probs;
  final Map<String, dynamic> picks;
  final Map<String, dynamic> metrics;

  MatchPredictionResponse({
    required this.ok,
    required this.exists,
    required this.fixtureId,
    required this.modelVersion,
    this.computedAt,
    required this.inputs,
    required this.probs,
    required this.picks,
    required this.metrics,
  });

  factory MatchPredictionResponse.fromJson(Map<String, dynamic> json) {
    return MatchPredictionResponse(
      ok: json['ok'] ?? false,
      exists: json['exists'] ?? false,
      fixtureId: json['fixture_id'] ?? 0,
      modelVersion: json['model_version'] ?? '',
      computedAt: json['computed_at'],
      inputs: Map<String, dynamic>.from(json['inputs'] ?? {}),
      probs: Map<String, dynamic>.from(json['probs'] ?? {}),
      picks: Map<String, dynamic>.from(json['picks'] ?? {}),
      metrics: Map<String, dynamic>.from(json['metrics'] ?? {}),
    );
  }
}

class ValuePicksResponse {
  final bool ok;
  final int count;
  final List<ValuePickItem> items;

  ValuePicksResponse({
    required this.ok,
    required this.count,
    required this.items,
  });

  factory ValuePicksResponse.fromJson(Map<String, dynamic> json) {
    return ValuePicksResponse(
      ok: json['ok'] ?? false,
      count: json['count'] ?? 0,
      items: (json['items'] as List? ?? [])
          .map((e) => ValuePickItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ValuePickItem {
  final int fixtureId;
  final String bookmaker;
  final String market;
  final String selection;
  final double modelProb;
  final double? fairOdd;
  final double bookOdd;
  final double edge;
  final double expectedValue;
  final double confidence;

  ValuePickItem({
    required this.fixtureId,
    required this.bookmaker,
    required this.market,
    required this.selection,
    required this.modelProb,
    required this.fairOdd,
    required this.bookOdd,
    required this.edge,
    required this.expectedValue,
    required this.confidence,
  });

  factory ValuePickItem.fromJson(Map<String, dynamic> json) {
    return ValuePickItem(
      fixtureId: json['fixture_id'] ?? 0,
      bookmaker: json['bookmaker'] ?? '',
      market: json['market'] ?? '',
      selection: json['selection'] ?? '',
      modelProb: (json['model_prob'] ?? 0).toDouble(),
      fairOdd: json['fair_odd'] != null ? (json['fair_odd']).toDouble() : null,
      bookOdd: (json['book_odd'] ?? 0).toDouble(),
      edge: (json['edge'] ?? 0).toDouble(),
      expectedValue: (json['expected_value'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class FixtureUiModel {
  final int fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String leagueName;
  final DateTime kickoffAt;

  FixtureUiModel({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.leagueName,
    required this.kickoffAt,
  });
}
