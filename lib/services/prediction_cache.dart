import '../api/api_football.dart';
import '../models/prediction_lite.dart';

class PredictionCache {
  final Map<int, PredictionLite> _cache = {};
  final Map<int, Future<PredictionLite?>> _inflight = {};

  PredictionLite? peek(int fixtureId) => _cache[fixtureId];

  Future<PredictionLite?> get({
    required ApiFootball api,
    required int fixtureId,
  }) {
    final hit = _cache[fixtureId];
    if (hit != null) return Future.value(hit);

    final running = _inflight[fixtureId];
    if (running != null) return running;

    final fut = _load(api, fixtureId);
    _inflight[fixtureId] = fut;
    return fut;
  }

  Future<PredictionLite?> _load(ApiFootball api, int fixtureId) async {
    try {
      final res = await api.getPredictionLite(fixtureId);
      if (res.isOk && res.data != null) {
        _cache[fixtureId] = res.data!;
        return res.data!;
      }
      return null;
    } finally {
      _inflight.remove(fixtureId);
    }
  }

  void clear() {
    _cache.clear();
    _inflight.clear();
  }
}
