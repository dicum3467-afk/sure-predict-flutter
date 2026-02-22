import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  static const _key = 'favorites_v1';

  final List<Map<String, dynamic>> items = [];

  bool isLoading = false;
  String? error;

  Future<void> load() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      items.clear();

      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items.addAll(decoded.map((e) => Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(Map<String, dynamic> fixture) async {
    final id = (fixture['provider_fixture_id'] ?? fixture['providerFixtureId'] ?? '').toString();
    if (id.isEmpty) return;

    final idx = items.indexWhere((e) {
      final eid = (e['provider_fixture_id'] ?? e['providerFixtureId'] ?? '').toString();
      return eid == id;
    });

    if (idx >= 0) {
      items.removeAt(idx);
    } else {
      items.add(fixture);
    }

    await _save();
    notifyListeners();
  }

  bool isFavorite(String providerFixtureId) {
    return items.any((e) {
      final eid = (e['provider_fixture_id'] ?? e['providerFixtureId'] ?? '').toString();
      return eid == providerFixtureId;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }
}
