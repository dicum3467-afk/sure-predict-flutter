import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;
  List<FixtureItem> fixtures = [];

  // paging / query
  int limit = 50;
  int offset = 0;
  String runType = 'initial';

  // filtre opționale
  String? status;
  String? dateFrom; // "YYYY-MM-DD"
  String? dateTo; // "YYYY-MM-DD"

  /// Setează implicit intervalul: azi -> +7 zile
  void setDefaultDates({int days = 7}) {
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

  Future<void> loadForLeague(String leagueUid) async {
    await loadForLeagues([leagueUid]);
  }

  /// Load fixtures pentru una sau mai multe ligi
  Future<void> loadForLeagues(List<String> leagueUids) async {
    loading = true;
    error = null;
    notifyListeners();

    Future<List<FixtureItem>> _doRequest() async {
      final path = _service.buildFixturesPath(
        leagueUids: leagueUids,
        runType: runType,
        limit: limit,
        offset: offset,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      return _service.getFixturesByUrl(path);
    }

    try {
      // Retry simplu (Render cold start / DNS / connection abort)
      const attempts = 3;
      for (int i = 0; i < attempts; i++) {
        try {
          fixtures = await _doRequest();
          error = null;
          break;
        } catch (e) {
          if (i == attempts - 1) rethrow;
          await Future.delayed(Duration(seconds: 2 + i)); // 2s, 3s
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

  /// Modifică paging-ul (ex: limit/offset) și, dacă vrei, poți reîncărca din UI.
  void setPaging({int? newLimit, int? newOffset}) {
    if (newLimit != null) limit = newLimit;
    if (newOffset != null) offset = newOffset;
    notifyListeners();
  }

  /// Setează filtrele și (opțional) reîncarci din UI după.
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
