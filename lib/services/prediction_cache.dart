import 'dart:async';
import 'dart:math';

import '../api/api_football.dart';
import '../models/fixture.dart';

class PredictionLite {
  final double pHome; // 0..1
  final double pDraw; // 0..1
  final double pAway; // 0..1
  final int confidence; // 0..100
  final String topPick; // "1", "X", "2"
  final String label; // text scurt (ex: "1 • 62%")

  const PredictionLite({
    required this.pHome,
    required this.pDraw,
    required this.pAway,
    required this.confidence,
    required this.topPick,
    required this.label,
  });
}

/// Cache + throttle pentru predictions pe listă.
class PredictionCache {
  final ApiFootball api;

  /// max requests active simultan (nu supraîncarci API)
  final int maxConcurrent;

  /// cache TTL
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

    // if already loading, return same future
    final inflight = _inFlight[f.id];
    if (inflight != null) return inflight;

    final completer = Completer<PredictionLite?>();
    _inFlight[f.id] = completer.future;

    _queue.add(f.id);
    _pump(f, completer);

    return completer.future;
  }

  void _pump(FixtureLite f, Completer<PredictionLite?> completer) {
    // dacă nu e în fața cozii, așteaptă
    if (_queue.isEmpty || _queue.first != f.id) {
      // re-check soon
      Timer(const Duration(milliseconds: 120), () => _pump(f, completer));
      return;
    }

    if (_active >= maxConcurrent) {
      Timer(const Duration(milliseconds: 120), () => _pump(f, completer));
      return;
    }

    _queue.removeAt(0);
    _active++;

    _run(f).then((value) {
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

  Future<PredictionLite?> _run(FixtureLite f) async {
    // 1) încearcă endpoint predictions (dacă planul îl suportă)
    final p = await api.getPredictions(f.id);
    if (p.isOk && p.data != null) {
      final lite = _fromApiPredictions(p.data!, f);
      if (lite != null) return lite;
    }

    // 2) fallback: AI simplu pe formă (ultimele 5) + H2H (ultimele 3)
    // (nu facem prea multe request-uri — doar dacă userul scrollează până acolo)
    final h = await api.lastFixturesForTeam(teamId: f.homeId, last: 5, timezone: 'Europe/Bucharest');
    final a = await api.lastFixturesForTeam(teamId: f.awayId, last: 5, timezone: 'Europe/Bucharest');
    final x = await api.headToHead(homeTeamId: f.homeId, awayTeamId: f.awayId, last: 3);

    if (!h.isOk || !a.isOk) return null;

    final fh = _formPoints(h.data ?? [], f.homeId);
    final fa = _formPoints(a.data ?? [], f.awayId);
    final bias = (fh - fa).clamp(-6, 6);

    // baza: home advantage mic + bias din formă
    double pHome = 0.40 + bias * 0.03;
    double pDraw = 0.28 - bias.abs() * 0.01;
    double pAway = 1 - pHome - pDraw;

    if ((x.data ?? []).isNotEmpty) {
      final h2h = _h2hDelta(x.data ?? [], f.homeId, f.awayId).clamp(-2, 2);
      pHome += h2h * 0.02;
      pAway -= h2h * 0.02;
    }

    // clamp + renormalize
    pHome = pHome.clamp(0.05, 0.90);
    pDraw = pDraw.clamp(0.05, 0.60);
    pAway = pAway.clamp(0.05, 0.90);
    final s = pHome + pDraw + pAway;
    pHome /= s; pDraw /= s; pAway /= s;

    final top = _topPick(pHome, pDraw, pAway);
    final topVal = max(pHome, max(pDraw, pAway));
    final conf = (40 + topVal * 60).round().clamp(0, 100);

    return PredictionLite(
      pHome: pHome,
      pDraw: pDraw,
      pAway: pAway,
      confidence: conf,
      topPick: top,
      label: '$top • $conf%',
    );
  }

  PredictionLite? _fromApiPredictions(Map<String, dynamic> root, FixtureLite f) {
    try {
      final percent = (root['percent'] ?? {}) as Map<String, dynamic>;

      double pHome = _parsePercent(percent['home']);
      double pDraw = _parsePercent(percent['draw']);
      double pAway = _parsePercent(percent['away']);

      if (pHome.isNaN || pDraw.isNaN || pAway.isNaN) return null;

      // convert 0..100 -> 0..1
      pHome = (pHome / 100).clamp(0.0, 1.0);
      pDraw = (pDraw / 100).clamp(0.0, 1.0);
      pAway = (pAway / 100).clamp(0.0, 1.0);

      // renormalize
      final s = pHome + pDraw + pAway;
      if (s <= 0) return null;
      pHome /= s; pDraw /= s; pAway /= s;

      final top = _topPick(pHome, pDraw, pAway);
      final topVal = max(pHome, max(pDraw, pAway));
      final conf = (45 + topVal * 55).round().clamp(0, 100);

      return PredictionLite(
        pHome: pHome,
        pDraw: pDraw,
        pAway: pAway,
        confidence: conf,
        topPick: top,
        label: '$top • $conf%',
      );
    } catch (_) {
      return null;
    }
  }

  double _parsePercent(dynamic v) {
    final s = (v ?? '').toString().replaceAll('%', '').trim();
    return double.tryParse(s) ?? double.nan;
  }

  String _topPick(double pHome, double pDraw, double pAway) {
    if (pHome >= pDraw && pHome >= pAway) return '1';
    if (pAway >= pHome && pAway >= pDraw) return '2';
    return 'X';
  }

  int _formPoints(List<Map<String, dynamic>> fixtures, int teamId) {
    int points = 0;
    int counted = 0;

    for (final item in fixtures) {
      if (counted >= 5) break;

      final fixture = (item['fixture'] ?? {}) as Map<String, dynamic>;
      final status = (fixture['status'] ?? {}) as Map<String, dynamic>;
      final short = (status['short'] ?? '').toString();
      if (!(short == 'FT' || short == 'AET' || short == 'PEN')) continue;

      final teams = (item['teams'] ?? {}) as Map<String, dynamic>;
      final goals = (item['goals'] ?? {}) as Map<String, dynamic>;
      final home = (teams['home'] ?? {}) as Map<String, dynamic>;
      final away = (teams['away'] ?? {}) as Map<String, dynamic>;

      final hid = home['id'];
      final gh = goals['home'] is int ? goals['home'] as int : int.tryParse('${goals['home']}') ?? 0;
      final ga = goals['away'] is int ? goals['away'] as int : int.tryParse('${goals['away']}') ?? 0;

      final isHome = hid == teamId;
      final my = isHome ? gh : ga;
      final op = isHome ? ga : gh;

      if (my > op) points += 3;
      else if (my == op) points += 1;

      counted++;
    }

    return points; // 0..15
  }

  int _h2hDelta(List<Map<String, dynamic>> fixtures, int homeId, int awayId) {
    int homeWins = 0, awayWins = 0;
    int counted = 0;

    for (final item in fixtures) {
      if (counted >= 3) break;

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

      int myHome, myAway;
      if (hid == homeId && aid == awayId) {
        myHome = gh; myAway = ga;
      } else if (hid == awayId && aid == homeId) {
        myHome = ga; myAway = gh;
      } else {
        continue;
      }

      if (myHome > myAway) homeWins++;
      else if (myHome < myAway) awayWins++;

      counted++;
    }

    return homeWins - awayWins;
  }
}

class _CacheEntry {
  final PredictionLite value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
}
