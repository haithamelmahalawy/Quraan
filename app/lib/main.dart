import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/mutashabihat_repository.dart';
import 'data/quran_repository.dart';
import 'data/variant_repository.dart';
import 'state/reader_settings.dart';
import 'services/audio_library.dart';
import 'services/ayah_player.dart';
import 'ui/ayah_sheet.dart';
import 'ui/home_screen.dart';
import 'ui/recitation_player.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final (mushafs, variants, mutashabihat, settings, _) = await (
    Mushafs.load(),
    VariantRepository.discover(),
    MutashabihatRepository.load(),
    ReaderSettings.load(),
    AudioLibrary.instance.init(),
  ).wait;
  // A recitation kept on the device plays from it, with no connection.
  AyahPlayer.instance.clipUri = AudioLibrary.instance.clipUri;
  runApp(
    QiraatApp(
      mushafs: mushafs,
      variants: variants,
      mutashabihat: mutashabihat,
      settings: settings,
    ),
  );
}

class QiraatApp extends StatefulWidget {
  const QiraatApp({
    super.key,
    required this.mushafs,
    required this.variants,
    required this.mutashabihat,
    required this.settings,
    this.player,
  });

  final Mushafs mushafs;
  final VariantRepository variants;
  final MutashabihatRepository mutashabihat;
  final ReaderSettings settings;
  final AyahPlayer? player;

  @override
  State<QiraatApp> createState() => _QiraatAppState();
}

class _QiraatAppState extends State<QiraatApp> {
  final _navigator = GlobalKey<NavigatorState>();
  bool _openingPlayer = false;
  AyahPlayer get _player => widget.player ?? AyahPlayer.instance;

  Future<void> _openRecitation() async {
    final current = _player.current;
    final context = _navigator.currentState?.overlay?.context;
    if (current == null || context == null || _openingPlayer) return;
    _openingPlayer = true;
    try {
      final quran = widget.mushafs.of(widget.settings.edition);
      await AyahSheet.show(
        context,
        ayah: quran.ayah(current.surah, current.ayah),
        word: _player.currentWord,
        quran: quran,
        variants: widget.variants,
        settings: widget.settings,
        player: _player,
      );
    } finally {
      _openingPlayer = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigator,
        title: 'مصحف القراءات العشر',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(MushafPalette.light),
        darkTheme: buildTheme(MushafPalette.dark),
        themeMode: widget.settings.themeMode,
        // The mushaf colours follow the theme; the tree is rebuilt when it
        // changes so every page, frame and sheet repaints with them.
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          MushafColors.use(brightness);
          return KeyedSubtree(
            key: ValueKey(brightness),
            child: RecitationPlayerHost(
              player: _player,
              quran: widget.mushafs.of(widget.settings.edition),
              onOpen: _openRecitation,
              child: child!,
            ),
          );
        },
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeScreen(
          mushafs: widget.mushafs,
          variants: widget.variants,
          mutashabihat: widget.mutashabihat,
          settings: widget.settings,
        ),
      ),
    );
  }
}
