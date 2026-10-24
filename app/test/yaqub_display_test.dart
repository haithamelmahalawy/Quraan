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
import 'package:qiraat_mushaf/ui/hamza_replacement_mark.dart';
import 'package:qiraat_mushaf/ui/quran_word_text.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
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
  }) async {
    t.view.physicalSize = const Size(1080, 2000);
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
  Finder mark(Finder w) =>
      find.ancestor(of: w, matching: find.byType(HamzaReplacementMark));

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
      expect(alerts(word(2, 167, 13)), findsOneWidget);
      expect(t.takeException(), isNull);
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
        expect(find.byKey(const ValueKey('yaqub-madd-note')), findsOneWidget);
        expect(
          find.text('يعقوب: المد المتصل بالتوسط، والمد المنفصل بالقصر'),
          findsOneWidget,
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
            'usul-reference:الإشمام:',
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
      // Unchanged kasra on ha is excluded from the margin, but the written
      // kasra on the mim remains in Yaqub's main reading.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'usul-reference:ميم الجمع:2:142:7:',
              ),
        ),
        findsNothing,
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
          const ValueKey('usul-reference:تسهيل الهمزتين في كلمة:2:6:5:ruways'),
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
