import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VipStore extends ChangeNotifier {
  static const _kVipUntilMs = 'vip:until_ms';

  int? _vipUntilMs;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _vipUntilMs = sp.getInt(_kVipUntilMs);
    notifyListeners();
  }

  bool get isVip {
    final until = _vipUntilMs;
    if (until == null) return false;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  Duration get remaining {
    final until = _vipUntilMs;
    if (until == null) return Duration.zero;
    final diffMs = until - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return Duration.zero;
    return Duration(milliseconds: diffMs);
  }

  Future<void> grant(Duration duration) async {
    final until = DateTime.now().add(duration).millisecondsSinceEpoch;
    _vipUntilMs = until;

    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kVipUntilMs, until);

    notifyListeners();
  }

  Future<void> clear() async {
    _vipUntilMs = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kVipUntilMs);
    notifyListeners();
  }
}
