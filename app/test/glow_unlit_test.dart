import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/reading_colors.dart';
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
    for (final e
        in find
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
    String bare(String s) => s.replaceAll(RegExp('[ً-ٟۖ-ۭـ]'), '');
    final words = lit.map(bare).toSet();
    expect(words, contains(bare('أَنَّهُمۡ')));
    expect(words, contains(bare('ءَامَنُواْ')));
  });

  // «قَدِيرٌ ۝ أَلَمۡ» (البقرة ١٠٦-١٠٧): the sakt across the ayah's end, the
  // two glowing together (the user, 2026-11-18).
  testWidgets('page 17 glows by the sakt across the ayah end', (t) async {
    String bare(String s) => s.replaceAll(RegExp('[ً-ٟۖ-ۭـ]'), '');
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

  // «رَّحِيمٞ ۝ وَقَٰتِلُوهُمۡ» (البقرة ١٩٢-١٩٣): the waw doubled in Khalaf's text
  // alone, Khallad's as Hafs's (the user, 2026-11-18).
  testWidgets('the idgham across an ayah end in its own reader alone', (
    t,
  ) async {
    for (final (id, doubled) in [('khallad', false), ('khalaf_hamzah', true)]) {
      await glowing(t, 30, khalaf(30)..displayed = id);
      final ink = t.widget<InkText>(find.byKey(const ValueKey('word:2:193:0')));
      final text = ink.parts?.map((p) => p.$1).join() ?? ink.text;
      expect(text.startsWith('وّ'), doubled, reason: id);
    }
  });

  // Page 33-34 of Khalaf (the user, 2026-11-18): the chain «بَيِّنَةٖ وَّمَن
  // يُّبَدِّلۡ» colours the nun; «وَمَن يَّرۡتَدِدۡ» keeps its shadda; the farsh of
  // «كَثِيرٞ» does not colour «وَّمَنَٰفِعُ» drawn with it.
  testWidgets('Khalaf idgham chains, yartadid, farsh beside it', (t) async {
    List<(String, Color?)> parts(String key) =>
        t.widget<InkText>(find.byKey(ValueKey('word:$key'))).parts!;
    await glowing(t, 33, khalaf(33)..displayed = 'khalaf_hamzah');
    expect(parts('2:211:7').last, ('ن', ReadingColors.idghamBilaGhunna));
    await glowing(t, 34, khalaf(34)..displayed = 'khalaf_hamzah');
    expect(parts('2:217:37')[4].$1, allOf(startsWith('ي'), contains('ّ')));
    final kathir = parts('2:219:7');
    final space = kathir.indexWhere((p) => p.$1.trim().isEmpty);
    expect(kathir.skip(space + 2).every((p) => p.$2 == null), isTrue);
    expect(kathir.first.$2, isNotNull);
  });
}
