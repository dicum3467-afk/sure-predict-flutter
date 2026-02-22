import 'dart:async';
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

  // query
  String runType = 'initial';

  // filtre
  String? status;
  String? dateFrom; // YYYY-MM-DD
  String? dateTo;   // YYYY-MM-DD

  // intern
  bool _hasMore = true;
  int _lastBatchCount = 0;

  bool get hasMore => _hasMore && !loading;

  /// Setează automat range-ul (azi..azi+days)
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

  /// Încarcă pentru o singură ligă (reset offset)
  Future<void> loadForLeague(
    String leagueId, {
    bool cacheFirst = true,
  }) async {
    offset = 0;
    _hasMore = true;
    _lastBatchCount = 0;
    fixtures.clear();
    notifyListeners();

    await loadForLeagues([leagueId], cacheFirst: cacheFirst);
  }

  /// Încarcă pentru mai multe ligi (reset offset dacă fixtures e gol)
  Future<void> loadForLeagues(
    List<String> leagueIds, {
    bool cacheFirst = true,
  }) async {
    // Dacă e deja în load, nu porni altul
    if (loading) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      const maxAttempts = 3;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final path = _service.buildFixturesPath(
            leagueIds: leagueIds,
            runType: runType,
            limit: limit,
            offset: offset,
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );

          final batch = await _service.getFixturesByUrl(path);

          // dacă offset == 0 -> replace, altfel append
          if (offset == 0) {
            fixtures
              ..clear()
              ..addAll(batch);
          } else {
            fixtures.addAll(batch);
          }

          _lastBatchCount = batch.length;
          // hasMore dacă am primit fix "limit" rezultate
          _hasMore = _lastBatchCount >= limit;

          error = null;
          break;
        } catch (e) {
          if (attempt == maxAttempts) rethrow;

          // delay pentru cold start / rețea
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    } catch (e) {
      error = e.toString();
      // dacă e prima pagină și a picat, păstrează lista goală
      if (offset == 0) fixtures.clear();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Forțează refresh (offset=0)
  Future<void> refresh(
    List<String> leagueIds, {
    bool cacheFirst = false,
  }) async {
    offset = 0;
    _hasMore = true;
    _lastBatchCount = 0;
    fixtures.clear();
    notifyListeners();

    await loadForLeagues(leagueIds, cacheFirst: cacheFirst);
  }

  /// Pagination: încarcă pagina următoare (offset += limit)
  Future<void> loadMore(
    List<String> leagueIds, {
    bool cacheFirst = false,
  }) async {
    if (loading) return;
    if (!_hasMore) return;

    offset += limit;
    await loadForLeagues(leagueIds, cacheFirst: cacheFirst);

    // dacă n-a venit nimic, oprește hasMore ca să nu tot ceară
    if (_lastBatchCount == 0) {
      _hasMore = false;
      notifyListeners();
    }
  }

  // helpers
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

    _hasMore = true;
    _lastBatchCount = 0;

    notifyListeners();
  }
}
