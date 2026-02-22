import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  static const _key = 'favorite_fixture_ids';

  final Set<String> _ids = {};
  bool _loaded = false;

  bool isFavorite(String fixtureId) => _ids.contains(fixtureId);

  List<String> get allIds => _ids.toList(growable: false);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    _ids.addAll(raw);
  }

  Future<void> toggle(String fixtureId) async {
    await ensureLoaded();

    if (_ids.contains(fixtureId)) {
      _ids.remove(fixtureId);
    } else {
      _ids.add(fixtureId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());

    notifyListeners();
  }
}
