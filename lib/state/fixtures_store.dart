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

  Future<void> loadForLeague(String leagueId) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final path = _service.buildFixturesPath(
        leagueIds: [leagueId],
        runType: runType,
        limit: limit,
        offset: offset,
      );
      fixtures = await _service.getFixturesByUrl(path);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
