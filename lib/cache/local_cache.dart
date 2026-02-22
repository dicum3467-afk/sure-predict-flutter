import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  LocalCache._();

  static Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  static String _tsKey(String key) => 'cache_ts::$key';
  static String _valKey(String key) => 'cache_val::$key';

  /// Salvează JSON (ca string) + timestamp
  static Future<void> setJson(
    String key,
    dynamic jsonValue,
  ) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(jsonValue);
    await prefs.setString(_valKey(key), encoded);
    await prefs.setInt(_tsKey(key), DateTime.now().millisecondsSinceEpoch);
  }

  /// Ia JSON dacă NU e expirat. Returnează null dacă lipsește/expirat.
  static Future<dynamic> getJson(
    String key, {
    required Duration ttl,
  }) async {
    final prefs = await _prefs;
    final ts = prefs.getInt(_tsKey(key));
    final raw = prefs.getString(_valKey(key));
    if (ts == null || raw == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > ttl.inMilliseconds) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Ia JSON chiar dacă e expirat (bun ca fallback la erori).
  static Future<dynamic> getJsonStale(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_valKey(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(_tsKey(key));
    await prefs.remove(_valKey(key));
  }

  static Future<void> clearAll() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
