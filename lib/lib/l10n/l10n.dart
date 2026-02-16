import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppL10n {
  final Locale locale;
  AppL10n(this.locale);

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  static AppL10n of(BuildContext context) {
    final l10n = Localizations.of<AppL10n>(context, AppL10n);
    return l10n!;
  }

  late Map<String, String> _strings;

  Future<void> load() async {
    final code = locale.languageCode;
    final raw = await rootBundle.loadString('lib/l10n/app_$code.arb');
    final map = (json.decode(raw) as Map<String, dynamic>);
    _strings = map.map((k, v) => MapEntry(k, v.toString()));
  }

  String t(String key) => _strings[key] ?? key;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  bool isSupported(Locale locale) => ['ro', 'en'].contains(locale.languageCode);

  @override
  Future<AppL10n> load(Locale locale) async {
    final l10n = AppL10n(locale);
    await l10n.load();
    return l10n;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppL10n> old) => false;
}
