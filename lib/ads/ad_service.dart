import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  // 🔥 TEST BANNER ID (NU SCHIMBA încă)
  static const String bannerTestId =
      'ca-app-pub-3940256099942544/6300978111';

  static BannerAd createBanner() {
    return BannerAd(
      adUnitId: bannerTestId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(),
    );
  }
}
