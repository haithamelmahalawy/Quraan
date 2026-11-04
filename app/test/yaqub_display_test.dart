import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/usul_text.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';
import 'package:qiraat_mushaf/ui/hamza_replacement_mark.dart';
import 'package:qiraat_mushaf/ui/letter_above_mark.dart';
import 'package:qiraat_mushaf/ui/quran_word_text.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/reading_colors.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded([
      'ruways',
      'rawh',
      'hisham',
      'warsh',
      'shubah',
      'khalaf_hamzah',
      'khallad',
      'qalun',
      'bazzi',
      'qunbul',
      'ibn_wardan',
      'ibn_jammaz',
    ]);
    mutashabihat = await MutashabihatRepository.load();
  });
  Future<void> page(
    WidgetTester t,
    String? displayed, {
    int number = 3,
    Set<String>? selected,
    bool qcf = false,
    DiffAlert? alert,
    MarginLayout layout = MarginLayout.organized,
    bool landscape = false,
  }) async {
    t.view.physicalSize = landscape
        ? const Size(2000, 1080)
        : const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final settings =
        ReaderSettings.memory(
            selected: {
              ...(selected ?? {'ruways', 'rawh', 'hisham', 'warsh'}),
              ?displayed,
            },
          )
          ..displayed = displayed
          ..marginLayout = layout
          ..diffAlert = alert;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: number,
              qcf: qcf,
              quran: quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: settings,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  Finder word(int s, int a, int w) => find.byKey(ValueKey('word:$s:$a:$w'));

  testWidgets('Ashab al-Silah change the hamza in the circle of Warsh', (
    t,
  ) async {
    for (final (id, number, a, w, letter) in [
      // ٱلسُّفَهَآءُ أَلَآ: a waw, all of them.
      ('qalun', 3, 13, 12, 'و'),
      ('bazzi', 3, 13, 12, 'و'),
      ('qunbul', 3, 13, 12, 'و'),
      ('ibn_wardan', 3, 13, 12, 'و'),
      ('ibn_jammaz', 3, 13, 12, 'و'),
      // يَشَآءُ إِلَىٰ: the waw their first face; Qalun's the tasheel.
      ('bazzi', 22, 142, 18, 'و'),
      ('ibn_wardan', 22, 142, 18, 'و'),
      ('qalun', 22, 142, 18, ''),
    ]) {
      await page(t, id, number: number, selected: {id});
      final mark = t.widget<HamzaReplacementMark>(
        find.ancestor(
          of: word(2, a, w),
          matching: find.byType(HamzaReplacementMark),
        ),
      );
      expect(mark.letter, letter, reason: '$id 2:$a:$w');
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Ashab al-Silah ease the hamza with the tasheel dot', (t) async {
    for (final (id, number, a, w, hamza) in [
      // ءَٰا۬نذَرْتَهُمُۥ: the source's dot, over the alif.
      ('qalun', 3, 6, 5, 'أَ'),
      // هَٰؤُلَآ۟ إِن: the first hamza, the sifr on its alif.
      ('qalun', 6, 31, 11, 'ءِ'),
      ('bazzi', 6, 31, 11, 'ءِ'),
      // The second: taken for a wasl alif, or written as Hafs.
      ('qunbul', 6, 31, 12, 'إِ'),
      ('ibn_wardan', 6, 31, 12, 'إِ'),
      ('ibn_jammaz', 6, 31, 12, 'إِ'),
      ('qalun', 20, 133, 3, 'إِ'),
      // إِسۡرَٰٓءِ۬يلَ: the hamza after the alif, not the first.
      ('ibn_wardan', 7, 40, 1, 'ءِ'),
      ('ibn_jammaz', 7, 40, 1, 'ءِ'),
    ]) {
      await page(t, id, number: number, selected: {id});
      final mark = t.widget<HamzaReplacementMark>(
        find.ancestor(
          of: word(2, a, w),
          matching: find.byType(HamzaReplacementMark),
        ),
      );
      expect(mark.letter, isEmpty, reason: '$id 2:$a:$w');
      expect(
        mark.originalHamza?.replaceAll('۬', ''),
        hamza,
        reason: '$id 2:$a:$w',
      );
      // Nor the font's round blots.
      expect(
        t.widget<InkText>(word(2, a, w)).parts?.map((p) => p.$1).join() ??
            t.widget<InkText>(word(2, a, w)).text,
        isNot(matches(RegExp('[۬۟]'))),
        reason: '$id 2:$a:$w',
      );
      expect(t.takeException(), isNull);
    }
    // In the hamesh too (ءَٰا۬عْجَمِيّٞ وَعَرَبِيّٞ, فصلت 44).
    await page(
      t,
      'qalun',
      number: 481,
      selected: {'qalun', 'bazzi', 'ibn_wardan'},
    );
    expect(
      t
          .widgetList<HamzaReplacementMark>(find.byType(HamzaReplacementMark))
          .any(
            (m) =>
                m.letter.isEmpty &&
                m.text.contains('وَعَرَبِيّ') &&
                !HamzaReplacementMark.seatText(m.text, m.offset).contains('۬'),
          ),
      isTrue,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets("Abu Ja'far's ikhfa colours the letter it is hidden before", (
    t,
  ) async {
    final number = quran.ayah(2, 59).page;
    for (final shown in ['ibn_wardan', 'qalun']) {
      await page(
        t,
        shown,
        number: number,
        selected: {'qalun', 'ibn_wardan'},
        alert: DiffAlert.glow,
      );
      // «قَوۡلًا غَيۡرَ»: the tanween, and the ghayn after it.
      final ghayr = t.widget<InkText>(word(2, 59, 4));
      final colour = ReadingColors.forLabel('الإخفاء');
      expect(ghayr.parts?.first.$2, colour, reason: shown);
      expect(ghayr.parts?.skip(1).every((p) => p.$2 == null), isTrue);
      for (final w in [3, 4]) {
        expect(
          find.ancestor(
            of: word(2, 59, w),
            matching: find.byWidgetPredicate(
              (x) => x.runtimeType.toString() == '_Alerting',
            ),
          ),
          findsOneWidget,
          reason: '$shown 2:59:$w',
        );
      }
      // Below, with both words.
      final item = find.byWidgetPredicate(
        (x) =>
            x.key is ValueKey<String> &&
            (x.key! as ValueKey<String>).value.startsWith(
              'usul-reference:الإخفاء:2:59:3:',
            ),
      );
      expect(item, findsOneWidget, reason: shown);
      expect(
        find.descendant(
          of: item,
          matching: find.byWidgetPredicate(
            (x) => x is RichText && x.text.toPlainText().contains(' غَيۡرَ'),
          ),
        ),
        findsWidgets,
        reason: shown,
      );
      expect(t.takeException(), isNull);
    }
  });

  test(
    '«فادارأتم»: a small alif for Abu Ja\'far, the hamza for the others',
    () {
      String written(String id) =>
          variants.at([id], 2, 72, 3).firstWhere((v) => v.text.isNotEmpty).text;
      for (final id in ['ibn_wardan', 'ibn_jammaz']) {
        expect(written(id), 'فَٱدَّٰرَٰتُمُۥ', reason: id);
      }
      // «وَمِيكَٰٓئِلَ»: one note for Qalun and Abu Ja'far, the dagger alif.
      final mikail = variants.at(['qalun'], 2, 98, 7).single;
      expect(mikail.text, contains('ٰ'));
      expect(mikail.description, 'بهمزة مكسورة بعد الألف');
      for (final id in ['warsh', 'ibn_wardan', 'ibn_jammaz']) {
        final v = variants.at([id], 2, 98, 7).single;
        expect(v.text, mikail.text, reason: id);
        expect(v.description, mikail.description, reason: id);
      }
      for (final id in ['bazzi', 'qunbul']) {
        expect(
          variants.at([id], 2, 98, 7).single.description,
          'بهمزة مكسورة بعد الألف وبعدها ياء ساكنة',
          reason: id,
        );
      }
      // «أَنۢبِئَآءَ»: its ya the hamza, not «بالهمز».
      for (final id in ['qalun', 'warsh']) {
        expect(
          variants
              .at([id], 2, 91, 23)
              .where((v) => v.rule == 'hamza_zaida')
              .single
              .description,
          'بإبدال الياء همزة',
          reason: id,
        );
      }
      // Drawn small in this word alone, as the print's; not in «قَرَأۡتَ».
      expect(smallHamzaAlifParts([('قَرَأۡتَ', null)]), isNull);
      expect(smallHamzaAlifParts([('فَٱدَّٰرَأۡتُمُۥ', null)])?[1].$3, isTrue);
      for (final id in ['qalun', 'bazzi', 'qunbul']) {
        // As Hafs's on the page: an alif with the hamza on it.
        expect(written(id), 'فَٱدَّٰرَأۡتُمُۥ', reason: id);
        expect(variants.at([id], 2, 72, 3), hasLength(1), reason: id);
      }
    },
  );

  test("no word of Abu Ja'far is lost, and «يأمركم» is usul", () {
    // Each row on the words its text reads; these alone are read as one or
    // leave a word out.
    const asOne = {'40:26:11', '53:50:2', '57:24:9'};
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      for (final v in variants.allOf(id)) {
        if (v.text.trim().isEmpty) continue;
        final n = v.text.trim().split(RegExp(r'\s+')).length;
        final place = '${v.surah}:${v.ayah}:${v.word}';
        if (!asOne.contains(place)) {
          expect(n, greaterThanOrEqualTo(v.count), reason: '$id $place');
        }
      }
      final v = variants
          .at([id], 2, 67, 6)
          .where((v) => v.rule == 'ibdal_single')
          .single;
      expect(v.count, 1);
      expect(v.text, startsWith('يَامُرُ'));
      expect(variants.at([id], 2, 67, 6).where((v) => v.inHamesh), isEmpty);
      expect(variants.at([id], 2, 67, 7).where((v) => v.word == 6), isEmpty);
      // آل عمران ٨٠: its raf' alone in the farsh, «وَلَا» untouched.
      expect(variants.at([id], 3, 80, 0).where((v) => v.word == 0), isEmpty);
      final raf = variants.at([id], 3, 80, 1).where((v) => !v.isUsul).single;
      expect(raf.description, 'برفع الراء');
    }
  });

  testWidgets('a hamza dropped or added colours its word on the page', (
    t,
  ) async {
    const ashab = {'qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz'};
    for (final (shown, a, w, n) in [
      // «مُسۡتَهۡزُونَ»: Abu Ja'far's, shown or compared.
      ('ibn_jammaz', 14, 15, 3),
      ('qalun', 14, 15, 3),
      // «يَامُرُكُمُۥ»: his ibdal, told by no rule of its own.
      ('ibn_jammaz', 93, 21, null),
      // «ٱلنَّبِيٓـِٕـۧنَ»: Qalun's added hamza against al-Bazzi.
      ('qalun', 61, 51, null),
      ('bazzi', 61, 51, null),
    ]) {
      await page(t, shown, number: n ?? quran.ayah(2, a).page, selected: ashab);
      final ink = t.widget<InkText>(word(2, a, w));
      expect(
        {ink.style.color, ...?ink.parts?.map((p) => p.$2)},
        contains(ReadingColors.hamza),
        reason: '$shown 2:$a:$w',
      );
      expect(t.takeException(), isNull);
    }
    // Shown alone, nothing of it is coloured.
    await page(t, 'ibn_jammaz', number: 3, selected: {'ibn_jammaz'});
    final alone = t.widget<InkText>(word(2, 14, 15));
    expect({
      alone.style.color,
      ...?alone.parts?.map((p) => p.$2),
    }, isNot(contains(ReadingColors.hamza)));
  });

  testWidgets("Abu Ja'far's إسرائيل is coloured against the others", (t) async {
    for (final shown in ['ibn_wardan', 'qalun']) {
      await page(
        t,
        shown,
        number: 7,
        selected: {'qalun', 'bazzi', 'ibn_wardan'},
      );
      final w = t.widget<InkText>(word(2, 40, 1));
      // Its hamza hidden under the dot, which takes the hamza's colour.
      final dot = t.widgetList<HamzaReplacementMark>(
        find.ancestor(
          of: word(2, 40, 1),
          matching: find.byType(HamzaReplacementMark),
        ),
      );
      final colours = {
        w.style.color,
        for (final m in dot) m.color,
        ...?w.parts?.map((p) => p.$2),
      };
      expect(colours, contains(ReadingColors.hamza), reason: shown);
      // In the usul below, by its own chapter.
      expect(
        find.byWidgetPredicate(
          (x) =>
              x.key is ValueKey<String> &&
              (x.key! as ValueKey<String>).value.startsWith(
                'usul-reference:',
              ) &&
              (x.key! as ValueKey<String>).value.endsWith(':2:40:1:ibn_wardan'),
        ),
        findsOneWidget,
        reason: shown,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'sequential notes stay on the page side and continue below in order',
    (t) async {
      for (final configuration in [
        (false, 4),
        (false, 5),
        (true, 4),
        (true, 5),
      ]) {
        final (landscape, number) = configuration;
        await page(
          t,
          null,
          number: number,
          selected: {'ruways', 'warsh'},
          layout: MarginLayout.sequential,
          landscape: landscape,
        );
        final right = find.byKey(const ValueKey('sequential-right-margin'));
        final left = find.byKey(const ValueKey('sequential-left-margin'));
        final isRight = quran.isRightPage(number);
        expect(right, isRight ? findsOneWidget : findsNothing);
        expect(left, isRight ? findsNothing : findsOneWidget);
        final bottom = find.byKey(const ValueKey('sequential-bottom-notes'));
        if (!landscape && number == 4) expect(bottom, findsOneWidget);
        if (bottom.evaluate().isNotEmpty) {
          await t.ensureVisible(bottom);
          await t.pump();
        }
        final positions = <int>[];
        var usul = false, farsh = false;
        for (final rail in [isRight ? right : left, bottom]) {
          final notes = find.descendant(
            of: rail,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is KeyedSubtree &&
                  w.key is ValueKey<String> &&
                  ((w.key as ValueKey<String>).value.startsWith(
                        'sequential-usul:',
                      ) ||
                      (w.key as ValueKey<String>).value.startsWith(
                        'sequential-farsh:',
                      )),
            ),
          );
          for (final widget in t.widgetList<KeyedSubtree>(notes)) {
            final key = (widget.key as ValueKey<String>).value;
            usul |= key.startsWith('sequential-usul:');
            farsh |= key.startsWith('sequential-farsh:');
            positions.add(int.parse(key.split(':')[1]));
          }
        }
        expect(usul, isTrue);
        if (number == 4) expect(farsh, isTrue);
        expect(positions, isNotEmpty);
        if (landscape) {
          final scroll = t
              .widget<SingleChildScrollView>(
                find.byKey(const ValueKey('landscape-page-scroll')),
              )
              .controller!;
          scroll.jumpTo(150);
          await t.pump();
          await t.pump();
          expect(scroll.offset, 150);
        }
        expect(t.takeException(), isNull);
      }
      await page(t, null, number: 4, selected: {'ruways', 'warsh'});
      expect(find.byKey(const ValueKey('sequential-reader')), findsNothing);
      expect(find.byKey(const ValueKey('usul-notes')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  Finder mark(Finder w) =>
      find.ancestor(of: w, matching: find.byType(HamzaReplacementMark));

  testWidgets('Yaqub keeps malik while opposing margin says only delete alif', (
    t,
  ) async {
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, number: 1, selected: {id, 'hisham', 'khalaf_hamzah'});
      expect(
        t.widget<InkText>(word(1, 4, 0)).text.replaceAll('ـ', ''),
        'مَٰلِكِ',
      );
      final note = find.byKey(const ValueKey('margin-reference:1:4:0'));
      expect(note, findsOneWidget);
      expect(
        find.descendant(of: note, matching: find.textContaining('بحذف الألف')),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: note,
          matching: find.textContaining('الميم الأولى'),
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'sequential groups each origin once and anchors farsh by its line',
    (t) async {
      await page(
        t,
        null,
        number: 267,
        selected: {'rawh', 'khalaf_hamzah', 'khallad'},
        layout: MarginLayout.sequential,
      );
      final sakt = find.text('السكت قبل الهمز:');
      expect(sakt, findsOneWidget);
      final box = find.ancestor(
        of: sakt,
        matching: find.byKey(const ValueKey('usul-notes')),
      );
      expect(box, findsOneWidget);
      expect(
        find
            .descendant(of: box, matching: find.byType(QuranWordText))
            .evaluate()
            .length,
        greaterThan(3),
      );
      final farsh = find.byKey(const ValueKey('margin-reference:16:2:1'));
      final side = find.byKey(const ValueKey('sequential-right-margin'));
      expect(farsh, findsOneWidget);
      final sideNotes = find.descendant(
        of: side,
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('margin-reference:'),
        ),
      );
      expect(sideNotes, findsWidgets);
      for (final widget in t.widgetList(sideNotes)) {
        final key = (widget.key as ValueKey<String>).value;
        final parts = key.split(':').skip(1).map(int.parse).toList();
        expect(
          (t.getTopLeft(find.byKey(widget.key!)).dy -
                  t.getTopLeft(word(parts[0], parts[1], parts[2])).dy)
              .abs(),
          lessThan(65),
        );
      }
      expect(t.takeException(), isNull);
      await page(
        t,
        null,
        number: 3,
        selected: {'ruways', 'hisham'},
        layout: MarginLayout.sequential,
      );
      expect(find.text('إشمام حركة بحركة:'), findsOneWidget);
      for (final narrator in ['ruways', 'hisham']) {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith(
                  'usul-reference:الإشمام (إشمام حركة بحركة):',
                ) &&
                (w.key as ValueKey<String>).value.contains(narrator),
          ),
          findsWidgets,
        );
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Rawh malaikatu is farsh and ordinary Hamza madd is hidden', (
    t,
  ) async {
    for (final id in [null, 'rawh', 'ruways']) {
      await page(t, id, number: 267, selected: {'rawh', 'ruways', 'hafs'});
      final text = t.widget<InkText>(word(16, 2, 1)).text;
      expect(text, endsWith(id == 'rawh' ? 'ةُ' : 'ةَ'));
      expect(text, contains('ٓ'));
      expect(
        find.byKey(const ValueKey('margin-reference:16:2:1')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    }
    for (final id in [null, 'khallad', 'khalaf_hamzah']) {
      await page(
        t,
        id,
        number: 267,
        selected: {'khallad', 'khalaf_hamzah'},
        alert: DiffAlert.glow,
      );
      final target = word(16, 2, 1);
      final ink = t.widget<InkText>(target);
      expect(ink.style.color, MushafColors.ink);
      expect(
        find.ancestor(
          of: target,
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_Alerting',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              RegExp(r'^usul-reference:(المدود|المد المتصل|المد المنفصل):')
                  .hasMatch((w.key as ValueKey<String>).value),
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Yaqub tasal on page 18 uses the nabra in page and margin', (
    t,
  ) async {
    for (final id in [null, 'ruways', 'rawh']) {
      await page(t, id, number: 18, selected: {'ruways', 'rawh', 'hafs'});
      final text = t.widget<InkText>(word(2, 119, 6)).text.replaceAll('ـ', '');
      expect(text, id == null ? 'تُسَۡٔلُ' : 'تَسَۡٔلۡ');
      expect(text, isNot(contains('أ')));
      final note = find.byKey(const ValueKey('margin-reference:2:119:6'));
      expect(note, findsOneWidget);
      if (id == null) {
        expect(
          find.descendant(of: note, matching: find.textContaining('تَسۡـَٔلۡ')),
          findsWidgets,
        );
      }
      expect(t.takeException(), isNull);
    }
  });

  test('Hafs remains the baseline when selected for comparison', () {
    final settings = ReaderSettings.memory(selected: {'hafs', 'ruways'});
    settings.displayed = null;
    expect(settings.displayed, isNull);
    settings.displayed = 'ruways';
    expect(settings.displayed, 'ruways');
    settings.displayed = 'hafs';
    expect(settings.displayed, isNull);
  });

  testWidgets(
    'broken mim after broken ha in qulubihim is listed, coloured and glowing',
    (t) async {
      for (final id in [null, 'ruways', 'rawh']) {
        await page(
          t,
          id,
          number: 14,
          selected: {'ruways', 'rawh', 'hafs'},
          alert: DiffAlert.glow,
        );
        final w = word(2, 93, 16);
        final ink = t.widget<InkText>(w);
        expect(
          ink.text.replaceAll('ـ', ''),
          contains(id == null ? 'هِمُ' : 'هِمِ'),
        );
        expect(ink.style.color, isNot(MushafColors.ink));
        expect(
          find.ancestor(
            of: w,
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_Alerting',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith(
                  'usul-reference:ميم الجمع:2:93:16:',
                ),
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('page 14 displays light yunzilla for Yaqub with farsh margin', (
    t,
  ) async {
    for (final id in [null, 'ruways', 'rawh']) {
      await page(t, id, number: 14, selected: {'ruways', 'rawh', 'hafs'});
      expect(
        compareReadings(
          repository: variants,
          ayah: quran.ayah(2, 90),
          word: 11,
          displayed: id,
          selected: ['ruways', 'rawh', 'hafs'],
        ).where((v) => v.inHamesh),
        hasLength(id == null ? 2 : 1),
      );
      final text = t.widget<InkText>(word(2, 90, 11)).text.replaceAll('ـ', '');
      expect(text, id == null ? 'يُنَزِّلَ' : 'يُنزِلَ');
      expect(
        find.byKey(const ValueKey('margin-reference:2:90:11')),
        findsOneWidget,
        reason: '$id',
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'khatiatuhu keeps full Hafs spelling without a false difference for Yaqub',
    (t) async {
      for (final id in [null, 'ruways', 'rawh']) {
        await page(t, id, number: 12, selected: {'ruways', 'rawh', 'hafs'});
        final ink = t.widget<InkText>(word(2, 81, 6));
        expect(
          ink.text.replaceAll('ـ', ''),
          quran.ayah(2, 81).words[6].replaceAll('ـ', ''),
        );
        expect(ink.style.color, MushafColors.ink);
        expect(
          find.byKey(const ValueKey('margin-reference:2:81:6')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('Yaqub tarjiun is written actively and listed in farsh', (
    t,
  ) async {
    for (final id in [null, 'ruways', 'rawh']) {
      await page(
        t,
        id,
        number: quran.ayah(2, 28).page,
        selected: {'ruways', 'rawh', if (id != null) 'shubah'},
      );
      final text = t.widget<InkText>(word(2, 28, 12)).text;
      expect(text, startsWith(id == null ? 'تُ' : 'تَ'));
      expect(text, contains(id == null ? 'جَ' : 'جِ'));
      final note = find.byKey(const ValueKey('margin-reference:2:28:12'));
      expect(note, findsOneWidget);
      expect(
        find.descendant(
          of: note,
          matching: find.textContaining('بفتح التاء وكسر الجيم'),
        ),
        id == null ? findsWidgets : findsNothing,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Ruways bi-l-kafirin imala appears on kaf and in usul margin', (
    t,
  ) async {
    for (final id in [null, 'ruways']) {
      await page(t, id, number: 4, selected: {'ruways'});
      final text = t.widget<InkText>(word(2, 19, 18)).text;
      expect(
        lettersOf(text).singleWhere((c) => c.contains(imalaSign)),
        startsWith('ك'),
      );
      expect(
        find.byKey(const ValueKey('usul-reference:الإمالة:2:19:18:ruways')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Ruways kabir writes both consonants in page and own margin', (
    t,
  ) async {
    for (final id in [null, 'ruways', 'rawh']) {
      await page(t, id, number: 4, selected: {'ruways'});
      final first = lettersOf(t.widget<InkText>(word(2, 20, 16)).text);
      final second = lettersOf(t.widget<InkText>(word(2, 20, 17)).text);
      expect(first.last == 'ب', id == 'ruways');
      expect(second.first.contains('ّ'), id == 'ruways');
      final note = find.byKey(
        const ValueKey('usul-reference:الإدغام الكبير:2:20:16:ruways'),
      );
      expect(note, findsOneWidget);
      final example = t
          .widget<QuranWordText>(
            find.descendant(of: note, matching: find.byType(QuranWordText)),
          )
          .text
          .split(' ');
      expect(lettersOf(example.first).last, 'ب');
      expect(lettersOf(example.last).first, contains('ّ'));
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Ruways kabir colours and glows both Quran words', (t) async {
    await page(
      t,
      'ruways',
      number: quran.ayah(2, 176).page,
      // Against Hafs: Ruways shown alone has nothing coloured.
      selected: {'ruways', 'hafs'},
      alert: DiffAlert.glow,
    );
    for (final target in [word(2, 176, 4), word(2, 176, 5)]) {
      expect(target, findsOneWidget);
      expect(t.widget<InkText>(target).style.color, isNot(MushafColors.ink));
      expect(
        find.ancestor(
          of: target,
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_Alerting',
          ),
        ),
        findsOneWidget,
      );
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('Yaqub early Baqara farsh is written in the Quran text', (
    t,
  ) async {
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, number: 25, selected: {id, 'hafs'});
      expect(t.widget<InkText>(word(2, 165, 17)).text, 'تَرَى');
      expect(
        find.byKey(const ValueKey('margin-reference:2:165:17')),
        findsOneWidget,
      );

      await page(t, id, number: 27, selected: {id, 'hafs'});
      expect(t.widget<InkText>(word(2, 177, 1)).text, contains('ُ'));
      final hafs = find.byKey(const ValueKey('margin-reference:2:177:1'));
      expect(hafs, findsOneWidget);
      expect(
        t
            .widgetList<Text>(
              find.descendant(of: hafs, matching: find.byType(Text)),
            )
            .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
            .any((text) => text.contains(quran.ayah(2, 177).words[1])),
        isTrue,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('tanween before ilayhi is not treated as a hamza pair', (
    t,
  ) async {
    await page(
      t,
      'ruways',
      number: 27,
      selected: {'ruways'},
      alert: DiffAlert.glow,
    );
    for (final target in [word(2, 178, 22), word(2, 178, 23)]) {
      final ink = t.widget<InkText>(target);
      expect(ink.style.color, MushafColors.ink);
      expect(
        find.ancestor(
          of: target,
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_Alerting',
          ),
        ),
        findsNothing,
      );
    }
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.contains(':2:178:23:'),
      ),
      findsNothing,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('extra ya uses the small silah sign in the Quran text', (
    t,
  ) async {
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, number: quran.ayah(2, 40).page, selected: {id});
      expect(t.widget<InkText>(word(2, 40, 12)).text, 'فَٱرۡهَبُونِۦ');
      await page(t, id, number: quran.ayah(2, 186).page, selected: {id});
      // With the stop sign of the Hafs page.
      expect(t.widget<InkText>(word(2, 186, 10)).text, 'دَعَانِۦۖ');
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('routine madd and legacy prose never become Quran words', (
    t,
  ) async {
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, number: 23, selected: {id}, alert: DiffAlert.glow);
      final remember = word(2, 152, 0);
      final ink = t.widget<InkText>(remember);
      expect(ink.text, isNot(contains('ٓ')));
      expect(ink.style.color, MushafColors.ink);
      expect(ink.parts?.every((p) => p.$2 == null) ?? true, isTrue);
      expect(
        find.ancestor(
          of: remember,
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_Alerting',
          ),
        ),
        findsNothing,
      );

      await page(t, id, number: 32, selected: {id});
      expect(t.widget<InkText>(word(2, 206, 1)).text, isNot(contains('اشمام')));
      expect(find.textContaining('اظهار اللام الأولى'), findsNothing);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Ruways has plain tasheel, not circled ya, at haulai in', (
    t,
  ) async {
    await page(t, 'ruways', number: 6, selected: {'ruways'});
    final v = variants
        .at(['ruways'], 2, 31, 12)
        .singleWhere((v) => v.rule == 'tasheel_pair');
    expect(v.hamzaReplacement, isNull);
    final m = t.widget<HamzaReplacementMark>(mark(word(2, 31, 12)));
    expect(m.letter, isEmpty);
    expect(m.originalHamza, startsWith('إ'));
    final notes = find.byWidgetPredicate(
      (w) => w is HamzaReplacementMark && w.letter == 'ي',
    );
    expect(notes, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'inni alam is no ya idafa difference against Hafs, but is against Warsh',
    (t) async {
      Finder note() => find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith(
              'usul-reference:ياءات الإضافة:2:30:23:',
            ),
      );
      for (final id in [null, 'ruways', 'rawh', 'shubah', 'hisham', 'warsh']) {
        await page(
          t,
          id,
          number: quran.ayah(2, 30).page,
          selected: {'ruways', 'rawh'},
        );
        final reference = readingText(variants, id, quran.ayah(2, 30), 23, 24);
        expect(lettersOf(reference).last.contains('َ'), id == 'warsh');
        expect(note(), id == 'warsh' ? findsOneWidget : findsNothing);
        if (id != 'warsh') {
          expect(
            t.widget<InkText>(word(2, 30, 23)).style.color,
            MushafColors.ink,
          );
        }
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('excluded Yaqub mim words have neither colour nor glow', (
    t,
  ) async {
    Finder alerts(Finder target) => find.ancestor(
      of: target,
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Alerting',
      ),
    );
    for (final id in [null, 'ruways', 'rawh']) {
      await page(t, id, selected: {'ruways', 'rawh'}, alert: DiffAlert.glow);
      await t.pump(const Duration(milliseconds: 200));
      for (final target in [word(2, 10, 3), word(2, 12, 2), word(2, 13, 14)]) {
        final ink = t.widget<InkText>(target);
        expect(ink.style.color, MushafColors.ink, reason: '$id ${ink.text}');
        expect(
          ink.parts?.every((p) => p.$2 == null || p.$2 == MushafColors.ink) ??
              true,
          isTrue,
          reason: '$id ${ink.text}',
        );
        expect(alerts(target), findsNothing);
      }
      if (id != 'rawh') {
        // Ruways's genuine ishmam must retain its own indication.
        expect(alerts(word(2, 11, 1)), findsOneWidget);
      }
      await page(
        t,
        id,
        number: 25,
        selected: {'ruways', 'rawh'},
        alert: DiffAlert.glow,
      );
      // Read alike by both: with Hafs not selected, nothing differs to tell.
      expect(alerts(word(2, 167, 13)), findsNothing);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('a riwaya shown alone: its text, its usul below, nothing '
      'coloured, glowing or in the hamesh', (t) async {
    for (final (id, number) in [('warsh', 2), ('warsh', 3), ('bazzi', 3)]) {
      await page(t, id, number: number, selected: {id}, alert: DiffAlert.glow);
      await t.pump(const Duration(milliseconds: 200));
      for (final e in find.byType(InkText).evaluate()) {
        final ink = e.widget as InkText;
        expect(ink.style.color, MushafColors.ink, reason: '$id ${ink.text}');
        expect(
          ink.parts?.every((p) => p.$2 == null || p.$2 == MushafColors.ink) ??
              true,
          isTrue,
          reason: '$id ${ink.text}',
        );
      }
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Alerting'),
        findsNothing,
        reason: id,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('margin-reference:'),
        ),
        findsNothing,
        reason: id,
      );
      expect(find.byKey(const ValueKey('usul-notes')), findsOneWidget);
    }
  });

  testWidgets('a usul all the selected read alike is neither coloured nor '
      'glowing, whichever of them the mushaf shows', (t) async {
    Finder alerts(Finder target) => find.ancestor(
      of: target,
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Alerting',
      ),
    );
    const silah = {'qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz'};
    for (final id in [null, 'bazzi', 'qalun']) {
      await page(t, id, selected: silah, alert: DiffAlert.glow);
      await t.pump(const Duration(milliseconds: 200));
      // قُلُوبِهِمُۥ: the mim silah of them all.
      final ink = t.widget<InkText>(word(2, 7, 3));
      expect(ink.style.color, MushafColors.ink, reason: '$id');
      expect(
        ink.parts?.every((p) => p.$2 == null || p.$2 == MushafColors.ink) ??
            true,
        isTrue,
        reason: '$id',
      );
      expect(alerts(word(2, 7, 3)), findsNothing, reason: '$id');
      // ءَأَنذَرۡتَهُمۡ: Qalun's idkhal, not Ibn Kathir's, still told.
      expect(alerts(word(2, 6, 5)), findsOneWidget, reason: '$id');
    }
  });

  testWidgets(
    'hasrati long madd belongs to Ruways and its ha stays in margin',
    (t) async {
      for (final id in [null, 'ruways', 'rawh']) {
        await page(t, id, number: 464, selected: {'ruways', 'rawh'}, qcf: true);
        final ink = t.widget<InkText>(word(39, 56, 3));
        expect(ink.text.endsWith('ىٰٓ'), id == 'ruways');
        expect(ink.text, isNot(endsWith('هۡ')));
        final example = find.byKey(
          const ValueKey('usul-reference:هاء السكت:39:56:3:ruways'),
        );
        expect(example, findsOneWidget);
        expect(
          t
              .widget<QuranWordText>(
                find.descendant(
                  of: example,
                  matching: find.byType(QuranWordText),
                ),
              )
              .text,
          'يَٰحَسۡرَتَآهۡ',
        );
        expect(find.textContaining('المد المشبع ست حركات'), findsWidgets);
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('Ruways bi-zanin keeps the dad with a small za over it', (
    t,
  ) async {
    await page(t, 'ruways', number: 586, selected: {'ruways'});
    final word = find.byKey(const ValueKey('word:81:24:4'));
    expect(t.widget<InkText>(word).text, contains('ض'));
    final mark = t.widget<LetterAboveMark>(
      find.ancestor(of: word, matching: find.byType(LetterAboveMark)),
    );
    expect(mark.letter, 'ظ');
    expect(mark.text[mark.offset], 'ض');
    expect(t.takeException(), isNull);
  });

  testWidgets('bal before Yaqub adraka takes its sukun, not Hafs kasra', (
    t,
  ) async {
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, number: 383, selected: {id});
      expect(t.widget<InkText>(word(27, 66, 0)).text, 'بَلۡ');
      expect(t.widget<InkText>(word(27, 66, 1)).text, 'أَدۡرَكَ');
    }
    await page(t, null, number: 383, selected: {'ruways'});
    expect(t.widget<InkText>(word(27, 66, 0)).text, 'بَلِ');
    expect(t.takeException(), isNull);
  });

  testWidgets('Yaqub lahab keeps the rasm with a circled ya on its hamza', (
    t,
  ) async {
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, number: 306, selected: {id});
      final m = t.widget<HamzaReplacementMark>(
        find.ancestor(
          of: word(19, 19, 5),
          matching: find.byType(HamzaReplacementMark),
        ),
      );
      expect(m.letter, 'ي');
      expect(m.originalHamza, startsWith('أ'));
      expect(m.offset, 'لِ'.length);
      expect(t.takeException(), isNull);
    }
  });

  test('ha of tanbih and ya of nida lose their joined separated madd', () {
    expect(withoutJoinedSeparatedMaddSign('هَٰٓؤُلَآءِ'), 'هَٰؤُلَآءِ');
    expect(withoutJoinedSeparatedMaddSign('يَٰٓأَيُّهَا'), 'يَٰأَيُّهَا');
    expect(withoutJoinedSeparatedMaddSign('يَٰٓـَٔادَمُ'), 'يَٰـَٔادَمُ');
    expect(
      withoutJoinedSeparatedMaddSign('ٱلۡمَلَٰٓئِكَةِ'),
      'ٱلۡمَلَٰٓئِكَةِ',
    );
  });

  test('shortening removes only the separated madd at the word end', () {
    expect(withoutSeparatedMaddSign('بِمَآ'), 'بِمَا');
    expect(withoutSeparatedMaddSign('جَآءُوٓاْ'), 'جَآءُواْ');
    expect(withoutSeparatedMaddSign('ٱلسَّمَآءِ'), 'ٱلسَّمَآءِ');
    expect(withoutSeparatedMaddSign('بِمَا'), 'بِمَا');
  });

  testWidgets(
    'Yaqub hides separated madd notes and shortens only its main text',
    (t) async {
      for (final id in [null, 'ruways', 'rawh']) {
        await page(t, id, number: 2, selected: {'ruways', 'rawh'});
        final separated = t.widget<InkText>(word(2, 4, 2)).text;
        expect(separated.contains('ٓ'), id == null, reason: '$id بما');
        expect(
          t.widget<InkText>(word(2, 5, 0)).text,
          contains('ٓ'),
          reason: '$id connected madd',
        );
        for (final target in [word(2, 4, 2), word(2, 5, 0)]) {
          final ink = t.widget<InkText>(target);
          expect(ink.style.color, MushafColors.ink);
          expect(ink.parts, isNull);
        }
        expect(find.byKey(const ValueKey('yaqub-madd-note')), findsNothing);
        expect(
          find.text('يعقوب: المد المتصل بالتوسط، والمد المنفصل بالقصر'),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                RegExp(r'^usul-reference:المد (المنفصل|المتصل):')
                    .hasMatch((w.key as ValueKey<String>).value),
          ),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('repeated Yaqub ishmam words have one margin example', (t) async {
    await page(t, 'ruways', selected: {'ruways', 'rawh'});
    final examples = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith(
            'usul-reference:الإشمام (إشمام حركة بحركة):',
          ),
    );
    // قيل at 2:11 and 2:13 has the same narrator and performance.
    expect(examples, findsOneWidget);
    expect(word(2, 11, 1), findsOneWidget);
    expect(word(2, 13, 1), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Yaqub mim examples require the requested change in ha', (
    t,
  ) async {
    Finder mimNotes() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith(
            'usul-reference:ميم الجمع:',
          ),
    );
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, selected: {id});
      // Hum al-muflihun/al-mufsidun agree with Hafs and have no example.
      expect(mimNotes(), findsNothing);
      await page(t, id, number: 22, selected: {id});
      // A changed mim following a broken ha is included in the margin.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'usul-reference:ميم الجمع:2:142:7:',
              ),
        ),
        findsOneWidget,
      );
      expect(t.widget<InkText>(word(2, 142, 7)).text, contains('هِمِ'));
      await page(t, id, number: 25, selected: {id});
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'usul-reference:ميم الجمع:2:167:13:',
              ),
        ),
        findsOneWidget,
      );
      expect(t.widget<InkText>(word(2, 167, 13)).text, contains('هُمُ'));
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Yaqub removes separated madd on dagger alif in printed mode', (
    t,
  ) async {
    for (final id in ['ruways', 'rawh']) {
      await page(t, id, qcf: true, selected: {id});
      // وعلىٰٓ أبصارهم: the dagger alif must survive; only madd is removed.
      final text = t.widget<InkText>(word(2, 7, 6)).text;
      expect(text, contains('ىٰ'));
      expect(text, isNot(contains('ٓ')));
      expect(t.widget<InkText>(word(2, 6, 3)).text, contains('ٓ'));
      expect(t.takeException(), isNull);
    }
  });
  testWidgets(
    'Ruways main tasheel is marked; Hafs and Rawh retain their hamzas',
    (t) async {
      for (final id in [null, 'ruways', 'rawh']) {
        await page(t, id);
        final target = word(2, 6, 5);
        expect(target, findsOneWidget);
        final footer = find.byKey(
          const ValueKey(
            'usul-reference:الهمزتان من كلمة (المفتوحتان):2:6:5:ruways',
          ),
        );
        expect(footer, findsOneWidget);
        final marginMark = t.widget<HamzaReplacementMark>(
          find.descendant(
            of: footer,
            matching: find.byType(HamzaReplacementMark),
          ),
        );
        expect(marginMark.letter, isEmpty);
        expect(marginMark.originalHamza, startsWith('أ'));
        if (id == 'ruways') {
          final m = t.widget<HamzaReplacementMark>(mark(target));
          expect(m.letter, isEmpty);
          expect(m.offset, greaterThan(0));
          final ink = t.widget<InkText>(target);
          expect(ink.parts!.map((p) => p.$1).join(), isNot(contains('أَ')));
        } else {
          expect(mark(target), findsNothing);
          expect(t.widget<InkText>(target).text, contains('أَ'));
        }
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Ruways ibdal circle uses original hamza seat without changing Hafs',
    (t) async {
      final v = variants
          .at(['ruways'], 2, 13, 12)
          .singleWhere((v) => v.rule == 'ibdal_waw');
      expect(v.word, 12);
      for (final id in [null, 'ruways', 'rawh']) {
        await page(t, id);
        final target = word(2, 13, 12);
        expect(target, findsOneWidget);
        if (id == 'ruways') {
          final m = t.widget<HamzaReplacementMark>(mark(target));
          expect(m.letter, 'و');
          expect(m.originalHamza, startsWith('أ'));
          expect(m.text, startsWith('أ'));
        } else {
          expect(mark(target), findsNothing);
          expect(t.widget<InkText>(target).text, startsWith('أ'));
        }
        expect(t.takeException(), isNull);
      }
    },
  );
}
