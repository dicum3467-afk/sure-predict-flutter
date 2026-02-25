class SimpleCacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  SimpleCacheEntry(this.value, this.expiresAt);

  bool get isFresh => DateTime.now().isBefore(expiresAt);
  int get ageSeconds =>
      DateTime.now().difference(expiresAt).inSeconds.abs();
}

class SimpleCache {
  final Duration ttl;
  final _map = <String, SimpleCacheEntry<dynamic>>{};

  const SimpleCache({required this.ttl});

  T? get<T>(String key) {
    final e = _map[key];
    if (e == null) return null;
    if (!e.isFresh) {
      _map.remove(key);
      return null;
    }
    return e.value as T;
  }

  void put<T>(String key, T value) {
    _map[key] =
        SimpleCacheEntry(value, DateTime.now().add(ttl));
  }

  SimpleCacheEntry<dynamic>? info(String key) => _map[key];

  void clearAll() => _map.clear();
}
