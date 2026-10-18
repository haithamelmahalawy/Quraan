import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/mutashabihat_repository.dart';
import 'data/online_qiraat.dart';
import 'data/quran_repository.dart';
import 'data/variant_repository.dart';
import 'state/reader_settings.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final online = OnlineQiraat(prefs: await SharedPreferences.getInstance());
  final (quran, variants, mutashabihat, settings) = await (
    QuranRepository.load(),
    VariantRepository.discover(null, online),
    MutashabihatRepository.load(),
    ReaderSettings.load(),
  ).wait;
  runApp(
    QiraatApp(
      quran: quran,
      variants: variants,
      mutashabihat: mutashabihat,
      settings: settings,
    ),
  );
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
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'مصحف القراءات العشر',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(MushafPalette.light),
        darkTheme: buildTheme(MushafPalette.dark),
        themeMode: settings.themeMode,
        // The mushaf colours follow the theme; the tree is rebuilt when it
        // changes so every page, frame and sheet repaints with them.
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          MushafColors.use(brightness);
          return KeyedSubtree(key: ValueKey(brightness), child: child!);
        },
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeScreen(
          quran: quran,
          variants: variants,
          mutashabihat: mutashabihat,
          settings: settings,
        ),
      ),
    );
  }
}
