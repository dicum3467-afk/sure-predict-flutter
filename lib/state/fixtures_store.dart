import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;

  List<FixtureItem> fixtures = [];

  // paging
  int limit = 50;
  int offset = 0;
  bool hasMore = true;

  // query
  String runType = 'initial';

  // filtre
  String? status; // ex: "scheduled"
  String? dateFrom; // YYYY-MM-DD
  String? dateTo; // YYYY-MM-DD

  // ultimele league ids cerute (pt refresh/loadMore)
  List<String> _lastLeagueIds = [];

  // cache
  Duration cacheTtl = const Duration(minutes: 10);

  /// setează implicit: azi -> +30 zile
  void setDefaultDateRange({int days = 30}) {
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
    loading = false;
    error = null;

    fixtures = [];

    limit = 50;
    offset = 0;
    hasMore = true;

    runType = 'initial';

    status = null;
    dateFrom = null;
    dateTo = null;

    _lastLeagueIds = [];
    notifyListeners();
  }

  /// load pentru 1 ligă (reset paging)
  Future<void> loadForLeague(String leagueId, {bool cacheFirst = true}) async {
    return loadForLeagues([leagueId], cacheFirst: cacheFirst, resetPaging: true);
  }

  /// load pentru mai multe ligi (resetPaging by default)
  Future<void> loadForLeagues(
    List<String> leagueIds, {
    bool cacheFirst = true,
    bool resetPaging = true,
  }) async {
    final ids = leagueIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    _lastLeagueIds = ids;

    if (resetPaging) {
      offset = 0;
      hasMore = true;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      // mic retry (ApiClient are deja retry/timeout)
      const maxAttempts = 3;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final path = _service.buildFixturesPath(
            leagueIds: ids,
            runType: runType,
            limit: limit,
            offset: offset,
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );

          final items = await _service.getFixturesByUrl(
            path,
            cacheFirst: cacheFirst,
            cacheTtl: cacheTtl,
          );

          if (resetPaging || offset == 0) {
            fixtures = items;
          } else {
            fixtures = [...fixtures, ...items];
          }

          hasMore = items.length >= limit;
          error = null;
          break;
        } catch (e) {
          if (attempt == maxAttempts) rethrow;
          // backoff pt Render cold start
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    } catch (e) {
      error = e.toString();
      fixtures = resetPaging ? [] : fixtures;
      hasMore = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// refresh = forțează network (ignore cache)
  Future<void> refresh() async {
    if (_lastLeagueIds.isEmpty) return;
    await loadForLeagues(
      _lastLeagueIds,
      cacheFirst: false,
      resetPaging: true,
    );
  }

  /// load more (paginare)
  Future<void> loadMore({bool cacheFirst = true}) async {
    if (loading) return;
    if (!hasMore) return;
    if (_lastLeagueIds.isEmpty) return;

    offset += limit;
    await loadForLeagues(
      _lastLeagueIds,
      cacheFirst: cacheFirst,
      resetPaging: false,
    );
  }
}
