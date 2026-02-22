import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;
  List<FixtureItem> fixtures = [];

  // paginare
  int limit = 50;
  int offset = 0;

  // run type (initial / daily etc)
  String runType = 'initial';

  // filtre opționale
  String? status;   // ex: "scheduled", "live", "finished"
  String? dateFrom; // "YYYY-MM-DD"
  String? dateTo;   // "YYYY-MM-DD"

  Future<void> loadForLeague(String leagueId) async {
    await loadForLeagues([leagueId]);
  }

  Future<void> loadForLeagues(List<String> leagueIds) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      // construim URL-ul complet cu league_ids repetat + restul query-ului
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

      // ✅ sortare (cele mai apropiate primele)
      fixtures.sort((a, b) =>
          (a.kickoffAt ?? DateTime(2100))
              .compareTo(b.kickoffAt ?? DateTime(2100)));
    } catch (e) {
      error = e.toString();
      fixtures = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Helpers pentru UI (optional)
  void setPaging({int? newLimit, int? newOffset}) {
    if (newLimit != null) limit = newLimit;
    if (newOffset != null) offset = newOffset;
    notifyListeners();
  }

  void setRunType(String value) {
    runType = value;
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
