import 'dart:async';
import 'dart:math';

import '../api/api_football.dart';
import '../models/fixture.dart';

class PredictionLite {
  final double pHome; // 0..1
  final double pDraw; // 0..1
  final double pAway; // 0..1

  final double pBttsYes; // 0..1
  final double pOver25; // 0..1

  final int confidence; // 0..100
  final String topPick; // "1", "X", "2"
  final String label; // ex: "1 • 67%"
  final String extras; // ex: "BTTS 54% • O2.5 48%"

  /// "DATA" = are suficientă formă/H2H
  /// "BASE" = fallback (date puține / lipsă)
  final String sourceTag;

  const PredictionLite({
    required this.pHome,
    required this.pDraw,
    required this.pAway,
    required this.pBttsYes,
    required this.pOver25,
    required this.confidence,
    required this.topPick,
    required this.label,
    required this.extras,
    required this.sourceTag,
  });
}

/// Cache + throttle pentru predicții pe listă (AI 2.0 + Smart Confidence).
class PredictionCache {
  final ApiFootball api;
  final int maxConcurrent;
  final Duration ttl;

  final _cache = <int, _CacheEntry>{};
  final _inFlight = <int, Future<PredictionLite?>>{};
  int _active = 0;
  final _queue = <int>[];

  PredictionCache({
    required this.api,
    this.maxConcurrent = 2,
    this.ttl = const Duration(minutes: 30),
  });

  void clear() => _cache.clear();

  PredictionLite? peek(int fixtureId) {
    final e = _cache[fixtureId];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expiresAt)) {
      _cache.remove(fixtureId);
      return null;
    }
    return e.value;
  }

  Future<PredictionLite?> getForFixture(FixtureLite f) async {
    final cached = peek(f.id);
    if (cached != null) return cached;

    final inflight = _inFlight[f.id];
    if (inflight != null) return inflight;

    final completer = Completer<PredictionLite?>();
    _inFlight[f.id] = completer.future;

    _queue.add(f.id);
    _pump(f, completer);

    return completer.future;
  }

  void _pump(FixtureLite f, Completer<PredictionLite?> completer) {
    if (_queue.isEmpty || _queue.first != f.id) {
      Timer(const Duration(milliseconds: 120), () => _pump(f, completer));
      return;
    }
    if (_active >= maxConcurrent) {
      Timer(const Duration(milliseconds: 120), () => _pump(f, completer));
      return;
    }

    _queue.removeAt(0);
    _active++;

    _runAi(f).then((value) {
      if (value != null) {
        _cache[f.id] = _CacheEntry(value, DateTime.now().add(ttl));
      }
      completer.complete(value);
    }).catchError((_) {
      completer.complete(null);
    }).whenComplete(() {
      _active--;
      _inFlight.remove(f.id);
    });
  }

  Future<PredictionLite?> _runAi(FixtureLite f) async {
    if (!api.hasKey) return null;

    const tz = 'Europe/Bucharest';

    List<Map<String, dynamic>> homeData = const [];
    List<Map<String, dynamic>> awayData = const [];
    List<Map<String, dynamic>> h2hData = const [];

    try {
      final homeLast = await api.lastFixturesForTeam(teamId: f.homeId, last: 8, timezone: tz);
      if (homeLast.isOk && homeLast.data != null) homeData = homeLast.data!;
    } catch (_) {}

    try {
      final awayLast = await api.lastFixturesForTeam(teamId: f.awayId, last: 8, timezone: tz);
      if (awayLast.isOk && awayLast.data != null) awayData = awayLast.data!;
    } catch (_) {}

    try {
      final h2h = await api.headToHead(homeTeamId: f.homeId, awayTeamId: f.awayId, last: 5);
      if (h2h.isOk && h2h.data != null) h2hData = h2h.data!;
    } catch (_) {}

    // Baseline neutru dacă nu avem date
    final hStats = homeData.isNotEmpty
        ? _teamStats(homeData, f.homeId)
        : _TeamStats(counted: 0, ppg: 1.35, gfPerGame: 1.25, gaPerGame: 1.25, trend: 0.0);

    final aStats = awayData.isNotEmpty
        ? _teamStats(awayData, f.awayId)
        : _TeamStats(counted: 0, ppg: 1.35, gfPerGame: 1.25, gaPerGame: 1.25, trend: 0.0);

    final h2hDelta = h2hData.isNotEmpty ? _h2hDelta(h2hData, f.homeId, f.awayId) : 0;

    // TAG sursă: DATA dacă avem suficientă formă / BASE dacă e fallback
    final totalGames = hStats.counted + aStats.counted;
    final bool strongData = totalGames >= 10; // ~5+5 meciuri reale
    final String sourceTag = strongData ? 'DATA' : 'BASE';

    // --- MODEL: lambda Poisson
    const homeAdv = 0.12;

    final formBoost = (hStats.ppg - aStats.ppg).clamp(-3.0, 3.0) * 0.04;
    final trendBoost = (hStats.trend - aStats.trend).clamp(-1.0, 1.0) * 0.06;
    final h2hBoost = (h2hDelta.clamp(-3, 3)) * 0.02;

    double lambdaHome =
        (0.55 * hStats.gfPerGame + 0.45 * aStats.gaPerGame) + homeAdv + formBoost + trendBoost + h2hBoost;
    double lambdaAway =
        (0.55 * aStats.gfPerGame + 0.45 * hStats.gaPerGame) - homeAdv - formBoost - trendBoost - h2hBoost;

    lambdaHome = lambdaHome.clamp(0.2, 3.2);
    lambdaAway = lambdaAway.clamp(0.2, 3.2);

    // --- 1X2
    final probs = _matchProbsFromPoisson(lambdaHome, lambdaAway, maxGoals: 6);
    final pHome = probs.$1;
    final pDraw = probs.$2;
    final pAway = probs.$3;

    final topPick = _topPick(pHome, pDraw, pAway);
    final topVal = max(pHome, max(pDraw, pAway));
    final second = _secondBest(pHome, pDraw, pAway);
    final margin = (topVal - second).clamp(0.0, 1.0);

    // --- BTTS & O2.5
    final pBttsYes = _pBttsYes(lambdaHome, lambdaAway);
    final pOver25 = _pOver25(lambdaHome, lambdaAway);

    // --- SMART CONFIDENCE (real)
    final conf = _smartConfidence(
      pHome: pHome,
      pDraw: pDraw,
      pAway: pAway,
      lambdaHome: lambdaHome,
      lambdaAway: lambdaAway,
      hStats: hStats,
      aStats: aStats,
      h2hDelta: h2hDelta,
      homeAdv: homeAdv,
      margin: margin,
      topVal: topVal,
      hasH2h: h2hData.isNotEmpty,
    );

    final extras =
        'BTTS ${(pBttsYes * 100).toStringAsFixed(0)}% • O2.5 ${(pOver25 * 100).toStringAsFixed(0)}%';

    return PredictionLite(
      pHome: pHome,
      pDraw: pDraw,
      pAway: pAway,
      pBttsYes: pBttsYes,
      pOver25: pOver25,
      confidence: conf,
      topPick: topPick,
      label: '$topPick • $conf%',
      extras: extras,
      sourceTag: sourceTag,
    );
  }

  // ---------------- SMART CONFIDENCE ----------------

  int _smartConfidence({
    required double pHome,
    required double pDraw,
    required double pAway,
    required double lambdaHome,
    required double lambdaAway,
    required _TeamStats hStats,
    required _TeamStats aStats,
    required int h2hDelta,
    required double homeAdv,
    required double margin,
    required double topVal,
    required bool hasH2h,
  }) {
    final clarity = (topVal * 55) + (margin * 45);

    final ppgDiff = (hStats.ppg - aStats.ppg).clamp(-3.0, 3.0);
    final formScore = (ppgDiff.abs() / 3.0) * 16;

    final trendDiff = (hStats.trend - aStats.trend).clamp(-1.0, 1.0);
    final trendScore = (trendDiff.abs()) * 10;

    final hNet = (hStats.gfPerGame - hStats.gaPerGame).clamp(-3.0, 3.0);
    final aNet = (aStats.gfPerGame - aStats.gaPerGame).clamp(-3.0, 3.0);
    final netDiff = (hNet - aNet).clamp(-3.0, 3.0);
    final netScore = (netDiff.abs() / 3.0) * 12;

    final goalEdge = (lambdaHome - lambdaAway).abs().clamp(0.0, 2.0);
    final goalEdgeScore = (goalEdge / 2.0) * 10;

    final h2hScore = hasH2h ? (h2hDelta.abs().clamp(0, 3) / 3.0) * 6 : 0.0;

    final dataCount = hStats.counted + aStats.counted;
    final dataQuality = (dataCount / 16.0).clamp(0.25, 1.0);
    final dataScore = dataQuality * 12;

    final entropyPenalty = _entropyPenalty(pHome, pDraw, pAway);

    final homeAdvScore = homeAdv * 10;

    double raw =
        18 +
        clarity +
        formScore +
        trendScore +
        netScore +
        goalEdgeScore +
        h2hScore +
        dataScore +
        homeAdvScore -
        entropyPenalty;

    int conf = raw.round().clamp(35, 94);

    if (dataCount <= 4) conf = min(conf, 72);
    if (dataCount == 0) conf = min(conf, 66);

    return conf;
  }

  double _entropyPenalty(double a, double b, double c) {
    double h(double p) => p <= 0 ? 0 : -p * log(p);
    final H = h(a) + h(b) + h(c);
    final norm = ((H - 0.7) / (1.0986 - 0.7)).clamp(0.0, 1.0);
    return norm * 12;
  }

  // -------------------- helpers --------------------

  String _topPick(double pHome, double pDraw, double pAway) {
    if (pHome >= pDraw && pHome >= pAway) return '1';
    if (pAway >= pHome && pAway >= pDraw) return '2';
    return 'X';
  }

  double _secondBest(double a, double b, double c) {
    final list = [a, b, c]..sort();
    return list[1];
  }

  (double, double, double) _matchProbsFromPoisson(double lH, double lA, {int maxGoals = 6}) {
    double pH = 0, pD = 0, pA = 0;
    for (int gh = 0; gh <= maxGoals; gh++) {
      final ph = _pois(gh, lH);
      for (int ga = 0; ga <= maxGoals; ga++) {
        final pa = _pois(ga, lA);
        final p = ph * pa;
        if (gh > ga) pH += p;
        else if (gh == ga) pD += p;
        else pA += p;
      }
    }
    final s = pH + pD + pA;
    if (s <= 0) return (0.33, 0.34, 0.33);
    return (pH / s, pD / s, pA / s);
  }

  double _pBttsYes(double lH, double lA) {
    final pH0 = _pois(0, lH);
    final pA0 = _pois(0, lA);
    final pBoth0 = pH0 * pA0;
    return (1 - pH0 - pA0 + pBoth0).clamp(0.0, 1.0);
  }

  double _pOver25(double lH, double lA) {
    final lt = (lH + lA).clamp(0.1, 8.0);
    final p0 = _pois(0, lt);
    final p1 = _pois(1, lt);
    final p2 = _pois(2, lt);
    final under = (p0 + p1 + p2).clamp(0.0, 1.0);
    return (1 - under).clamp(0.0, 1.0);
  }

  double _pois(int k, double lambda) {
    final e = exp(-lambda);
    double num = 1.0;
    for (int i = 0; i < k; i++) {
      num *= lambda;
    }
    return e * num / _fact(k);
  }

  double _fact(int n) {
    if (n <= 1) return 1.0;
    double r = 1.0;
    for (int i = 2; i <= n; i++) r *= i;
    return r;
  }

  _TeamStats _teamStats(List<Map<String, dynamic>> fixtures, int teamId) {
    int points = 0;
    int counted = 0;
    int gf = 0;
    int ga = 0;

    int pointsFirst = 0, gamesFirst = 0;
    int pointsLast = 0, gamesLast = 0;

    final valid = <_MiniResult>[];

    for (final item in fixtures) {
      if (valid.length >= 8) break;

      final fixture = (item['fixture'] ?? {}) as Map<String, dynamic>;
      final status = (fixture['status'] ?? {}) as Map<String, dynamic>;
      final short = (status['short'] ?? '').toString();
      if (!(short == 'FT' || short == 'AET' || short == 'PEN')) continue;

      final teams = (item['teams'] ?? {}) as Map<String, dynamic>;
      final goals = (item['goals'] ?? {}) as Map<String, dynamic>;
      final home = (teams['home'] ?? {}) as Map<String, dynamic>;

      final hid = home['id'];
      final gh = goals['home'] is int ? goals['home'] as int : int.tryParse('${goals['home']}') ?? 0;
      final gA = goals['away'] is int ? goals['away'] as int : int.tryParse('${goals['away']}') ?? 0;

      final isHome = hid == teamId;
      final my = isHome ? gh : gA;
      final op = isHome ? gA : gh;

      int pts = 0;
      if (my > op) pts = 3;
      else if (my == op) pts = 1;

      valid.add(_MiniResult(gf: my, ga: op, pts: pts));
    }

    for (final r in valid) {
      gf += r.gf;
      ga += r.ga;
      points += r.pts;
      counted++;
    }

    final chrono = valid.reversed.toList();
    for (int i = 0; i < chrono.length; i++) {
      final r = chrono[i];
      if (i < 4) {
        pointsFirst += r.pts;
        gamesFirst++;
      } else {
        pointsLast += r.pts;
        gamesLast++;
      }
    }

    final games = max(counted, 1);
    final ppg = points / games;
    final gfpg = gf / games;
    final gapg = ga / games;

    final ppgFirst = gamesFirst == 0 ? ppg : pointsFirst / gamesFirst;
    final ppgLast = gamesLast == 0 ? ppg : pointsLast / gamesLast;

    final trend = ((ppgLast - ppgFirst) / 3.0).clamp(-1.0, 1.0);

    return _TeamStats(
      counted: counted,
      ppg: ppg,
      gfPerGame: gfpg,
      gaPerGame: gapg,
      trend: trend,
    );
  }

  int _h2hDelta(List<Map<String, dynamic>> fixtures, int homeId, int awayId) {
    int homeWins = 0, awayWins = 0;
    int counted = 0;

    for (final item in fixtures) {
      if (counted >= 5) break;

      final fixture = (item['fixture'] ?? {}) as Map<String, dynamic>;
      final status = (fixture['status'] ?? {}) as Map<String, dynamic>;
      final short = (status['short'] ?? '').toString();
      if (!(short == 'FT' || short == 'AET' || short == 'PEN')) continue;

      final teams = (item['teams'] ?? {}) as Map<String, dynamic>;
      final goals = (item['goals'] ?? {}) as Map<String, dynamic>;
      final th = (teams['home'] ?? {}) as Map<String, dynamic>;
      final ta = (teams['away'] ?? {}) as Map<String, dynamic>;
      final hid = th['id'];
      final aid = ta['id'];

      final gh = goals['home'] is int ? goals['home'] as int : int.tryParse('${goals['home']}') ?? 0;
      final ga = goals['away'] is int ? goals['away'] as int : int.tryParse('${goals['away']}') ?? 0;

      int scoreHome, scoreAway;
      if (hid == homeId && aid == awayId) {
        scoreHome = gh;
        scoreAway = ga;
      } else if (hid == awayId && aid == homeId) {
        scoreHome = ga;
        scoreAway = gh;
      } else {
        continue;
      }

      if (scoreHome > scoreAway) homeWins++;
      else if (scoreHome < scoreAway) awayWins++;

      counted++;
    }

    return homeWins - awayWins;
  }
}

class _MiniResult {
  final int gf;
  final int ga;
  final int pts;
  _MiniResult({required this.gf, required this.ga, required this.pts});
}

class _TeamStats {
  final int counted;
  final double ppg;
  final double gfPerGame;
  final double gaPerGame;
  final double trend; // -1..+1

  _TeamStats({
    required this.counted,
    required this.ppg,
    required this.gfPerGame,
    required this.gaPerGame,
    required this.trend,
  });
}

class _CacheEntry {
  final PredictionLite value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
}
