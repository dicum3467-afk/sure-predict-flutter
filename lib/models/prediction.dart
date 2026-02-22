class Prediction {
  final String providerFixtureId;

  final double? pHome;
  final double? pDraw;
  final double? pAway;

  final double? pBtts;
  final double? pOver25;
  final double? pUnder25;

  final String? computedAt;

  const Prediction({
    required this.providerFixtureId,
    this.pHome,
    this.pDraw,
    this.pAway,
    this.pBtts,
    this.pOver25,
    this.pUnder25,
    this.computedAt,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    double? _d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Prediction(
      providerFixtureId: (json['provider_fixture_id'] ?? '').toString(),
      pHome: _d(json['p_home']),
      pDraw: _d(json['p_draw']),
      pAway: _d(json['p_away']),
      pBtts: _d(json['p_btts']),
      pOver25: _d(json['p_over25']),
      pUnder25: _d(json['p_under25']),
      computedAt: json['computed_at']?.toString(),
    );
  }

  int? get bestIndex {
    final a = pHome;
    final b = pDraw;
    final c = pAway;
    if (a == null && b == null && c == null) return null;
    final va = a ?? -1;
    final vb = b ?? -1;
    final vc = c ?? -1;
    if (va >= vb && va >= vc) return 0;
    if (vb >= va && vb >= vc) return 1;
    return 2;
  }
}
