import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  // state
  bool loading = false;
  String? error;
  List<FixtureItem> fixtures = [];

  // paging
  int limit = 50;
  int offset = 0;
  bool hasMore = true;

  // query / filters
  String runType = 'initial'; // initial / live / etc.
  String? status;
  String? dateFrom; // YYYY-MM-DD
  String? dateTo;   // YYYY-MM-DD

  // last request context
  List<String> _lastLeagueIds = [];

  // -------------------------
  // Date range helper
  // -------------------------
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

  // -------------------------
  // Main loads
  // -------------------------
  Future<void> loadForLeague(
    String leagueId, {
    bool cacheFirst = false,
  }) async {
    await loadForLeagues([leagueId], cacheFirst: cacheFirst, append: false);
  }

  Future<void> loadForLeagues(
    List<String> leagueIds, {
    bool cacheFirst = false,
    bool append = false,
  }) async {
    _lastLeagueIds = leagueIds;

    loading = true;
    error = null;
    notifyListeners();

    try {
      // retry (Render cold start / net glitch)
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

          final data = await _service.getFixturesByUrl(path);

          if (append) {
            fixtures.addAll(data);
          } else {
            fixtures = data;
          }

          // dacă a venit fix cât limit, posibil mai există pagini
          hasMore = data.length == limit;
          error = null;
          break;
        } catch (e) {
          if (attempt == maxAttempts) rethrow;
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    } catch (e) {
      error = e.toString();
      if (!append) fixtures = [];
      hasMore = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // -------------------------
  // UI actions
  // -------------------------
  Future<void> refresh() async {
    // refresh = reîncarcă de la offset 0
    offset = 0;
    hasMore = true;

    if (_lastLeagueIds.isEmpty) {
      // fallback safe
      fixtures = [];
      error = null;
      loading = false;
      notifyListeners();
      return;
    }

    await loadForLeagues(_lastLeagueIds, cacheFirst: false, append: false);
  }

  Future<void> loadMore({bool cacheFirst = false}) async {
    if (loading || !hasMore) return;
    if (_lastLeagueIds.isEmpty) return;

    offset += limit;
    await loadForLeagues(_lastLeagueIds, cacheFirst: cacheFirst, append: true);
  }

  // -------------------------
  // Setters
  // -------------------------
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
    fixtures = [];
    error = null;
    loading = false;

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
}
