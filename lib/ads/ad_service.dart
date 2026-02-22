import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  // 🔥 ÎNLOCUIEȘTE CU ID-UL TĂU REAL
  static const String bannerId =
      'ca-app-pub-3940256099942544/6300978111'; // <-- schimbăm după

  static BannerAd createBanner() {
    return BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(),
    );
  }
}
