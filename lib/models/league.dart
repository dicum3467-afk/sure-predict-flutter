class League {
  final String id;
  final String providerLeagueId;
  final String name;
  final String? country;
  final int? tier;
  final bool isActive;

  League({
    required this.id,
    required this.providerLeagueId,
    required this.name,
    required this.country,
    required this.tier,
    required this.isActive,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: (json['id'] ?? '').toString(),
      providerLeagueId: (json['provider_league_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      country: json['country']?.toString(),
      tier: json['tier'] is int ? json['tier'] as int : int.tryParse('${json['tier']}'),
      isActive: json['is_active'] == true,
    );
  }
}
