import 'package:flutter/foundation.dart';

import '../models/league.dart';
import '../services/sure_predict_service.dart';

class LeaguesStore extends ChangeNotifier {
  LeaguesStore(this._service);

  final SurePredictService _service;

  bool loading = false;
  String? error;
  List<League> leagues = [];

  Future<void> load({bool active = true}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      leagues = await _service.getLeagues(active: active);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
