import 'package:flutter/foundation.dart';
import '../services/sure_predict_service.dart';

class LeaguesStore extends ChangeNotifier {
  final SurePredictService _service;

  LeaguesStore(this._service);

  bool isLoading = false;
  String? error;

  final List<Map<String, dynamic>> items = [];

  bool _loadedOnce = false;

  // ✅ FIX: getter cerut de UI (Top Picks / Fixtures)
  Set<String> get selectedIds {
    return items
        .where((e) => e['selected'] == true)
        .map<String>((e) => (e['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  // opțional: selectează/deselectează o ligă
  void toggleSelected(String leagueId) {
    for (final l in items) {
      final id = (l['id'] ?? '').toString();
      if (id == leagueId) {
        l['selected'] = !(l['selected'] == true);
        notifyListeners();
        return;
      }
    }
  }

  void setSelected(String leagueId, bool selected) {
    for (final l in items) {
      final id = (l['id'] ?? '').toString();
      if (id == leagueId) {
        l['selected'] = selected;
        notifyListeners();
        return;
      }
    }
  }

  void selectAll(bool selected) {
    for (final l in items) {
      l['selected'] = selected;
    }
    notifyListeners();
  }

  // ---- LOAD ----
  Future<void> load({bool force = false}) async {
    // dacă avem deja date și nu forțăm, nu mai încărcăm
    if (!force && _loadedOnce && items.isNotEmpty) return;

    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final data = await _service.getLeagues();

      // sort: country -> tier -> name (dacă există)
      data.sort((a, b) {
        final ca = (a['country'] ?? '').toString();
        final cb = (b['country'] ?? '').toString();
        final c = ca.compareTo(cb);
        if (c != 0) return c;

        int tierNum(dynamic v) {
          if (v is int) return v;
          return int.tryParse(v?.toString() ?? '') ?? 999;
        }

        final ta = tierNum(a['tier']);
        final tb = tierNum(b['tier']);
        final t = ta.compareTo(tb);
        if (t != 0) return t;

        final na = (a['name'] ?? '').toString();
        final nb = (b['name'] ?? '').toString();
        return na.compareTo(nb);
      });

      // dacă nu există "selected", implicit selectat
      for (final l in data) {
        l['selected'] ??= true;
      }

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

  Future<void> refresh() => load(force: true);
}
