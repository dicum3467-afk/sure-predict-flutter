import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleCache {
  final Duration ttl;

  const SimpleCache({required this.ttl});

  String _kData(String key) => 'cache:data:$key';
  String _kTs(String key) => 'cache:ts:$key';

  Future<int?> getLastUpdatedMs(String key) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kTs(key));
  }

  Future<int?> getAgeSeconds(String key) async {
    final ts = await getLastUpdatedMs(key);
    if (ts == null) return null;
    final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
    return (ageMs / 1000).floor();
  }

  Future<bool> isFresh(String key) async {
    final age = await getAgeSeconds(key);
    if (age == null) return false;
    return age <= ttl.inSeconds;
  }

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

  Future<T> getSWR<T>({
    required String key,
    required Future<T> Function() fetcher,
  }) async {
    final fresh = await get(key);
    if (fresh != null) {
      // ignore: unawaited_futures
      _revalidate<T>(key: key, fetcher: fetcher);
      return fresh as T;
    }

    final stale = await getStale(key);
    if (stale != null) {
      // ignore: unawaited_futures
      _revalidate<T>(key: key, fetcher: fetcher);
      return stale as T;
    }

    final data = await fetcher();
    await set(key, data);
    return data;
  }

  Future<void> _revalidate<T>({
    required String key,
    required Future<T> Function() fetcher,
  }) async {
    try {
      final data = await fetcher();
      await set(key, data);
    } catch (_) {
      // ignore
    }
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
