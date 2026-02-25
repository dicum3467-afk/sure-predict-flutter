// lib/state/leagues_store.dart
import 'package:flutter/foundation.dart';
import '../services/sure_predict_service.dart';

class LeaguesStore extends ChangeNotifier {
  final SurePredictService _service;

  LeaguesStore(this._service);

  // ================= STATE =================
  bool isLoading = false;
  String? error;
  final List<Map<String, dynamic>> items = [];

  bool _loadedOnce = false;
  Future<void>? _loadingFuture;

  // ================= LOAD =================
  Future<void> load({bool force = false}) async {
    // 🚫 evită load dublu
    if (_loadingFuture != null) return _loadingFuture;

    // 🚫 dacă avem deja date și nu forțăm
    if (!force && _loadedOnce && items.isNotEmpty) return;

    _loadingFuture = _doLoad(force: force);
    await _loadingFuture;
    _loadingFuture = null;
  }

  Future<void> _doLoad({bool force = false}) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final data = await _service.getLeagues();

      // 🔥 sortare PRO: country -> tier -> name
      data.sort((a, b) {
        final ca = (a['country'] ?? '').toString();
        final cb = (b['country'] ?? '').toString();
        final countryCmp = ca.compareTo(cb);
        if (countryCmp != 0) return countryCmp;

        final ta = _tierNum(a['tier']);
        final tb = _tierNum(b['tier']);
        final tierCmp = ta.compareTo(tb);
        if (tierCmp != 0) return tierCmp;

        final na = (a['name'] ?? '').toString();
        final nb = (b['name'] ?? '').toString();
        return na.compareTo(nb);
      });

      items
        ..clear()
        ..addAll(data);

      _loadedOnce = true;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ================= REFRESH =================
  Future<void> refresh() => load(force: true);

  // ================= HELPERS =================
  int _tierNum(dynamic t) {
    if (t is int) return t;
    final n = int.tryParse(t?.toString() ?? '');
    return n ?? 999;
  }
}
