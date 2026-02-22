import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _prefix = 'cache:';

  final SharedPreferences _prefs;
  LocalCache(this._prefs);

  static Future<LocalCache> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalCache(prefs);
  }

  String _k(String key) => '$_prefix$key';
  String _kTs(String key) => '$_prefix$key:ts';

  Future<void> setJson(String key, Object json) async {
    await _prefs.setString(_k(key), jsonEncode(json));
    await _prefs.setInt(_kTs(key), DateTime.now().millisecondsSinceEpoch);
  }

  /// Returnează JSON (Map/List) dacă:
  /// - există
  /// - și nu e expirat (ttl)
  dynamic getJson(String key, {Duration? ttl}) {
    final raw = _prefs.getString(_k(key));
    if (raw == null) return null;

    if (ttl != null) {
      final ts = _prefs.getInt(_kTs(key)) ?? 0;
      final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
      if (ageMs > ttl.inMilliseconds) return null;
    }

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    await _prefs.remove(_k(key));
    await _prefs.remove(_kTs(key));
  }

  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
