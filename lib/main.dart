import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'l10n/i18n.dart';
import 'l10n/locale_provider.dart';
export 'app.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // Initialize locale provider
  final localeProvider = LocaleProvider();
  await localeProvider.init();
 
  // Initialize i18n with the current locale
  await I18n.init(localeProvider.locale);
 
  runApp(
    ChangeNotifierProvider.value(
      value: localeProvider,
      child: const FixMateApp(),
    ),
  );
}
