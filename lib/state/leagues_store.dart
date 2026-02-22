// lib/state/leagues_store.dart
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../services/sure_predict_service.dart';

class LeaguesStore extends ChangeNotifier {
  final SurePredictService service;

  LeaguesStore(this.service);

  bool loading = false;
  String? error;

  List<League> leagues = const [];

  Future<void> loadLeagues() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      leagues = await service.getLeagues();
    } on ApiException catch (e) {
      error = e.toString();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadLeagues();
}
