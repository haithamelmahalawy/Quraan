import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/hamza_replacement_mark.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';
import 'package:qiraat_mushaf/ui/reading_colors.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import '../tool/build_warsh_usul.dart';
import '../tool/build_usul.dart' as usul_builder;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran, shamarly;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;

  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    shamarly = await QuranRepository.load(null, MushafEdition.shamarly);
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh', 'qunbul', 'susi']);
    mutashabihat = await MutashabihatRepository.load();
  });

  Variant rule(int s, int a, int w, String id) =>
      variants.at(['warsh'], s, a, w).singleWhere((v) => v.rule == id);

  test('falan on page 29 has naql as well as badal', () {
    expect(quran.pageOf(2, 187), 29);
    final naql = rule(2, 187, 23, 'naql');
    expect(naql.description, contains('نقل حركة الهمزة إلى اللام'));
    expect(naql.text, 'فَالَٰنَ');
    expect(naql.isUsul, isTrue);
    expect(rule(2, 187, 23, 'badal').isBadal, isTrue);
    expect(variants.at(['warsh'], 2, 187, 23).every((v) => v.isUsul), isTrue);
  });

  test('extra ya is an independent usul with wasl and waqf faces', () {
    for (final w in [8, 10]) {
      final readings = variants.at(['warsh'], 2, 186, w).toList();
      final ya = readings.singleWhere((v) => v.rule == 'ya_zaida');
      expect(ya.isUsul, isTrue);
      expect(ya.description, 'بإثبات الياء الزائدة وصلاً وحذفها وقفًا');
      expect(readings.any((v) => v.description.contains('هاء')), isFalse);
      expect(readings.any((v) => v.inHamesh), isFalse);
    }
  });

  test('shared nun idgham is not a Warsh difference alongside ibdal', () {
    for (var p = 1; p <= 604; p++) {
      for (final a in quran.page(p)) {
        for (var w = 1; w < a.words.length; w++) {
          for (final v in variants.at(['warsh'], a.surah, a.number, w)) {
            if (v.rule == 'ibdal_single' &&
                RegExp(r'ن[ْۡ]?[ۖ-ۭ]*$').hasMatch(a.words[w - 1]) &&
                RegExp(r'^[يرملون][َُِ]*ّ').hasMatch(v.text)) {
              expect(
                v.description,
                isNot(contains('الإدغام')),
                reason: '${a.surah}:${a.number}:$w',
              );
            }
          }
        }
      }
    }
    expect(rule(2, 75, 2, 'ibdal_single').description, 'بإبدال الهمزة واوًا');
    expect(variants.sourceTextAt('warsh', 2, 75, 1), 'أَن');
  });

  test('badal follows lexical additions and deletions throughout Warsh', () {
    for (final (s, a, w) in [(2, 81, 6), (37, 130, 2), (43, 38, 2)]) {
      expect(
        variants.at(['warsh'], s, a, w).any((v) => v.isBadal),
        isTrue,
        reason: '$s:$a:$w',
      );
      expect(variants.at(['warsh'], s, a, w).any((v) => v.inHamesh), isTrue);
    }
    expect(variants.at(['warsh'], 41, 51, 5).any((v) => v.isBadal), isTrue);
    for (final (s, a, w) in [
      (2, 62, 6),
      (5, 69, 5),
      (22, 17, 5),
      (30, 50, 2),
      (33, 14, 8),
    ]) {
      expect(
        variants.at(['warsh'], s, a, w).any((v) => v.isBadal),
        isFalse,
        reason: '$s:$a:$w',
      );
    }
  });

  test('Warsh Sabiin and Sabiun are farsh without madd al-badal', () {
    for (final (s, a, w) in [(2, 62, 6), (5, 69, 5), (22, 17, 5)]) {
      final word = quran.ayah(s, a).words[w];
      expect(usul_builder.hasBadal(word, '$s:$a'), isFalse);
      final readings = variants.at(['warsh'], s, a, w).toList();
      expect(readings, hasLength(1));
      expect(readings.single.kind, VariantKind.farsh);
      expect(readings.single.inHamesh, isTrue);
      expect(readings.single.isUsul, isFalse);
      expect(readings.single.description, 'بلا همز');
    }
    expect(usul_builder.hasBadal(quran.ayah(2, 62).words[2], '2:62'), isTrue);
  });

  test(
    'faddaratum agrees with Hafs in Warsh while Susi retains its reading',
    () {
      expect(variants.at(['warsh'], 2, 72, 3), isEmpty);
      final susi = variants.at(['susi'], 2, 72, 3).single;
      expect(susi.text, 'فَاَدَّٰرَٰتُمۡ');
      expect(susi.description, 'بحذف الهمزة');
    },
  );

  test('both huda words on page 2 have stopping taqlil in usul', () {
    for (final (a, w) in [(2, 5), (5, 2)]) {
      final v = rule(2, a, w, 'taqlil_stop');
      expect(v.stopOnly, isTrue);
      expect(v.isImala, isTrue);
      expect(v.isUsul, isTrue);
      expect(v.inHamesh, isFalse);
    }
  });

  test('naql includes both words and removes the false farsh on khalaw', () {
    final alim = rule(2, 10, 8, 'naql');
    expect(alim.usulText, 'عَذَابٌ أَلِيمُۢ');
    final ila = rule(2, 14, 8, 'naql');
    expect(ila.usulText, 'خَلَوۡاْ إِلَىٰ');
    for (final v in [alim, ila, rule(2, 14, 7, 'naql_source')]) {
      expect(v.isUsul, isTrue);
      expect(v.inHamesh, isFalse);
      expect(v.shownDescription, contains('نقل'));
      expect(v.shownDescription, isNot(contains('تخفيف')));
    }
    expect(rule(2, 107, 0, 'naql').usulText, 'قَدِيرٌ أَلَمۡ');
    expect(rule(3, 28, 16, 'naql').usulText, 'شَيۡءٍ إِلَّآ');
  });

  test('two-word hamza rules distinguish both vowels and keep other ways', () {
    final waw = rule(2, 13, 12, 'ibdal_waw');
    expect(waw.hamzaReplacement, 'و');
    expect(waw.usulText, 'ٱلسُّفَهَآءُۗ أَلَآ');
    final ya = rule(2, 235, 9, 'ibdal_ya');
    expect(ya.hamzaReplacement, 'ي');
    expect(ya.usulText, 'ٱلنِّسَآءِ أَوۡ');
    expect(rule(4, 43, 27, 'tasheel_pair').hamzaReplacement, isNull);
    expect(rule(4, 43, 27, 'tasheel_pair').description, contains('تسهيل'));
    expect(
      rule(2, 142, 18, 'ibdal_waw').description,
      contains('تسهيل الهمزة الثانية'),
    );
    for (final v in [waw, ya]) {
      expect(v.inHamesh, isFalse);
    }
  });

  test('data generation is repeatable and preserves independent farsh', () {
    final q =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final b =
        jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
    final rows =
        (jsonDecode(File('assets/data/qiraat/warsh.json').readAsStringSync())
                as Map)['variants']
            as List;
    final before = jsonEncode(rows);
    // Regenerating the generic comparisons must not restore this false
    // Warsh difference.
    rows.add([2, 72, 3, 1, 'فَادَّٰرَٰٔتُمْ', 'h', 'بالهمز وحذف الهمزة']);
    correctWarshUsul(
      q,
      b,
      rows,
      sourceText: jsonDecode(
        File('assets/data/reading_texts/warsh.json').readAsStringSync(),
      ) as Map,
    );
    final beforeRows = jsonDecode(before) as List;
    final differences = [
      for (var i = 0; i < rows.length && i < beforeRows.length; i++)
        if (jsonEncode(rows[i]) != jsonEncode(beforeRows[i]))
          [beforeRows[i], rows[i]],
    ];
    expect(
      jsonEncode(rows) == before,
      isTrue,
      reason:
          'A second generation must preserve the existing rows exactly. '
          '${differences.take(3).toList()}',
    );
    expect(variants.at(['warsh'], 6, 63, 11).any((v) => v.inHamesh), isTrue);
    expect(
      variants
          .at(['warsh'], 4, 152, 11)
          .any((v) => v.inHamesh && v.description.contains('النون')),
      isTrue,
    );
    expect(variants.at(['warsh'], 2, 10, 11).single.kind, VariantKind.farsh);
  });

  Future<void> page(
    WidgetTester t,
    int number, {
    ReaderSettings? settings,
    VariantRepository? repository,
    QuranRepository? mushaf,
    Size? viewport,
  }) async {
    t.view.physicalSize = viewport ?? const Size(1080, 2000);
    t.view.devicePixelRatio = viewport == null ? 2.5 : 1;
    addTearDown(t.view.reset);
    final theme = buildTheme(MushafPalette.light);
    await t.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: number,
              quran: mushaf ?? quran,
              variants: repository ?? variants,
              mutashabihat: mutashabihat,
              settings: settings ?? ReaderSettings.memory(selected: {'warsh'}),
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('page 2 footer explicitly labels stopping taqlil', (t) async {
    await page(t, 2);
    expect(find.text('التقليل:'), findsOneWidget);
    expect(find.text(' (وقفًا)'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'page 29 lists falan under naql and badal and extra ya separately',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          29,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..displayed = displayed,
        );
        for (final label in ['النقل', 'مد البدل']) {
          expect(
            find.byKey(ValueKey('usul-reference:$label:2:187:23:warsh')),
            findsOneWidget,
          );
        }
        final ink = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:187:23')),
        );
        final parts = ink.parts!;
        expect(
          parts.map((p) => p.$1).join().replaceAll(tatweel, ''),
          ink.text.replaceAll(tatweel, ''),
        );
        expect(
          parts.where((p) => p.$1.contains('ٰ')).single.$2,
          MushafColors.green,
        );
        expect(
          parts.where((p) => p.$1.startsWith('ل')).single.$2,
          displayed == 'warsh' ? MushafColors.green : ReadingColors.naql,
        );
        await page(
          t,
          quran.pageOf(2, 186),
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..displayed = displayed,
        );
        for (final w in [8, 10]) {
          expect(
            find.byKey(ValueKey('usul-reference:ياءات الزوائد:2:186:$w:warsh')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              ValueKey('usul-reference:صلة هاء الضمير:2:186:$w:warsh'),
            ),
            findsNothing,
          );
        }
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('badal green takes priority over naql on ataynahum and aya', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        quran.pageOf(2, 211),
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..displayed = displayed,
      );
      for (final w in [4, 6]) {
        final ink = t.widget<InkText>(find.byKey(ValueKey('word:2:211:$w')));
        final parts = ink.parts!;
        final target = badalLetter(lettersOf(ink.text))!;
        expect(
          parts[target].$2,
          MushafColors.green,
          reason: '$displayed: ${ink.text}',
        );
        expect(
          parts.map((p) => p.$1).join().replaceAll(tatweel, ''),
          ink.text.replaceAll(tatweel, ''),
        );
      }
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'page 11 lists yuminun only under ibdal and leaves the preceding nun bare',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          11,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..displayed = displayed,
        );
        expect(
          t.widget<InkText>(find.byKey(const ValueKey('word:2:75:1'))).text,
          'أَن',
        );
        expect(
          find.byKey(const ValueKey('usul-reference:إبدال الهمز:2:75:2:warsh')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('usul-reference:الإدغام:2:75:2:warsh')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('page 11 has no Warsh colour, animation or usul for faddaratum', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..displayed = displayed
        ..mode = DisplayMode.highlight
        ..diffAlert = DiffAlert.glow
        ..showMutashabihat = false;
      await page(t, 11, settings: settings);
      final main = find.byKey(const ValueKey('word:2:72:3'));
      final word = t.widget<InkText>(main);
      expect(word.style.color, MushafColors.ink);
      expect(word.parts, isNull);
      expect(
        find.ancestor(
          of: main,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_Alerting',
          ),
        ),
        findsNothing,
      );
      final notes = find.byKey(const ValueKey('usul-notes'));
      expect(
        find.descendant(
          of: notes,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                skeleton(widget.data ?? widget.textSpan?.toPlainText() ?? '')
                    .contains('فدرتم'),
          ),
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('page 10 keeps Sabiin in farsh and out of the badal footer', (
    t,
  ) async {
    for (final displayed in [null, 'warsh']) {
      await page(
        t,
        10,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..displayed = displayed,
      );
      final notes = find.byKey(const ValueKey('usul-notes'));
      expect(
        find.descendant(
          of: notes,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                skeleton(widget.data ?? widget.textSpan?.toPlainText() ?? '')
                    .contains('لصبين'),
          ),
        ),
        findsNothing,
      );
      if (displayed == null) {
        expect(
          find.byKey(const ValueKey('margin-reference:2:62:6')),
          findsOneWidget,
        );
      }
      expect(find.text('مد البدل:'), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'naql before badal includes both words without a vague hamza group',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await page(
          t,
          8,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..displayed = displayed,
        );
        final notes = find.byKey(const ValueKey('usul-notes'));
        Finder example(String value) =>
            find.descendant(of: notes, matching: find.text(value));
        expect(example('مِّنَ اٰلِ'), findsOneWidget);
        expect(example('وَإِذَ اٰتَيْنَا'), findsOneWidget);
        expect(
          example('اٰلِ'),
          findsOneWidget,
        ); // The independent badal example.
        expect(example('اٰتَيْنَا'), findsOneWidget);
        expect(example('مِّنَ'), findsNothing);
        expect(example('وَإِذَ'), findsNothing);
        expect(example('تخفيف الهمز:'), findsNothing);
        expect(example('الهمزات:'), findsNothing);
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Israel notes stay in the margin without colouring a difference',
    (t) async {
      final places = <(Ayah, int)>[
        for (var p = 1; p <= 604; p++)
          for (final a in quran.page(p))
            for (final (w, text) in a.words.indexed)
              if (skeleton(text) == 'سريل') (a, w),
      ];
      expect(places, hasLength(42));
      for (final (a, w) in places) {
        final readings = variants.at(['warsh'], a.surah, a.number, w).toList();
        expect(readings.every((v) => v.isMarginNote), isTrue);
        expect(ReadingColors.ofReadings(readings), isNull);
      }
      for (final displayed in [null, 'warsh']) {
        final settings = ReaderSettings.memory(selected: {'warsh'})
          ..displayed = displayed
          ..mode = DisplayMode.hamesh
          ..compareHafs = true
          ..showMutashabihat = false;
        await page(t, 7, settings: settings);
        final word = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:40:1')),
        );
        expect(word.style.color, MushafColors.ink);
        expect(word.parts, isNull);
        final note = find.byKey(const ValueKey('margin-reference:2:40:1'));
        expect(note, findsOneWidget);
        expect(
          find.textContaining('ولا ترقق راؤه لأنه اسم أعجمي'),
          findsOneWidget,
        );
        settings.mode = DisplayMode.highlight;
        settings.diffAlert = DiffAlert.glow;
        await page(t, 7, settings: settings);
        final main = find.byKey(const ValueKey('word:2:40:1'));
        expect(t.widget<InkText>(main).style.color, MushafColors.ink);
        expect(
          find.ancestor(
            of: main,
            matching: find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_Alerting',
            ),
          ),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('replacement circles belong only to a Warsh base or its margin', (
    t,
  ) async {
    for (final displayed in [null, 'warsh', 'qunbul']) {
      final settings = ReaderSettings.memory(selected: {'warsh', 'qunbul'})
        ..displayed = displayed;
      for (final (number, a, w, letter) in [
        (3, 13, 12, 'و'),
        (6, 31, 12, 'ي'),
        (38, 235, 9, 'ي'),
      ]) {
        await page(t, number, settings: settings);
        final word = find.byKey(ValueKey('word:2:$a:$w'));
        expect(word, findsOneWidget);
        final main = find.ancestor(
          of: word,
          matching: find.byType(HamzaReplacementMark),
        );
        expect(main, displayed == 'warsh' ? findsOneWidget : findsNothing);
        if (displayed == 'warsh') {
          expect(t.widget<HamzaReplacementMark>(main).letter, letter);
        }
        final notes = find.byKey(const ValueKey('usul-notes'));
        expect(
          t
              .widgetList<HamzaReplacementMark>(
                find.descendant(
                  of: notes,
                  matching: find.byType(HamzaReplacementMark),
                ),
              )
              .any((m) => m.letter == letter),
          isTrue,
        );
        expect(t.takeException(), isNull);
      }
    }
  });

  test(
    'two broken hamzas show the ya replacement as well as their other ways',
    () {
      final v = rule(2, 31, 12, 'tasheel_pair');
      expect(v.hamzaReplacement, 'ي');
      expect(v.usulWays.any((w) => w.contains('تسهيل')), isTrue);
      expect(v.usulWays.any((w) => w.contains('ياءً')), isTrue);
      const text = 'هَٰٓؤُلَآءِ إِن';
      expect(
        HamzaReplacementMark.seatText(text, text.lastIndexOf(' ') + 1),
        'هَٰٓؤُلَآءِ ان',
      );
    },
  );

  test('the two ways of open hamzas belong to usul without insertion', () {
    for (final (s, a, w) in [(2, 6, 5), (3, 20, 13), (36, 10, 2)]) {
      final v = rule(s, a, w, 'tasheel_word');
      expect(v.inHamesh, isFalse);
      expect(v.isImala, isFalse);
      expect(v.usulWays, [
        'تسهيل الهمزة الثانية بلا إدخال',
        'إبدال الهمزة الثانية ألفًا مع المد المشبع (٦ حركات)',
      ]);
      expect(ReadingColors.of(v), ReadingColors.hamza);
    }
    expect(rule(43, 58, 1, 'tasheel_word').usulWays, hasLength(1));
    expect(rule(2, 31, 12, 'tasheel_pair').isImala, isFalse);
  });

  testWidgets('hamza ways are explicit in the compact usul margin', (t) async {
    await page(t, 3);
    final explanation = t.widget<Text>(
      find.byKey(const ValueKey('hamza-word-ways')),
    );
    expect(explanation.data, contains('تسهيل الهمزة الثانية بلا إدخال'));
    expect(explanation.data, contains('مع المد المشبع (٦ حركات)'));
    expect(find.text('الهمزتان المفتوحتان في كلمة:'), findsOneWidget);
    expect(
      t.widget<Text>(find.text('الأصول')).style?.fontSize,
      lessThanOrEqualTo(8),
    );
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(800 - print.height, greaterThan(0));
    expect(800 - print.height, lessThan(2 * print.height / 15));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'portrait uses one outer margin and a wider print on either page',
    (t) async {
      for (final width in [432.0, 360.0]) {
        for (final number in [3, 4]) {
          await page(
            t,
            number,
            repository: _DenseVariants(),
            viewport: Size(width, 800),
          );
          await t.pumpAndSettle();
          final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
          final right = quran.isRightPage(number);
          expect(print.width, greaterThanOrEqualTo(width * .83));
          expect(right ? print.left : print.right, right ? 0 : width);
          final notes = <Rect>[];
          for (
            var i = 0;
            find.byKey(ValueKey('side-note-$i')).evaluate().isNotEmpty;
            i++
          ) {
            final rect = t.getRect(find.byKey(ValueKey('side-note-$i')));
            expect(rect.top, greaterThanOrEqualTo(-0.1));
            expect(rect.bottom, lessThanOrEqualTo(print.bottom + 0.1));
            if (right) {
              expect(rect.left, greaterThanOrEqualTo(print.right));
            } else {
              expect(rect.right, lessThanOrEqualTo(print.left));
            }
            notes.add(rect);
          }
          expect(notes, isNotEmpty);
          notes.sort((a, b) => a.top.compareTo(b.top));
          for (var i = 1; i < notes.length; i++) {
            expect(notes[i].top, greaterThanOrEqualTo(notes[i - 1].bottom));
          }
          expect(find.byKey(const ValueKey('bottom-notes')), findsOneWidget);
          expect(
            t.getTopLeft(find.byKey(const ValueKey('bottom-notes'))).dy,
            lessThan(800),
          );
          expect(t.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'extra portrait width enlarges letters without changing printed lines',
    (t) async {
      await page(t, 3, repository: _DenseVariants());
      await t.pumpAndSettle();
      final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
      final lines = t.widget<MushafLines>(find.byType(MushafLines));
      expect(lines.lines, quran.lines(3));
      // Previously the two margins left 74% of the viewport to the print.
      final oldSize = lines.metrics(432 * .74 - 48).fontSize;
      expect(
        lines.metrics(print.width - 48).fontSize,
        greaterThan(oldSize * 1.1),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('portrait margin follows the Shamarly page side too', (t) async {
    for (final number in [3, 4]) {
      await page(t, number, repository: _DenseVariants(), mushaf: shamarly);
      await t.pumpAndSettle();
      final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
      final note = t.getRect(find.byKey(const ValueKey('side-note-0')));
      if (shamarly.isRightPage(number)) {
        expect(note.left, greaterThanOrEqualTo(print.right));
      } else {
        expect(note.right, lessThanOrEqualTo(print.left));
      }
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('two-word faces stay with their own contexts in the footer', (
    t,
  ) async {
    await page(t, 424);
    final details = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '');
    final arid = details.where((s) => s.contains('الحركة العارضة')).toList();
    expect(arid, hasLength(1));
    expect(arid.single, contains('السكون الأصلي'));
    expect(arid.single, contains('القصر (حركتان)'));
    expect(arid.single, contains('٦ حركات'));
    // A separate group on the same page permits a moving waw or tasheel;
    // it must not acquire the ya-madd faces of للنبيء إن أراد.
    final waw = details.where((s) => s.contains('واوًا مكسورة خالصة')).toList();
    expect(waw, hasLength(1));
    expect(waw.single, isNot(contains('الحركة العارضة')));
    expect(waw.single, isNot(contains('حركات')));
    expect(t.takeException(), isNull);
  });

  testWidgets('a narrow phone keeps the right margin and uses the bottom', (
    t,
  ) async {
    await page(
      t,
      3,
      repository: _DenseVariants(),
      viewport: const Size(360, 740),
    );
    await t.pumpAndSettle();
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(print.left, 0);
    expect(
      t.getRect(find.byKey(const ValueKey('side-note-0'))).left,
      greaterThanOrEqualTo(print.right),
    );
    expect(find.byKey(const ValueKey('bottom-notes')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('compound hamza, silah and madd descriptions remain usul', () {
    final v = variants.at(['warsh'], 2, 6, 5).single;
    expect(v.isUsul, isTrue);
    expect(v.inHamesh, isFalse);
    expect(ReadingColors.of(v), ReadingColors.hamza);
    expect(variants.at(['warsh'], 2, 10, 11).single.isUsul, isFalse);
    expect(ReadingColors.of(rule(2, 10, 8, 'naql')), ReadingColors.naql);
    expect(ReadingColors.forLabel('النقل'), ReadingColors.naql);
    expect(ReadingColors.forLabel('تسهيل الهمز'), ReadingColors.hamza);
    expect(ReadingColors.forLabel('صلة ميم الجمع'), ReadingColors.silah);
    expect(
      variants.at(['warsh'], 2, 13, 11),
      isEmpty,
      reason: 'The paired hamza rule belongs to the second word.',
    );
    expect(
      variants.at(['warsh'], 2, 14, 15).every((v) => v.isUsul),
      isTrue,
      reason: 'The book must not duplicate madd al-badal as farsh.',
    );
  });

  testWidgets(
    'rule colours survive switching the displayed riwaya and Hafs comparison',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        final settings = ReaderSettings.memory(selected: {'warsh'})
          ..displayed = displayed
          ..compareHafs = true;
        await page(t, 3, settings: settings);
        InkText word(int a, int w) =>
            t.widget<InkText>(find.byKey(ValueKey('word:2:$a:$w')));
        List<Color> colours(int a, int w) => [
          for (final p in word(a, w).parts ?? <(String, Color?)>[])
            if (p.$2 != null) p.$2!,
        ];
        expect(
          colours(6, 5),
          containsAll([ReadingColors.hamza, ReadingColors.silah]),
        );
        expect(colours(6, 10), contains(ReadingColors.hamza));
        expect(colours(10, 8), contains(ReadingColors.naql));
        expect(colours(14, 7), contains(ReadingColors.naql));
        expect(colours(14, 8), contains(ReadingColors.naql));
        expect(
          word(10, 11).style.color,
          qiraaOf(displayed == null ? 'warsh' : hafsId).color,
        );
        expect(
          t
              .widget<HamzaReplacementMark>(
                find.byType(HamzaReplacementMark).first,
              )
              .color,
          ReadingColors.hamza,
        );
        expect(
          t.widget<Text>(find.text('النقل:')).style?.color,
          ReadingColors.naql,
        );
        expect(
          t.widget<Text>(find.text('إبدال الهمز:')).style?.color,
          ReadingColors.hamza,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('page 3 groups the two-word rules and paints the circled waw', (
    t,
  ) async {
    await page(t, 3);
    expect(find.text('النقل:'), findsOneWidget);
    expect(find.text('عَذَابٌ اَلِيمُۢ'), findsOneWidget);
    expect(find.text('خَلَوِاْ اِلَىٰ'), findsOneWidget);
    final marks = t.widgetList<HamzaReplacementMark>(
      find.byType(HamzaReplacementMark),
    );
    expect(
      marks.where((m) => m.letter == 'و'),
      hasLength(1),
    ); // Warsh's footer example; the Hafs page keeps its original hamza.
    expect(t.takeException(), isNull);
  });

  testWidgets('usul examples use their own riwaya when the main text changes', (
    t,
  ) async {
    for (final displayed in [null, 'warsh', 'qunbul']) {
      final settings = ReaderSettings.memory(selected: {'warsh', 'qunbul'})
        ..displayed = displayed;
      await page(t, 3, settings: settings);
      final notes = find.byKey(const ValueKey('usul-notes'));
      Finder example(String text) =>
          find.descendant(of: notes, matching: find.text(text));
      expect(example('عَلَيْهِمُۥٓ'), findsOneWidget);
      expect(example('عَلَيۡهِمُۥ'), findsOneWidget);
      expect(example('عَذَابٌ اَلِيمُۢ'), findsOneWidget);
      expect(example('خَلَوِاْ اِلَىٰ'), findsOneWidget);
      expect(example('يُومِنُونَۖ'), findsOneWidget);
      expect(example('عَذَابٌ أَلِيمُۢ'), findsNothing);
      expect(t.takeException(), isNull);
    }
  });

  test('a replacement circle removes only the target hamza from its seat', () {
    for (final target in ['أَ', 'إِ', 'أَ', 'إِ', 'ٱ', 'اَ۬', 'اِ۪']) {
      final text = 'ٱلسُّفَهَآءُ $targetلَا';
      final offset = text.lastIndexOf(' ') + 1;
      final shown = HamzaReplacementMark.seatText(text, offset);
      expect(shown.substring(0, offset), text.substring(0, offset));
      expect(shown.substring(offset), startsWith('ا'));
      expect(shown.substring(offset), isNot(matches('[أإٱٕ۪ٔ۬]')));
      expect(shown.substring(offset, offset + 1), 'ا');
      expect(
        RegExp('[َُِ]')
            .hasMatch(shown.substring(offset, shown.indexOf('لَا', offset))),
        isFalse,
      );
      expect(shown.endsWith('لَا'), isTrue);
    }
  });

  testWidgets(
    'wasl uses the Hafs sign without a vowel or circle across Warsh',
    (t) async {
      for (var p = 1; p <= 604; p++) {
        for (final a in quran.page(p)) {
          for (var w = 0; w < a.words.length; w++) {
            final text = variants.sourceTextAt('warsh', a.surah, a.number, w)!;
            expect(
              text,
              isNot(matches('ا[َُِ]۟')),
              reason: '${a.surah}:${a.number}:$w',
            );
          }
        }
      }
      for (final (p, a, w) in [(4, 21, 2), (6, 34, 3), (6, 35, 2)]) {
        await page(
          t,
          p,
          settings: ReaderSettings.memory(selected: {'warsh'})
            ..displayed = 'warsh',
        );
        final word = t.widget<InkText>(find.byKey(ValueKey('word:2:$a:$w')));
        expect(word.text, startsWith('ٱ'));
        expect(word.text, isNot(contains('۟')));
      }
      expect(t.takeException(), isNull);
    },
  );

  test(
    'a standalone hamza keeps its width, vowel and neighbouring colours',
    () {
      const before = 'هَٰٓؤُلَآءِ ';
      final parts = HamzaReplacementMark.hideHamza([
        (before, Colors.green),
        ('ءَالِهَةً', Colors.red),
      ], before.length);
      expect(parts.map((p) => p.$1).join(), 'هَٰٓؤُلَآءِ ءَالِهَةً');
      expect(parts.where((p) => p.$2 == Colors.transparent).single.$1, 'ء');
      expect(parts.first, (before, Colors.green));
      expect(parts.last, ('َالِهَةً', Colors.red));
    },
  );

  testWidgets(
    'circles stay on the target seat at different scales and widths',
    (t) async {
      addTearDown(t.view.reset);
      for (final size in [const Size(430, 860), const Size(860, 430)]) {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        for (final scale in [1.0, 1.8]) {
          for (final fontSize in [12.0, 32.0]) {
            for (final letter in ['و', 'ي']) {
              const original = 'ٱلسُّفَهَآءُ أَلَآ';
              final offset = original.lastIndexOf(' ') + 1;
              final style = TextStyle(
                fontFamily: 'Hafs',
                fontSize: fontSize,
                height: 1.4,
              );
              await t.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Center(
                      child: HamzaReplacementMark(
                        text: original,
                        offset: offset,
                        letter: letter,
                        style: style,
                        color: ReadingColors.hamza,
                        builder: (shown, _) => Text(
                          shown,
                          textDirection: TextDirection.rtl,
                          style: style,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final text = find.descendant(
                of: find.byType(HamzaReplacementMark),
                matching: find.byType(Text),
              );
              final paragraph = t.renderObject<RenderParagraph>(text);
              final box = paragraph
                  .getBoxesForSelection(
                    TextSelection(baseOffset: offset, extentOffset: offset + 1),
                  )
                  .single;
              final paint = find
                  .descendant(
                    of: find.byType(HamzaReplacementMark),
                    matching: find.byType(CustomPaint),
                  )
                  .first;
              final painter = t.widget<CustomPaint>(paint).foregroundPainter!;
              late Offset center;
              expect(
                (Canvas canvas) => painter.paint(canvas, t.getSize(paint)),
                paints..something((method, args) {
                  if (method != #drawCircle) return false;
                  center = args[0] as Offset;
                  return true;
                }),
              );
              expect(center.dx, closeTo((box.left + box.right) / 2, 0.1));
              expect(center.dy, inInclusiveRange(box.top, box.bottom));
              expect(
                letter == 'و'
                    ? center.dy < (box.top + box.bottom) / 2
                    : center.dy > (box.top + box.bottom) / 2,
                isTrue,
              );
              expect(t.takeException(), isNull);
            }
          }
        }
      }
    },
  );

  testWidgets(
    'circled waw above and ya below the second hamza',
    tags: 'golden',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('marks'),
                child: Container(
                  width: 640,
                  height: 460,
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final (text, letter) in [
                        ('ٱلسُّفَهَآءُ أَلَآ', 'و'),
                        ('ٱلنِّسَآءِ أَوۡ', 'ي'),
                        ('يَشَآءُ إِلَىٰ', 'و'),
                        ('هَٰٓؤُلَآءِ ءَالِهَةً', 'ي'),
                        ('هَٰٓؤُلَآءِ إِن', 'ي'),
                      ])
                        HamzaReplacementMark(
                          text: text,
                          letter: letter,
                          offset: text.lastIndexOf(' ') + 1,
                          style: const TextStyle(
                            fontFamily: 'Hafs',
                            fontSize: 54,
                            height: 1,
                          ),
                          color: ReadingColors.hamza,
                          builder: (shown, hidden) => Text.rich(
                            TextSpan(
                              children: [
                                for (final (part, color)
                                    in HamzaReplacementMark.hideHamza([
                                      (shown, Colors.black),
                                    ], hidden))
                                  TextSpan(
                                    text: part,
                                    style: TextStyle(color: color),
                                  ),
                              ],
                            ),
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: 'Hafs',
                              fontSize: 54,
                              height: 1,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('marks')),
        matchesGoldenFile('goldens/warsh_hamza_marks.png'),
      );
    },
  );

  testWidgets('page 3 with corrected Warsh rules', tags: 'golden', (t) async {
    await page(t, 3);
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p3_warsh_rules.png'),
    );
    await t.ensureVisible(find.text('النقل:'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p3_warsh_usul_footer.png'),
    );
  });

  testWidgets('portrait left page has its margin on the left', tags: 'golden', (
    t,
  ) async {
    await page(t, 20);
    await t.pumpAndSettle();
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(
      t.getRect(find.byKey(const ValueKey('side-note-0'))).right,
      lessThanOrEqualTo(print.left),
    );
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p20_warsh_left_margin.png'),
    );
  });

  testWidgets('Warsh hamza faces in the footer of page 424', tags: 'golden', (
    t,
  ) async {
    await page(t, 424);
    await t.ensureVisible(find.textContaining('الحركة العارضة'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/p424_warsh_hamza_faces.png'),
    );
  });

  testWidgets(
    'Warsh displayed with Hafs compared keeps rule colours',
    tags: 'golden',
    (t) async {
      await page(
        t,
        3,
        settings: ReaderSettings.memory(selected: {'warsh'})
          ..displayed = 'warsh'
          ..compareHafs = true,
      );
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile('goldens/p3_warsh_rule_colors_compared.png'),
      );
    },
  );
}

class _DenseVariants extends VariantRepository {
  _DenseVariants() : super({'warsh'});

  @override
  bool isLoaded(String id) => id == 'warsh';

  @override
  Iterable<Variant> at(
    Iterable<String> ids,
    int surah,
    int ayah,
    int word,
  ) sync* {
    if (!ids.contains('warsh') || word.isOdd) return;
    yield Variant(
      riwayaId: 'warsh',
      surah: surah,
      ayah: ayah,
      word: word,
      count: 1,
      text: 'قِرَاءَة',
      kind: VariantKind.farsh,
      description: 'بفتح الحرف وتشديده وتغيير الحركة في هذا الموضع رقم $word',
    );
  }
}
