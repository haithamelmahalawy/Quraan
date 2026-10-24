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
      'khalaf_hamzah',
      'khallad',
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
      expect(find.text('الإشمام:'), findsOneWidget);
      for (final narrator in ['ruways', 'hisham']) {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith(
                  'usul-reference:الإشمام:',
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
      expect(text, id == null ? 'يُنَزِّلَ' : 'يُنۡزِلَ');
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
