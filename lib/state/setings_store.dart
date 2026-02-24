import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  static const _kThreshold = 'settings:threshold';
  static const _kTopPerLeague = 'settings:top_per_league';
  static const _kStatus = 'settings:status';

  double threshold = 0.60;
  bool topPerLeague = false;
  String status = 'all';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    threshold = sp.getDouble(_kThreshold) ?? 0.60;
    topPerLeague = sp.getBool(_kTopPerLeague) ?? false;
    status = sp.getString(_kStatus) ?? 'all';

    notifyListeners();
  }

  Future<void> setThreshold(double v) async {
    threshold = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kThreshold, v);
    notifyListeners();
  }

  Future<void> setTopPerLeague(bool v) async {
    topPerLeague = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kTopPerLeague, v);
    notifyListeners();
  }

  Future<void> setStatus(String v) async {
    status = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kStatus, v);
    notifyListeners();
  }

  Future<void> reset() async {
    threshold = 0.60;
    topPerLeague = false;
    status = 'all';

    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kThreshold);
    await sp.remove(_kTopPerLeague);
    await sp.remove(_kStatus);

    notifyListeners();
  }
}
