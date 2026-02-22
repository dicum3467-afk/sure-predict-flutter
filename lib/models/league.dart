class League {
  final String id; // UUID intern (important!)
  final String? providerLeagueId; // ex: api_39
  final String name;
  final String? country;
  final int? tier;
  final bool isActive;

  League({
    required this.id,
    required this.name,
    required this.isActive,
    this.providerLeagueId,
    this.country,
    this.tier,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: (json['id'] ?? '').toString(),
      providerLeagueId: json['provider_league_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      country: json['country']?.toString(),
      tier: json['tier'] is int ? json['tier'] as int : int.tryParse(json['tier']?.toString() ?? ''),
      isActive: json['is_active'] == true,
    );
  }
}
