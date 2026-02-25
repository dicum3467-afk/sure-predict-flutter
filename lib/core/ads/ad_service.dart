import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  int _predictionOpens = 0;

  // ================= REAL IDs =================

  static const String _realBannerId =
      'ca-app-pub-2800443504046517/6111381965';

  static const String _realInterstitialId = '';

  static const String _realRewardedId = '';

  // ================= TEST IDs =================

  static const String _testBannerId =
      'ca-app-pub-3940256099942544/6300978111';

  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  String get bannerId => kReleaseMode ? _realBannerId : _testBannerId;

  String get interstitialId {
    if (!kReleaseMode) return _testInterstitialId;
    if (_realInterstitialId.trim().isEmpty) return _testInterstitialId;
    return _realInterstitialId;
  }

  String get rewardedId {
    if (!kReleaseMode) return _testRewardedId;
    if (_realRewardedId.trim().isEmpty) return _testRewardedId;
    return _realRewardedId;
  }

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  // ================= INTERSTITIAL =================

  void _loadInterstitial() {
    if (_loadingInterstitial) return;

    _loadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  void maybeShowPredictionAd() {
    _predictionOpens++;

    if (_predictionOpens % 3 != 0) return;

    if (_interstitial == null) {
      _loadInterstitial();
      return;
    }

    _interstitial!.fullScreenContentCallback =
        FullScreenContentCallback(
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

  // ================= REWARDED =================

  void _loadRewarded() {
    if (_loadingRewarded) return;

    _loadingRewarded = true;

    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
          _loadingRewarded = false;
        },
      ),
    );
  }

  Future<bool> showRewarded() async {
    if (_rewarded == null) {
      _loadRewarded();
      return false;
    }

    bool earned = false;

    await _rewarded!.show(
      onUserEarnedReward: (_, __) {
        earned = true;
      },
    );

    _rewarded?.dispose();
    _rewarded = null;
    _loadRewarded();

    return earned;
  }

  // ================= BANNER =================

  BannerAd createBanner() {
    return BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    );
  }
}
