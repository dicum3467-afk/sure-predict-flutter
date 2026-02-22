import 'package:flutter/foundation.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  final SurePredictService service;

  FixturesStore(this.service);

  List<dynamic> items = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int offset = 0;
  final int limit = 50;
  bool hasMore = true;

  String? _leagueId;

  Future<void> loadInitial(String leagueId) async {
    _leagueId = leagueId;
    offset = 0;
    hasMore = true;
    items = [];
    isLoading = true;
    notifyListeners();

    try {
      final data = await service.getFixtures(
        leagueId: leagueId,
        limit: limit,
        offset: offset,
      );

      items = data;
      offset += data.length;
      hasMore = data.length == limit;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || _leagueId == null) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      final data = await service.getFixtures(
        leagueId: _leagueId!,
        limit: limit,
        offset: offset,
      );

      items.addAll(data);
      offset += data.length;
      hasMore = data.length == limit;
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_leagueId != null) {
      await loadInitial(_leagueId!);
    }
  }
}
