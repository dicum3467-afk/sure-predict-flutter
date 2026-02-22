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

  // Filtre utile
  String status = 'scheduled'; // optional
  String? dateFrom; // ex: "2026-02-19"
  String? dateTo;   // ex: "2026-02-25"

  Future<void> load({
    required List<String> leagueIds,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

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

      fixtures = await _service.getFixturesByUrl(path);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForLeague(String leagueId) {
    return load(leagueIds: [leagueId]);
  }
}
