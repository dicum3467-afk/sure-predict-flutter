import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  InterstitialAd? _interstitial;
  bool _isLoading = false;
  int _predictionOpens = 0;

  // ⚠️ PUNE ID-URILE TALE REALE AICI
  static const String bannerId = 'ca-app-pub-2800443504046517/6111381965';
  static const String interstitialId = 'ca-app-pub-3940256099942544/1033173712';
  // ↑ momentan test interstitial (sigur). Îl schimbăm când ești gata live.

  // ---------------- INIT ----------------

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  // ---------------- INTERSTITIAL ----------------

  void _loadInterstitial() {
    if (_isLoading) return;

    _isLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// ⭐ LOGICĂ COMERCIALĂ
  /// arată ad la fiecare 3 deschideri prediction
  void maybeShowPredictionAd() {
    _predictionOpens++;

    if (_predictionOpens % 3 != 0) return;

    if (_interstitial == null) {
      _loadInterstitial();
      return;
    }

    _interstitial!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _interstitial?.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (_, __) {
        _interstitial?.dispose();
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
