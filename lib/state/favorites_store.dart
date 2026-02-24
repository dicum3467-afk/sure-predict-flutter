import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  static const _kKey = 'sure_predict_favorites_v1';

  final List<Map<String, dynamic>> _items = [];
  bool _loaded = false;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  String _keyOf(Map<String, dynamic> fixture) {
    final pf = (fixture['provider_fixture_id'] ?? '').toString();
    if (pf.isNotEmpty) return 'pf:$pf';
    final id = (fixture['id'] ?? '').toString();
    return 'id:$id';
  }

  bool isFavorite(Map<String, dynamic> fixture) {
    final k = _keyOf(fixture);
    return _items.any((x) => _keyOf(x) == k);
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _items
          ..clear()
          ..addAll(decoded.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (_) {
      // ignore corrupted
      _items.clear();
    }

    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, jsonEncode(_items));
  }

  Future<void> toggle(Map<String, dynamic> fixture) async {
    final k = _keyOf(fixture);

    final idx = _items.indexWhere((x) => _keyOf(x) == k);
    if (idx >= 0) {
      _items.removeAt(idx);
    } else {
      // salvăm un subset curat (nu vrei să salvezi tot)
      final safe = <String, dynamic>{
        'provider_fixture_id': (fixture['provider_fixture_id'] ?? '').toString(),
        'id': (fixture['id'] ?? '').toString(),
        'league_id': (fixture['league_id'] ?? '').toString(),
        'home': (fixture['home'] ?? '').toString(),
        'away': (fixture['away'] ?? '').toString(),
        'kickoff': (fixture['kickoff_at'] ?? fixture['kickoff'] ?? '').toString(),
        'status': (fixture['status'] ?? '').toString(),
        'p_home': fixture['p_home'],
        'p_draw': fixture['p_draw'],
        'p_away': fixture['p_away'],
        'p_over25': fixture['p_over25'],
        'p_under25': fixture['p_under25'],
      };
      _items.insert(0, safe);
    }

    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
    notifyListeners();
  }
}
