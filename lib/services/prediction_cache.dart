import 'dart:math';

import '../api/api_football.dart';
import '../models/fixture.dart';

class PredictionLite {
  final String topPick; // "1" / "X" / "2"
  final int confidence; // 0..100
  final double pHome; // 0..1
  final double pDraw; // 0..1
  final double pAway; // 0..1
  final String sourceTag; // "DATA" (din API predictions) / "BASE" (fallback)
  final String extras; // text scurt

  const PredictionLite({
    required this.topPick,
    required this.confidence,
    required this.pHome,
    required this.pDraw,
    required this.pAway,
    required this.sourceTag,
    required this.extras,
  });
}

class PredictionCache {
  final ApiFootball api;
  final Map<int, PredictionLite?> _cache = {};
  final Map<int, Future<PredictionLite?>> _inflight = {};

  PredictionCache({required this.api});

  void clear() {
    _cache.clear();
    _inflight.clear();
  }

  Future<PredictionLite?> getForFixture(FixtureLite f) async {
    final id = f.id;
    if (_cache.containsKey(id)) return _cache[id];
    if (_inflight.containsKey(id)) return _inflight[id]!;

    final future = _compute(f).then((value) {
      _cache[id] = value;
      _inflight.remove(id);
      return value;
    });

    _inflight[id] = future;
    return future;
  }

  // ----------------- Core -----------------

  Future<PredictionLite?> _compute(FixtureLite f) async {
    // dacă lipsesc IDs pentru teams, putem rula doar DATA (predictions) sau fallback simplu.
    final hasTeams = f.homeId > 0 && f.awayId > 0;
    const tz = 'Europe/Bucharest';

    // 1) try DATA predictions first (cel mai bun)
    final predRes = await api.getPredictions(f.id);
    if (predRes.isOk && predRes.data != null) {
      final parsed = _parsePredictionsResponse(predRes.data!);
      if (parsed != null) return parsed;
    }

    // 2) fallback BASE smart confidence (form + h2h + context)
    if (!hasTeams) {
      return _baseFallbackNoTeams(f);
    }

    // Run in parallel: last fixtures for each team + h2h
    final futures = await Future.wait([
      api.lastFixturesForTeam(teamId: f.homeId, last: 8, timezone: tz),
      api.lastFixturesForTeam(teamId: f.awayId, last: 8, timezone: tz),
      api.headToHead(homeTeamId: f.homeId, awayTeamId: f.awayId, last: 5, timezone: tz),
    ]);

    final homeLastRes = futures[0] as ApiResult<List<Map<String, dynamic>>>;
    final awayLastRes = futures[1] as ApiResult<List<Map<String, dynamic>>>;
    final h2hRes = futures[2] as ApiResult<List<Map<String, dynamic>>>;

    final homeLast = (homeLastRes.isOk ? (homeLastRes.data ?? const []) : const <Map<String, dynamic>>[]);
    final awayLast = (awayLastRes.isOk ? (awayLastRes.data ?? const []) : const <Map<String, dynamic>>[]);
    final h2h = (h2hRes.isOk ? (h2hRes.data ?? const []) : const <Map<String, dynamic>>[]);

    return _buildSmartConfidence(
      f: f,
      homeLast: homeLast,
      awayLast: awayLast,
      h2h: h2h,
    );
  }

  // ----------------- DATA parser -----------------

  PredictionLite? _parsePredictionsResponse(Map<String, dynamic> item) {
    // API-Football /predictions: item are keys: "predictions", "teams", "comparison", etc.
    final predictions = item['predictions'];
    if (predictions is! Map) return null;

    // winner can be {"id":..,"name":..,"comment":"Win or draw"} or null
    final winner = predictions['winner'];

    // percent: {"home":"45%","draw":"26%","away":"29%"} (uneori)
    final percent = predictions['percent'];

    double ph = 0.0, pd = 0.0, pa = 0.0;
    if (percent is Map) {
      ph = _pctTo01(percent['home']);
      pd = _pctTo01(percent['draw']);
      pa = _pctTo01(percent['away']);
      final sum = ph + pd + pa;
      if (sum > 0) {
        ph /= sum;
        pd /= sum;
        pa /= sum;
      }
    }

    // top pick
    String top = 'X';
    if (winner is Map && winner['id'] != null) {
      // we don't know home/away mapping from winner id here safely without team ids;
      // but the API often sets winner.name. We'll infer via string compare later if available.
      // fallback: choose max probability if we have it
      top = _pickFromProbs(ph, pd, pa);
    } else {
      top = _pickFromProbs(ph, pd, pa);
    }

    // confidence – use max(prob)*100 if available else a conservative 55
    final conf = (max(ph, max(pd, pa)) * 100).round().clamp(0, 100);

    // extras: advice (string) if present
    final advice = predictions['advice'];
    final extra = (advice is String && advice.trim().isNotEmpty) ? advice.trim() : 'Model DATA';

    // if percent missing => return null (we prefer BASE)
    if ((ph + pd + pa) == 0) return null;

    return PredictionLite(
      topPick: top,
      confidence: max(55, conf),
      pHome: ph,
      pDraw: pd,
      pAway: pa,
      sourceTag: 'DATA',
      extras: extra,
    );
  }

  double _pctTo01(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return (v / 100.0).clamp(0.0, 1.0);
    if (v is String) {
      final s = v.replaceAll('%', '').trim();
      final n = double.tryParse(s);
      if (n == null) return 0.0;
      return (n / 100.0).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  // ----------------- BASE fallback -----------------

  PredictionLite _baseFallbackNoTeams(FixtureLite f) {
    // simplu: ușor avantaj home
    final ph = 0.40;
    final pd = 0.30;
    final pa = 0.30;
    final top = _pickFromProbs(ph, pd, pa);
    return PredictionLite(
      topPick: top,
      confidence: 52,
      pHome: ph,
      pDraw: pd,
      pAway: pa,
      sourceTag: 'BASE',
      extras: 'Fallback (IDs echipe lipsă)',
    );
  }

  PredictionLite _buildSmartConfidence({
    required FixtureLite f,
    required List<Map<String, dynamic>> homeLast,
    required List<Map<String, dynamic>> awayLast,
    required List<Map<String, dynamic>> h2h,
  }) {
    // Compute form score: points per match + goal diff
    final homeForm = _formScore(teamId: f.homeId, fixtures: homeLast);
    final awayForm = _formScore(teamId: f.awayId, fixtures: awayLast);

    // h2h tilt
    final h2hTilt = _h2hTilt(homeId: f.homeId, awayId: f.awayId, fixtures: h2h);

    // baseline probabilities
    double ph = 0.38;
    double pd = 0.30;
    double pa = 0.32;

    // apply form boost
    final diff = (homeForm - awayForm).clamp(-1.0, 1.0);
    ph += 0.12 * diff;
    pa -= 0.12 * diff;

    // apply h2h tilt (small)
    ph += 0.06 * h2hTilt;
    pa -= 0.06 * h2hTilt;

    // normalize + clamp
    ph = ph.clamp(0.10, 0.78);
    pa = pa.clamp(0.10, 0.78);
    pd = (1.0 - (ph + pa)).clamp(0.10, 0.45);

    final sum = ph + pd + pa;
    ph /= sum;
    pd /= sum;
    pa /= sum;

    final top = _pickFromProbs(ph, pd, pa);

    final conf = _smartConfidencePercent(
      ph: ph,
      pd: pd,
      pa: pa,
      formDiff: diff,
      h2hTilt: h2hTilt,
      sampleHome: homeLast.length,
      sampleAway: awayLast.length,
      sampleH2h: h2h.length,
    );

    final extras = _extrasText(
      homeForm: homeForm,
      awayForm: awayForm,
      h2hTilt: h2hTilt,
      sampleHome: homeLast.length,
      sampleAway: awayLast.length,
      sampleH2h: h2h.length,
    );

    return PredictionLite(
      topPick: top,
      confidence: conf,
      pHome: ph,
      pDraw: pd,
      pAway: pa,
      sourceTag: 'BASE',
      extras: extras,
    );
  }

  double _formScore({
    required int teamId,
    required List<Map<String, dynamic>> fixtures,
  }) {
    // return ~0..1
    if (fixtures.isEmpty) return 0.50;

    double points = 0;
    double gdSum = 0;
    int n = 0;

    for (final fx in fixtures) {
      final teams = fx['teams'];
      final goals = fx['goals'];
      if (teams is! Map || goals is! Map) continue;

      final home = teams['home'];
      final away = teams['away'];
      if (home is! Map || away is! Map) continue;

      final hid = _asInt(home['id']);
      final aid = _asInt(away['id']);

      final gh = _asInt(goals['home']);
      final ga = _asInt(goals['away']);
      if (gh < 0 || ga < 0) continue;

      bool isHome = hid == teamId;
      bool isAway = aid == teamId;
      if (!isHome && !isAway) continue;

      n += 1;

      final my = isHome ? gh : ga;
      final opp = isHome ? ga : gh;
      gdSum += (my - opp);

      if (my > opp) points += 3;
      else if (my == opp) points += 1;
      else points += 0;
    }

    if (n == 0) return 0.50;

    final ppm = points / (n * 3); // 0..1
    final gdNorm = (gdSum / n); // goal diff per match

    // map gd to [-1..1] approx using tanh-ish clamp
    final gdScaled = (gdNorm / 2.5).clamp(-1.0, 1.0);

    // weighted blend
    final score = (0.72 * ppm + 0.28 * (0.5 + 0.5 * gdScaled)).clamp(0.0, 1.0);
    return score;
  }

  double _h2hTilt({
    required int homeId,
    required int awayId,
    required List<Map<String, dynamic>> fixtures,
  }) {
    // returns -1..1; positive => favors home
    if (fixtures.isEmpty) return 0.0;

    int homeWins = 0;
    int awayWins = 0;
    int draws = 0;

    for (final fx in fixtures) {
      final teams = fx['teams'];
      final goals = fx['goals'];
      if (teams is! Map || goals is! Map) continue;

      final home = teams['home'];
      final away = teams['away'];
      if (home is! Map || away is! Map) continue;

      final hid = _asInt(home['id']);
      final aid = _asInt(away['id']);
      if (!((hid == homeId && aid == awayId) || (hid == awayId && aid == homeId))) continue;

      final gh = _asInt(goals['home']);
      final ga = _asInt(goals['away']);
      if (gh < 0 || ga < 0) continue;

      // Determine winner relative to homeId (our match home)
      int matchHomeGoals;
      int matchAwayGoals;
      if (hid == homeId) {
        matchHomeGoals = gh;
        matchAwayGoals = ga;
      } else {
        // swapped
        matchHomeGoals = ga;
        matchAwayGoals = gh;
      }

      if (matchHomeGoals > matchAwayGoals) homeWins++;
      else if (matchHomeGoals < matchAwayGoals) awayWins++;
      else draws++;
    }

    final total = homeWins + awayWins + draws;
    if (total == 0) return 0.0;

    final tilt = ((homeWins - awayWins) / total).clamp(-1.0, 1.0);
    return tilt;
  }

  int _smartConfidencePercent({
    required double ph,
    required double pd,
    required double pa,
    required double formDiff, // -1..1
    required double h2hTilt, // -1..1
    required int sampleHome,
    required int sampleAway,
    required int sampleH2h,
  }) {
    final top = max(ph, max(pd, pa)); // 0..1

    // base from probability separation
    double base = 45 + (top * 40); // 45..85

    // boost if form strongly favors one side
    base += (formDiff.abs() * 8);

    // boost if h2h consistent
    base += (h2hTilt.abs() * 5);

    // penalty for low samples
    final sample = min(sampleHome, sampleAway);
    if (sample < 4) base -= 8;
    else if (sample < 6) base -= 4;

    if (sampleH2h == 0) base -= 3;

    // draw-heavy -> reduce confidence slightly
    if (pd > 0.34) base -= 4;

    // clamp to int 0..100
    final v = base.round().clamp(0, 100);
    return v;
  }

  String _extrasText({
    required double homeForm,
    required double awayForm,
    required double h2hTilt,
    required int sampleHome,
    required int sampleAway,
    required int sampleH2h,
  }) {
    String formLabel(double v) {
      if (v >= 0.72) return 'foarte bună';
      if (v >= 0.60) return 'bună';
      if (v >= 0.48) return 'medie';
      return 'slabă';
    }

    final form = 'Formă: H ${formLabel(homeForm)} vs A ${formLabel(awayForm)}';
    final h2h = sampleH2h == 0
        ? 'H2H: N/A'
        : (h2hTilt > 0.15
            ? 'H2H: avantaj home'
            : (h2hTilt < -0.15 ? 'H2H: avantaj away' : 'H2H: echilibrat'));

    final samples = 'Samples: H $sampleHome / A $sampleAway / H2H $sampleH2h';
    return '$form • $h2h • $samples';
  }

  String _pickFromProbs(double ph, double pd, double pa) {
    if (ph >= pd && ph >= pa) return '1';
    if (pa >= ph && pa >= pd) return '2';
    return 'X';
    }

  int _asInt(dynamic v) {
    if (v == null) return -1;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? -1;
    return -1;
  }
}
