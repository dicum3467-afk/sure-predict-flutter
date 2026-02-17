class PredictionPick {
  final String label; // "1", "X", "2"
  final double prob;  // 0..1

  const PredictionPick({required this.label, required this.prob});

  int get percent => (prob * 100).round();
}

class PredictionLite {
  final int fixtureId;

  final double? pHome;
  final double? pDraw;
  final double? pAway;

  final String? winnerSide; // "home"|"away"|"draw"|null
  final String? winnerName;
  final String? winnerComment;

  final String? advice;
  final String? underOver;
  final String? btts;
  final String? predictedScore;

  final int confidence;
  final PredictionPick? topPick;

  const PredictionLite({
    required this.fixtureId,
    required this.pHome,
    required this.pDraw,
    required this.pAway,
    required this.winnerSide,
    required this.winnerName,
    required this.winnerComment,
    required this.advice,
    required this.underOver,
    required this.btts,
    required this.predictedScore,
    required this.confidence,
    required this.topPick,
  });

  bool get has1x2 => pHome != null && pDraw != null && pAway != null;

  List<PredictionPick> get picks {
    final list = <PredictionPick>[];
    if (pHome != null) list.add(PredictionPick(label: '1', prob: pHome!));
    if (pDraw != null) list.add(PredictionPick(label: 'X', prob: pDraw!));
    if (pAway != null) list.add(PredictionPick(label: '2', prob: pAway!));
    list.sort((a, b) => b.prob.compareTo(a.prob));
    return list;
  }

  factory PredictionLite.fromApiFootballPrediction({
    required int fixtureId,
    required Map<String, dynamic> obj,
  }) {
    final pred = (obj['predictions'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final percent = (pred['percent'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    double? parsePct(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      final cleaned = s.replaceAll('%', '');
      final numVal = double.tryParse(cleaned);
      if (numVal == null) return null;
      return (numVal / 100.0).clamp(0.0, 1.0);
    }

    final pHome = parsePct(percent['home']);
    final pDraw = parsePct(percent['draw']);
    final pAway = parsePct(percent['away']);

    final winner = (pred['winner'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final winnerName = winner['name']?.toString();
    final winnerComment = winner['comment']?.toString();

    String? winnerSide;
    if (winnerName != null && winnerName.toLowerCase() == 'draw') {
      winnerSide = 'draw';
    } else {
      final teams = (obj['teams'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final home = (teams['home'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final away = (teams['away'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final wid = (winner['id'] as num?)?.toInt();
      final hid = (home['id'] as num?)?.toInt();
      final aid = (away['id'] as num?)?.toInt();
      if (wid != null && hid != null && wid == hid) winnerSide = 'home';
      if (wid != null && aid != null && wid == aid) winnerSide = 'away';
    }

    final advice = pred['advice']?.toString();
    final underOver = pred['under_over']?.toString();
    final btts = pred['btts']?.toString();

    String? predictedScore;
    final score = (pred['score'] as Map?)?.cast<String, dynamic>();
    if (score != null) {
      predictedScore = score['fulltime']?.toString() ??
          score['halftime']?.toString() ??
          score['exact']?.toString();
    }

    PredictionPick? topPick;
    int confidence = 0;

    final picks = <PredictionPick>[];
    if (pHome != null) picks.add(PredictionPick(label: '1', prob: pHome));
    if (pDraw != null) picks.add(PredictionPick(label: 'X', prob: pDraw));
    if (pAway != null) picks.add(PredictionPick(label: '2', prob: pAway));
    picks.sort((a, b) => b.prob.compareTo(a.prob));

    if (picks.isNotEmpty) {
      topPick = picks.first;
      final top = picks[0].prob;
      final second = picks.length > 1 ? picks[1].prob : 0.0;

      final base = top * 60.0;
      final gap = (top - second).clamp(0.0, 1.0) * 80.0;
      confidence = (base + gap).round().clamp(0, 100);
    }

    return PredictionLite(
      fixtureId: fixtureId,
      pHome: pHome,
      pDraw: pDraw,
      pAway: pAway,
      winnerSide: winnerSide,
      winnerName: winnerName,
      winnerComment: winnerComment,
      advice: advice,
      underOver: underOver,
      btts: btts,
      predictedScore: predictedScore,
      confidence: confidence,
      topPick: topPick,
    );
  }

  String format1X2() {
    if (!has1x2) return '—';
    final a = (pHome! * 100).round();
    final d = (pDraw! * 100).round();
    final b = (pAway! * 100).round();
    return '1 $a% • X $d% • 2 $b%';
  }
}
