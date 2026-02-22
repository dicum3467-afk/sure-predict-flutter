// lib/state/leagues_store.dart
import 'package:flutter/foundation.dart';
import '../services/sure_predict_service.dart';

class LeaguesStore extends ChangeNotifier {
  final SurePredictService _service;

  LeaguesStore(this._service);

  // ===== STATE =====
  bool isLoading = false;
  String? error;
  final List<Map<String, dynamic>> items = [];

  // ===== LOAD =====
  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final data = await _service.getLeagues();

      items
        ..clear()
        ..addAll(data);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
