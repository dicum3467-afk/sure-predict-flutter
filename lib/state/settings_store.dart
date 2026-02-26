import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  static const _kThreshold = 'threshold';
  static const _kStatus = 'default_status';
  static const _kTopPerLeague = 'top_per_league';

  double _threshold = 0.60; // 60%
  String _status = 'all';   // all/scheduled/live/finished
  bool _topPerLeague = false;

  double get threshold => _threshold;
  String get status => _status;
  bool get topPerLeague => _topPerLeague;

  String _normalizeStatus(String v) {
    final s = v.trim().toLowerCase();
    if (s.isEmpty) return 'all';
    if (s == 'all') return 'all';
    if (s == 'scheduled') return 'scheduled';
    if (s == 'live') return 'live';
    if (s == 'finished') return 'finished';
    return 'all';
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _threshold = sp.getDouble(_kThreshold) ?? 0.60;
    _status = _normalizeStatus(sp.getString(_kStatus) ?? 'all');
    _topPerLeague = sp.getBool(_kTopPerLeague) ?? false;
    notifyListeners();
  }

  Future<void> setThreshold(double v) async {
    _threshold = v.clamp(0.0, 1.0);
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kThreshold, _threshold);
  }

  Future<void> setStatus(String v) async {
    _status = _normalizeStatus(v);
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kStatus, _status);
  }

  Future<void> setTopPerLeague(bool v) async {
    _topPerLeague = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kTopPerLeague, _topPerLeague);
  }

  Future<void> reset() async {
    _threshold = 0.60;
    _status = 'all';
    _topPerLeague = false;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kThreshold);
    await sp.remove(_kStatus);
    await sp.remove(_kTopPerLeague);
  }
}
