import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';
import 'package:qiraat_mushaf/ui/usul_guide_sheet.dart';

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
    await variants.ensureLoaded(['khallad', 'khalaf_hamzah']);
    mutashabihat = await MutashabihatRepository.load();
  });

  // Khalaf shown, Khallad and Hafs in the hamesh (the user, 2026-11-18).
  ReaderSettings khalaf(int page) =>
      ReaderSettings.memory(selected: {'khallad', 'khalaf_hamzah'})
        ..page = page
        ..qcfFont = false
        ..compareHafs = true
        ..displayed = 'khalaf_hamzah'
        ..diffAlert = DiffAlert.glow;

  /// The words glowing on [page].
  Future<Set<String>> glowing(
    WidgetTester t,
    int page,
    ReaderSettings settings,
  ) async {
    t.view.physicalSize = const Size(900, 1500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: page,
              quran: mushafs.of(MushafEdition.madani),
              variants: variants,
              mutashabihat: mutashabihat,
              settings: settings,
              showHamesh: true,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    final words = <String>{};
    for (final e in find
        .byWidgetPredicate((w) => w.runtimeType.toString() == '_Alerting')
        .evaluate()) {
      void visit(Element el) {
        if (el.widget case RichText(:final text)) {
          words.add(text.toPlainText().trim());
        }
        el.visitChildren(visit);
      }

      visit(e);
    }
    return words;
  }

  // «الوقف على الهمز» put out: a stop both narrators read alike glows no
  // more; the sakt and the word after it glow together.
  testWidgets('page 3 glows without the stop on the hamza', (t) async {
    final settings = khalaf(3);
    expect(settings.unlitUsul, {'الوقف على الهمز'});
    final lit = await glowing(t, 3, settings);
    for (final word in ['يُؤۡمِنُــونَ', 'بِمُؤۡمِنِينَ', 'أَنُؤۡمِنُ']) {
      expect(lit, isNot(contains(word)));
    }
    for (final word in ['خَلَوۡاْ', 'إِلَىٰ', 'عَــذَابٌ', 'أَلِيــمُۢ']) {
      expect(lit, contains(word));
    }
  });

  // «وَلَوۡ أَنَّهُمۡ ءَامَنُواْ» (البقرة ١٠٣): the word of two usul glows by
  // the lit one, the sakt before its hamza, «الوقف على الهمز» put out (the
  // user, 2026-11-18).
  testWidgets('page 16 glows by the sakt before the hamza', (t) async {
    final settings = khalaf(16);
    final lit = await glowing(t, 16, settings);
    String bare(String s) =>
        s.replaceAll(RegExp('[ً-ٟۖ-ۭـ]'), '');
    final words = lit.map(bare).toSet();
    expect(words, contains(bare('أَنَّهُمۡ')));
    expect(words, contains(bare('ءَامَنُواْ')));
  });

  // «قَدِيرٌ ۝ أَلَمۡ» (البقرة ١٠٦-١٠٧): the sakt across the ayah's end, the
  // two glowing together (the user, 2026-11-18).
  testWidgets('page 17 glows by the sakt across the ayah end', (t) async {
    String bare(String s) =>
        s.replaceAll(RegExp('[ً-ٟۖ-ۭـ]'), '');
    final lit = (await glowing(t, 17, khalaf(17))).map(bare).toSet();
    expect(lit, contains(bare('قَدِيرٌ')));
    expect(lit, contains(bare('أَلَمۡ')));
  });

  // Every asl put out: nothing glows, not even what both read alike (شَاءَ,
  // عَلَيۡهُمۡ).
  testWidgets('every asl put out, page 4 glows nowhere', (t) async {
    final settings = khalaf(4);
    for (final id in ['khalaf_hamzah', 'khallad']) {
      settings.putOutUsul(
        usulOfRiwaya(variants, mushafs.of(MushafEdition.madani), id).keys,
      );
    }
    expect(await glowing(t, 4, settings), isEmpty);
  });
}
