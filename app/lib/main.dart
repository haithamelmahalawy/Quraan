import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/mutashabihat_repository.dart';
import 'data/quran_repository.dart';
import 'data/variant_repository.dart';
import 'state/reader_settings.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final (mushafs, variants, mutashabihat, settings) = await (
    Mushafs.load(),
    VariantRepository.discover(),
    MutashabihatRepository.load(),
    ReaderSettings.load(),
  ).wait;
  runApp(
    QiraatApp(
      mushafs: mushafs,
      variants: variants,
      mutashabihat: mutashabihat,
      settings: settings,
    ),
  );
}

class QiraatApp extends StatelessWidget {
  const QiraatApp({
    super.key,
    required this.mushafs,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
  });

  final Mushafs mushafs;
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
          mushafs: mushafs,
          variants: variants,
          mutashabihat: mutashabihat,
          settings: settings,
        ),
      ),
    );
  }
}
