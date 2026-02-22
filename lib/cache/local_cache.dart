import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalCache> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalCache(prefs);
  }

  String _tsKey(String key) => '${key}__ts';

  Future<void> setJson(String key, Object value) async {
    final s = jsonEncode(value);
    await _prefs.setString(key, s);
    await _prefs.setInt(_tsKey(key), DateTime.now().millisecondsSinceEpoch);
  }

  /// Returnează null dacă nu există sau dacă e expirat (ttl).
  Object? getJson(String key, {Duration? ttl}) {
    final s = _prefs.getString(key);
    if (s == null) return null;

    if (ttl != null) {
      final ts = _prefs.getInt(_tsKey(key));
      if (ts == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > ttl.inMilliseconds) return null;
    }

    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
    await _prefs.remove(_tsKey(key));
  }

  Future<void> clear() async {
    await _prefs.clear();
  }
}
