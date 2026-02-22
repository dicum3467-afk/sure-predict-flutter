import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;
  List<FixtureItem> fixtures = [];

  // query
  int limit = 50;
  int offset = 0;
  String runType = 'initial';

  // filtre
  String? status;
  String? dateFrom; // YYYY-MM-DD
  String? dateTo; // YYYY-MM-DD

  // =========================
  // ✅ setează azi -> +N zile
  // =========================
  void setDefaultDates([int days = 7]) {
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

  // ✅ load pentru o ligă
  Future<void> loadForLeague(String leagueUid) async {
    await loadForLeagues([leagueUid]);
  }

  // =========================
  // ✅ LOAD CU RETRY (Render cold start / DNS / net)
  // =========================
  Future<void> loadForLeagues(List<String> leagueUids) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      const maxAttempts = 3;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final path = _service.buildFixturesPath(
            leagueIds: leagueUids,
            runType: runType,
            limit: limit,
            offset: offset,
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );

          fixtures = await _service.getFixturesByUrl(path);
          error = null;
          break;
        } catch (e) {
          if (attempt == maxAttempts) rethrow;

          // important pt. Render cold start + rețea slabă
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    } catch (e) {
      error = e.toString();
      fixtures = [];
    } finally {
      loading = false;
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
    fixtures = [];
    error = null;
    loading = false;

    limit = 50;
    offset = 0;
    runType = 'initial';

    status = null;
    dateFrom = null;
    dateTo = null;

    notifyListeners();
  }
}
