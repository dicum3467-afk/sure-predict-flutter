import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleCache {
  final Duration ttl;

  const SimpleCache({required this.ttl});

  String _kData(String key) => 'cache:data:$key';
  String _kTs(String key) => 'cache:ts:$key';

  Future<dynamic> get(String key) async {
    final sp = await SharedPreferences.getInstance();
    final ts = sp.getInt(_kTs(key));
    final raw = sp.getString(_kData(key));

    if (ts == null || raw == null || raw.isEmpty) return null;

    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > ttl.inMilliseconds) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Ia date chiar dacă sunt expirate (pentru fallback când API cade)
  Future<dynamic> getStale(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kData(key));
    if (raw == null || raw.isEmpty) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String key, dynamic data) async {
    final sp = await SharedPreferences.getInstance();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final raw = jsonEncode(data);
    await sp.setString(_kData(key), raw);
    await sp.setInt(_kTs(key), ts);
  }

  Future<void> remove(String key) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kData(key));
    await sp.remove(_kTs(key));
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys().where((k) => k.startsWith('cache:')).toList();
    for (final k in keys) {
      await sp.remove(k);
    }
  }
}
