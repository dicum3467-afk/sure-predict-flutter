import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;

  final List<FixtureItem> fixtures = [];

  // paging
  int limit = 50;
  int offset = 0;

  // filtrare
  String runType = 'initial';
  String? status;
  String? dateFrom; // YYYY-MM-DD
  String? dateTo;   // YYYY-MM-DD

  // intern: ultimul batch pentru hasMore
  int _lastBatchCount = 0;

  bool get hasMore => _lastBatchCount >= limit;

  // set default range: azi -> azi + days
  void setDefaultDateRange({int days = 7}) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(Duration(days: days));

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    dateFrom = fmt(from);
    dateTo = fmt(to);
    notifyListeners();
  }

  Future<void> loadForLeague(String leagueId, {bool cacheFirst = false}) async {
    await loadForLeagues([leagueId], cacheFirst: cacheFirst);
  }

  Future<void> refresh({required String leagueId, bool cacheFirst = false}) async {
    // reset paging, păstrăm filtrele
    offset = 0;
    fixtures.clear();
    _lastBatchCount = 0;
    notifyListeners();

    await loadForLeague(leagueId, cacheFirst: cacheFirst);
  }

  Future<void> loadMore({
    required String leagueId,
    bool cacheFirst = false,
  }) async {
    if (loading) return;
    if (!hasMore && fixtures.isNotEmpty) return;

    offset += limit;
    notifyListeners();

    await loadForLeague(leagueId, cacheFirst: cacheFirst);
  }

  Future<void> loadForLeagues(
    List<String> leagueUuids, {
    bool cacheFirst = false,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      // retry pentru cold start / rețea instabilă
      const maxAttempts = 3;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final path = _service.buildFixturesPath(
            leagueIds: leagueUuids,
            runType: runType,
            limit: limit,
            offset: offset,
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );

          final batch = await _service.getFixturesByUrl(path);

          _lastBatchCount = batch.length;

          if (offset == 0) {
            fixtures
              ..clear()
              ..addAll(batch);
          } else {
            fixtures.addAll(batch);
          }

          error = null;
          break;
        } catch (e) {
          if (attempt == maxAttempts) rethrow;
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    } catch (e) {
      error = e.toString();
      if (offset == 0) {
        fixtures.clear();
      }
      _lastBatchCount = 0;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setPaging({int? newLimit, int? newOffset}) {
    if (newLimit != null) limit = newLimit;
    if (newOffset != null) offset = newOffset;
    notifyListeners();
  }

  void setFilters({
    String? newStatus,
    String? newDateFrom,
    String? newDateTo,
  }) {
    status = newStatus;
    dateFrom = newDateFrom;
    dateTo = newDateTo;
    notifyListeners();
  }

  void setRunType(String value) {
    runType = value;
    notifyListeners();
  }

  void reset() {
    fixtures.clear();
    error = null;
    loading = false;

    limit = 50;
    offset = 0;
    runType = 'initial';

    status = null;
    dateFrom = null;
    dateTo = null;

    _lastBatchCount = 0;

    notifyListeners();
  }
}
