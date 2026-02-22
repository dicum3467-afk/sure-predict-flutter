import 'package:flutter/foundation.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  final SurePredictService _service;

  FixturesStore(this._service);

  // ====== STATE EXPUS UI ======
  bool isLoading = false;
  bool isLoadingMore = false;

  String? error;

  // UI-ul tău cere store.fixtures
  final List<Map<String, dynamic>> fixtures = [];

  // paging
  int limit = 50;
  int offset = 0;
  bool hasMore = true;

  // filter/params
  String? _leagueId;

  Future<void> loadInitial(String leagueId) async {
    _leagueId = leagueId;
    offset = 0;
    hasMore = true;
    fixtures.clear();
    error = null;

    isLoading = true;
    notifyListeners();

    try {
      final data = await _service.getFixtures(
        leagueId: leagueId,
        limit: limit,
        offset: offset,
      );

      fixtures
        ..clear()
        ..addAll(data);

      hasMore = data.length >= limit;
      offset = fixtures.length;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final leagueId = _leagueId;
    if (leagueId == null) return;
    await loadInitial(leagueId);
  }

  Future<void> loadMore() async {
    final leagueId = _leagueId;
    if (leagueId == null) return;

    if (isLoading || isLoadingMore) return;
    if (!hasMore) return;

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.getFixtures(
        leagueId: leagueId,
        limit: limit,
        offset: offset,
      );

      fixtures.addAll(data);
      hasMore = data.length >= limit;
      offset = fixtures.length;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
