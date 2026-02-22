import 'package:flutter/foundation.dart';
import '../services/sure_predict_service.dart';

class FixturesStore extends ChangeNotifier {
  final SurePredictService _service;
  FixturesStore(this._service);

  final List<Map<String, dynamic>> items = [];

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  String _leagueId = '';
  int _limit = 50;
  int _offset = 0;

  // range default: azi -> +30 zile
  DateTime from = DateTime.now();
  DateTime to = DateTime.now().add(const Duration(days: 30));

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  Future<void> loadInitial(String leagueId) async {
    _leagueId = leagueId;
    _offset = 0;
    items.clear();
    error = null;
    notifyListeners();
    await _load(isMore: false);
  }

  Future<void> refresh() async {
    _offset = 0;
    items.clear();
    error = null;
    notifyListeners();
    await _load(isMore: false);
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore) return;
    await _load(isMore: true);
  }

  Future<void> setRangeDays(int days) async {
    from = DateTime.now();
    to = DateTime.now().add(Duration(days: days));
    await refresh();
  }

  Future<void> _load({required bool isMore}) async {
    try {
      if (isMore) {
        isLoadingMore = true;
      } else {
        isLoading = true;
      }
      notifyListeners();

      final data = await _service.getFixtures(
        leagueId: _leagueId,
        from: _fmt(from),
        to: _fmt(to),
        limit: _limit,
        offset: _offset,
      );

      items.addAll(data);
      _offset += _limit;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
