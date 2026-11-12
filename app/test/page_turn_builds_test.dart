import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/book_pager.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/reader_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

/// Weak phones turned pages slowly, the more so with more riwayat chosen:
/// every turn built the three pages near again, two or three times. A turn
/// builds only the page newly come near.
/// The reader's lamp and hints may keep animating: a fixed wait, not a settle.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Mushafs mushafs;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  const riwayat = {'warsh', 'qalun', 'khalaf_hamzah', 'khallad'};
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    mushafs = await Mushafs.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(riwayat.toList());
    mutashabihat = await MutashabihatRepository.load();
  });

  testWidgets('a turn builds only the page newly come near', (t) async {
    t.view.physicalSize = const Size(412, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = ReaderSettings.memory(selected: riwayat)..page = 10;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ReaderScreen(
            mushafs: mushafs,
            variants: variants,
            mutashabihat: mutashabihat,
            settings: s,
          ),
        ),
      ),
    );
    await settle(t);
    for (var i = 0; i < 3; i++) {
      MushafPage.built.clear();
      t.state<BookPagerState>(find.byType(BookPager)).turn(1);
      await settle(t);
      // ignore: avoid_print
      print('turn ${i + 1}: built ${MushafPage.built}');
      // The page come near (measured, then laid out with its hamesh).
      expect(MushafPage.built.toSet(), {12 + i});
      expect(MushafPage.built.length, lessThanOrEqualTo(2));
    }
    expect(s.page, 13);
    // A setting changed: the pages near are drawn again with it.
    MushafPage.built.clear();
    s.setSelected({'warsh'});
    await settle(t);
    expect(MushafPage.built.toSet(), containsAll([12, 13, 14]));
    expect(t.takeException(), isNull);
  });
}
