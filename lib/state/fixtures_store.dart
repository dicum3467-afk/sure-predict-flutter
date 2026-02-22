import 'package:flutter/foundation.dart';

import '../models/fixture_item.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  FixturesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;
  List<FixtureItem> fixtures = <FixtureItem>[];

  int limit = 50;
  int offset = 0;
  String runType = 'initial';

  // filtre opționale
  String? status;
  String? dateFrom; // ex: "2026-02-19"
  String? dateTo;   // ex: "2026-02-25"

  Future<void> loadForLeague(String leagueUid) async {
    await loadForLeagues(<String>[leagueUid]);
  }

  Future<void> loadForLeagues(List<String> leagueUids) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final path = _service.buildFixturesPath(
        leagueUids: leagueUids,
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
      fixtures = <FixtureItem>[];
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
    fixtures = <FixtureItem>[];
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
