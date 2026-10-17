import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/mutashabihat_repository.dart';
import 'data/quran_repository.dart';
import 'data/variant_repository.dart';
import 'state/reader_settings.dart';
import 'ui/reader_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (quran, variants, mutashabihat, settings) = await (
    QuranRepository.load(),
    VariantRepository.discover(),
    MutashabihatRepository.load(),
    ReaderSettings.load(),
  ).wait;
  runApp(QiraatApp(
    quran: quran,
    variants: variants,
    mutashabihat: mutashabihat,
    settings: settings,
  ));
}

class QiraatApp extends StatelessWidget {
  const QiraatApp({
    super.key,
    required this.quran,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
  });

  final QuranRepository quran;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مصحف القراءات العشر',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ReaderScreen(
        quran: quran,
        variants: variants,
        mutashabihat: mutashabihat,
        settings: settings,
      ),
    );
  }
}
