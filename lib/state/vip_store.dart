import 'package:flutter/foundation.dart';

class VipStore extends ChangeNotifier {
  DateTime? _vipUntil;

  bool get isVip => _vipUntil != null && DateTime.now().isBefore(_vipUntil!);

  Duration get remaining {
    if (!isVip) return Duration.zero;
    return _vipUntil!.difference(DateTime.now());
  }

  /// Demo: activează VIP 7 zile (pentru test)
  void activateDemo({Duration duration = const Duration(days: 7)}) {
    _vipUntil = DateTime.now().add(duration);
    notifyListeners();
  }

  void clear() {
    _vipUntil = null;
    notifyListeners();
  }
}
