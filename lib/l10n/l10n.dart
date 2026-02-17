import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppL10n {
  final Locale locale;
  AppL10n(this.locale);

  /// IMPORTANT: Folosește delegate-ul ăsta în MaterialApp.localizationsDelegates
  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// IMPORTANT: Folosește lista asta în MaterialApp.supportedLocales
  static const supportedLocales = <Locale>[
    Locale('ro'),
    Locale('en'),
  ];

  static AppL10n of(BuildContext context) {
    final l10n = Localizations.of<AppL10n>(context, AppL10n);
    assert(l10n != null, 'AppL10n not found in widget tree. Did you add AppL10n.delegate?');
    return l10n!;
  }

  late final Map<String, String> _strings;

  Future<void> load() async {
    final code = locale.languageCode;
    // Fișierele trebuie să existe exact aici:
    // lib/l10n/app_ro.arb și lib/l10n/app_en.arb
    final raw = await rootBundle.loadString('lib/l10n/app_$code.arb');
    final map = (json.decode(raw) as Map<String, dynamic>);
    _strings = map.map((k, v) => MapEntry(k, v.toString()));
  }

  String t(String key) => _strings[key] ?? key;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ro' || locale.languageCode == 'en';

  @override
  Future<AppL10n> load(Locale locale) async {
    final l10n = AppL10n(locale);
    await l10n.load();
    return l10n;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppL10n> old) => false;
}
