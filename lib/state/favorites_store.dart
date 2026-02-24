// lib/state/favorites_store.dart
import 'package:flutter/foundation.dart';

class FavoritesStore extends ChangeNotifier {
  final Set<String> _favoriteIds = {};

  Set<String> get ids => _favoriteIds;

  bool isFavorite(String fixtureId) {
    return _favoriteIds.contains(fixtureId);
  }

  void toggle(String fixtureId) {
    if (_favoriteIds.contains(fixtureId)) {
      _favoriteIds.remove(fixtureId);
    } else {
      _favoriteIds.add(fixtureId);
    }
    notifyListeners();
  }

  void clear() {
    _favoriteIds.clear();
    notifyListeners();
  }
}
