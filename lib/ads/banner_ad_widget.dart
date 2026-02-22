import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    _ad = AdService.createBanner()
      ..load().then((_) {
        if (mounted) {
          setState(() => _loaded = true);
        }
      });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) {
      return const SizedBox(height: 50);
    }

    return SizedBox(
      height: _ad!.size.height.toDouble(),
      width: _ad!.size.width.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
