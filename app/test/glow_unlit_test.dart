import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
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

  // «مَّفۡرُوضٗا ۝ وَلَأُضِلَّنَّهُمۡ» (النساء ١١٨-١١٩): Khalaf's idgham without
  // ghunna across the ayah's end, the two glowing together (the user,
  // 2026-11-19).
  testWidgets('page 97 glows by the idgham across the ayah end', (t) async {
    String bare(String s) => s.replaceAll(RegExp('[ً-ٟۖ-ۭـ]'), '');
    final lit = (await glowing(t, 97, khalaf(97))).map(bare).toSet();
    expect(lit, contains(bare('مَّفۡرُوضٗا')));
    expect(lit, contains(bare('وَلَأُضِلَّنَّهُمۡ')));
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

  // Page 71 of Khalaf (the user, 2026-11-18): «أَن يُّغَلَّ» drawn as one, the
  // ya in the idgham's colour, the rest of his farsh «يُغَلَّ» in the colour of
  // the difference.
  testWidgets('Khalaf idgham into his farsh colours the farsh', (t) async {
    List<(String, Color?)> parts(String key) =>
        t.widget<InkText>(find.byKey(ValueKey('word:$key'))).parts!;
    await glowing(t, 71, khalaf(71));
    final yughall = parts('3:161:3');
    final space = yughall.indexWhere((p) => p.$1.trim().isEmpty);
    expect(yughall[space + 1].$2, ReadingColors.idghamBilaGhunna);
    final rest = yughall.skip(space + 2).where((p) => p.$1.trim().isNotEmpty);
    expect(rest, isNotEmpty);
    expect(
      rest.every((p) => p.$2 != null && p.$2 != ReadingColors.idghamBilaGhunna),
      isTrue,
    );
  });

  // Page 86 of Khalaf (the user, 2026-11-19): «وَلِيّٗا وَّكَفَىٰ» drawn as one,
  // the waw in the idgham's colour, the fa of «كَفَىٰ» in the imala's under
  // its sign.
  testWidgets('Khalaf idgham into a word of imala colours its letter', (
    t,
  ) async {
    List<(String, Color?)> parts(String key) =>
        t.widget<InkText>(find.byKey(ValueKey('word:$key'))).parts!;
    await glowing(t, 86, khalaf(86));
    final kafa = parts('4:45:5');
    final space = kafa.indexWhere((p) => p.$1.trim().isEmpty);
    expect(kafa[space + 1].$2, ReadingColors.idghamBilaGhunna);
    final fa = kafa.skip(space + 1).firstWhere((p) => p.$1.contains('ف'));
    expect(fa.$1, contains(imalaSign));
    expect(fa.$2, isNotNull);
    expect(fa.$2, isNot(ReadingColors.idghamBilaGhunna));
  });

  // «جَمِيعٗا وَّلَقَد جَّآءَتۡهُمۡ» (المائدة ٣٢): the chain's last word with its
  // imala sign under the jim; «وَرَحۡمَةٗ وَّبُشۡرَىٰ» (النحل ٨٩): drawn on its own
  // in the chain, «رَحۡمَة» not coloured by the imala of «بُشۡرَىٰ» (the user,
  // 2026-11-19).
  testWidgets('Khalaf idgham chains keep each word its own imala', (t) async {
    InkText ink(String key) =>
        t.widget<InkText>(find.byKey(ValueKey('word:$key')));
    String text(InkText i) => i.parts?.map((p) => p.$1).join() ?? i.text;
    await glowing(t, 113, khalaf(113));
    expect(text(ink('5:32:28')), contains(imalaSign));
    await glowing(t, 277, khalaf(277));
    expect(text(ink('16:89:22')), contains(imalaSign));
    final rahma = ink('16:89:21').parts!;
    expect(
      rahma.every(
        (p) => p.$2 == null || p.$2 == ReadingColors.idghamBilaGhunna,
      ),
      isTrue,
    );
  });

  // Hafs shown, page 130 (the user, 2026-11-19): «فِتۡنَتُهُمۡ» of Hamza's farsh
  // «يَكُن فِتۡنَتَهُمۡ» in the farsh colour, its mim in the sakt's red.
  testWidgets('a word of a two-word farsh coloured beside its sakt', (t) async {
    await glowing(t, 130, khalaf(130)..displayed = 'hafs');
    final parts = t
        .widget<InkText>(find.byKey(const ValueKey('word:6:23:3')))
        .parts!
        .where((p) => p.$1.trim().isNotEmpty)
        .toList();
    expect(parts.first.$2, isNotNull);
    expect(parts.first.$2, isNot(ReadingColors.saktHamza));
    expect(parts.last.$2, ReadingColors.saktHamza);
  });

  // «مُكَآءٗ وَّتَصۡدِيَةٗ» (الأنفال ٣٥) drawn as one by Khalaf's idgham: the sad
  // in the ishmam's colour as Khallad's (the user, 2026-11-20); the sakt
  // (وَّمَتَٰعٌۜ) and the ha's damma (وُّجُوهِهُمُ) of the second word too.
  testWidgets('Khalaf idgham into a word of ishmam colours its sad', (t) async {
    Color? colorOf(String key, String letter) => t
        .widget<InkText>(find.byKey(ValueKey('word:$key')))
        .parts!
        .firstWhere((p) => p.$1.startsWith(letter))
        .$2;
    await glowing(t, 181, khalaf(181));
    expect(colorOf('8:35:6', 'ص'), ReadingColors.ishmam);
    await glowing(t, 6, khalaf(6));
    expect(colorOf('2:36:15', 'ع'), ReadingColors.saktHamza);
    await glowing(t, 325, khalaf(325));
    expect(colorOf('21:39:7', 'هُ'), isNotNull);
  });

  // «الإدغام بلا غنة» put out (the user, 2026-11-24): «رَّحِيمٞ ۝ وَّقَٰتِلُوهُمۡ»
  // (البقرة ١٩٢-١٩٣) glows no more, the second word of none of its own;
  // «إِحۡسَٰنٗا وَّتَوۡفِيقًا» (النساء ٦٢), drawn as one, glows on its second
  // word alone, by its sakt.
  testWidgets('the idgham put out, its words glow by their own usul', (
    t,
  ) async {
    String bare(String s) => s.replaceAll(RegExp('[ً-ٟۖ-ۭـ]'), '');
    final lit30 = (await glowing(
      t,
      30,
      khalaf(30)..setUsulLit('الإدغام بلا غنة', false),
    )).map(bare).toSet();
    expect(lit30, isNot(contains(bare('وَّقَٰتِلُوهُمۡ'))));
    expect(lit30, isNot(contains(bare('رَّحِيمٞ'))));
    await glowing(t, 88, khalaf(88)..setUsulLit('الإدغام بلا غنة', false));
    final pair = find.ancestor(
      of: find.byKey(const ValueKey('word:4:62:14')),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Alerting',
      ),
    );
    expect(pair, findsOneWidget);
    expect(
      find.descendant(of: pair, matching: find.byType(FractionallySizedBox)),
      findsOneWidget,
    );
  });

  // The stop on the hamza of the second word drawn as one by the idgham
  // (فِرَٰشٗا وَّٱلسَّمَآءَ، أَندَادٗا وَّأَنتُمۡ): its hamza purple (the user,
  // 2026-11-24).
  testWidgets('the second word of the idgham keeps its hamza purple', (
    t,
  ) async {
    await glowing(t, 4, khalaf(4));
    for (final key in ['2:22:4', '2:22:20']) {
      final parts = t.widget<InkText>(find.byKey(ValueKey('word:$key'))).parts!;
      final space = parts.indexWhere((p) => p.$1.trim().isEmpty);
      expect(
        parts.skip(space + 1).any((p) => p.$2 == ReadingColors.hamza),
        isTrue,
        reason: key,
      );
    }
  });

  // Khallad's sakt on the article and on «شيء» of two faces (the user,
  // 2026-11-24): alone, «بوجهين»; with Khalaf, beside his sakt.
  testWidgets('Khallad\'s sakt of two faces in the key', (t) async {
    await glowing(t, 2, khalaf(2)..displayed = null);
    expect(
      find.textContaining('ولخلاد وجه آخر بعدم السكت وهو المقدّم'),
      findsWidgets,
    );
    final alone = ReaderSettings.memory(selected: {'khallad'})
      ..page = 2
      ..qcfFont = false
      ..diffAlert = DiffAlert.glow;
    await glowing(t, 2, alone);
    expect(find.text('بوجهين: السكت، وعدم السكت وهو المقدّم'), findsWidgets);
  });

  // «وَلِيدٗا وَّلَبِثتَّ» (الشعراء ١٨), drawn as one, «الإدغام بلا غنة» put out:
  // «لَبِثتَّ» glows still by its own idgham (the user, 2026-11-24).
  testWidgets('the second word of the idgham glows by its own idgham', (
    t,
  ) async {
    await glowing(t, 367, khalaf(367)..setUsulLit('الإدغام بلا غنة', false));
    final pair = find.ancestor(
      of: find.byKey(const ValueKey('word:26:18:4')),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Alerting',
      ),
    );
    expect(pair, findsOneWidget);
    expect(
      find.descendant(of: pair, matching: find.byType(FractionallySizedBox)),
      findsOneWidget,
    );
  });
}
