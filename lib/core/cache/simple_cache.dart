import 'dart:async';

class SimpleCacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  SimpleCacheEntry(this.value, this.expiresAt);

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}

class SimpleCache {
  final Duration ttl;

  SimpleCache({required this.ttl});

  final Map<String, SimpleCacheEntry<dynamic>> _map = {};

  T? get<T>(String key) {
    final entry = _map[key];
    if (entry == null) return null;
    if (!entry.isFresh) {
      _map.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void put<T>(String key, T value) {
    _map[key] = SimpleCacheEntry<T>(
      value,
      DateTime.now().add(ttl),
    );
  }

  Future<void> clearAll() async {
    _map.clear();
  }
}
