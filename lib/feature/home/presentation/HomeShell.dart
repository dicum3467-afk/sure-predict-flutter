import 'package:flutter/material.dart';
import '../../../core/ads/banner_ad_widget.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  final String title;

  const HomeShell({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(child: child),
          const SafeArea(
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }
}
