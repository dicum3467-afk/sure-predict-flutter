import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _prefix = 'cache:';

  Future<String?> getString(String key) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('$_prefix$key');
  }

  Future<void> setString(String key, String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('$_prefix$key', value);
  }

  Future<void> remove(String key) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('$_prefix$key');
  }

  /// Cache JSON cu TTL
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final map = Map<String, dynamic>.from(decoded);

    final exp = map['__expiresAt'] as int?;
    if (exp != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs > exp) {
        await remove(key);
        return null;
      }
    }

    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> setJson(
    String key,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    final exp = ttl == null
        ? null
        : DateTime.now().add(ttl).millisecondsSinceEpoch;

    final wrapped = <String, dynamic>{
      '__expiresAt': exp,
      'data': data,
    };

    await setString(key, jsonEncode(wrapped));
  }

  /// Cache LIST JSON cu TTL
  Future<List<dynamic>?> getJsonList(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final map = Map<String, dynamic>.from(decoded);

    final exp = map['__expiresAt'] as int?;
    if (exp != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs > exp) {
        await remove(key);
        return null;
      }
    }

    final data = map['data'];
    if (data is List) return data;
    return null;
  }

  Future<void> setJsonList(
    String key,
    List<dynamic> data, {
    Duration? ttl,
  }) async {
    final exp = ttl == null
        ? null
        : DateTime.now().add(ttl).millisecondsSinceEpoch;

    final wrapped = <String, dynamic>{
      '__expiresAt': exp,
      'data': data,
    };

    await setString(key, jsonEncode(wrapped));
  }
}
