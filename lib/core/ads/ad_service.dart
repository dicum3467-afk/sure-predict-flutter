import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  InterstitialAd? _interstitial;
  bool _isLoadingInterstitial = false;
  int _predictionOpens = 0;

  // =========================
  // ✅ IDs REALE (ale tale)
  // =========================
  static const String _realBannerId = 'ca-app-pub-2800443504046517/6111381965';

  // ❗ Pune aici interstitial-ul REAL când îl creezi în AdMob.
  // Dacă nu ai încă, lasă gol și va folosi TEST chiar și în release.
  static const String _realInterstitialId = '';

  // =========================
  // ✅ IDs TEST (Google)
  // =========================
  // Banner test
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  // Interstitial test
  static const String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  String get bannerId => kReleaseMode ? _realBannerId : _testBannerId;

  String get interstitialId {
    if (!kReleaseMode) return _testInterstitialId;
    // în release: dacă nu ai setat încă interstitial real, rămâne test
    if (_realInterstitialId.trim().isEmpty) return _testInterstitialId;
    return _realInterstitialId;
  }

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  // ---------------- INTERSTITIAL ----------------

  void _loadInterstitial() {
    if (_isLoadingInterstitial) return;

    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  /// ⭐ Arată interstitial la fiecare 3 deschideri Prediction
  void maybeShowPredictionAd() {
    _predictionOpens++;

    // comercial: o dată la 3
    if (_predictionOpens % 3 != 0) return;

    if (_interstitial == null) {
      _loadInterstitial();
      return;
    }

    _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
    );

    _interstitial!.show();
    _interstitial = null;
  }

  // ---------------- BANNER ----------------

  BannerAd createBanner() {
    return BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    );
  }
}
