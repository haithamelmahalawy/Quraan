import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/reader_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Mushafs mushafs;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    mushafs = await Mushafs.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh', 'khalaf_hamzah']);
    mutashabihat = await MutashabihatRepository.load();
  });

  Future<void> show(
    WidgetTester t,
    Size size, {
    VariantRepository? repository,
    bool margins = true,
    QuranRepository? quran,
    int number = 3,
    ReaderSettings? settings,
    bool reader = false,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    final s = settings ?? ReaderSettings.memory(selected: {'warsh'});
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light).copyWith(
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: reader
              ? ReaderScreen(
                  mushafs: mushafs,
                  variants: variants,
                  mutashabihat: mutashabihat,
                  settings: s,
                )
              : Scaffold(
                  body: MushafPage(
                    page: number,
                    quran: quran ?? mushafs.of(MushafEdition.madani),
                    variants: repository ?? variants,
                    mutashabihat: mutashabihat,
                    settings: s,
                    showHamesh: margins,
                    onWordTap: (_, _) {},
                  ),
                ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('a chain of Khalaf\'s idgham keeps each of its words', (
    t,
  ) async {
    final s = ReaderSettings.memory(selected: {'khalaf_hamzah'})
      ..displayed = 'khalaf_hamzah'
      ..compareHafs = true
      ..qcfFont = false;
    await show(t, const Size(700, 1700), settings: s, number: 4);
    final drawn = [
      for (final r in t.widgetList<RichText>(find.byType(RichText)))
        r.text.toPlainText().replaceAll('ـ', ''),
    ];
    final i = drawn.indexWhere((d) => d.contains('ظُلُمَٰتٞ'));
    final after = drawn.skip(i).toSet().toList();
    expect(after.indexWhere((d) => d.contains('بَرۡقٞ')), isNonNegative);
    expect(after.indexWhere((d) => d.contains('جۡعَلُونَ')), isNonNegative);
  });
}
