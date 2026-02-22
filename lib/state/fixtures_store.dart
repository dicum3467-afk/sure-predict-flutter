import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;
  List<FixtureItem> fixtures = [];

  int limit = 50;
  int offset = 0;
  String runType = 'initial';

  // filtre opționale (le poți seta din UI dacă vrei)
  String? status;
  String? dateFrom; // "2026-02-19"
  String? dateTo; // "2026-02-25"

  Future<void> loadForLeague(String leagueId) async {
    await loadForLeagues([leagueId]);
  }

  Future<void> loadForLeagues(List<String> leagueIds) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      // Construiește path-ul cu league_ids repetat:
      // /fixtures?league_ids=a&league_ids=b&run_type=...&limit=...&offset=...
      final path = _service.buildFixturesPath(
        leagueIds: leagueIds,
        runType: runType,
        limit: limit,
        offset: offset,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      fixtures = await _service.getFixturesByUrl(path);
    } catch (e) {
      error = e.toString();
      fixtures = [];
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
