import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/usul_text.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import '../tool/build_data.dart' show sourceWords;
import '../tool/build_warsh_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  late List<Map> source;
  late Map sourceAsset;
  String compact(String s) => s.replaceAll(RegExp(r'\s+'), '');
  String expectedSurah(int s) {
    final text = source
        .where((a) => a['sura_no'] == s)
        .expand((a) => sourceWords(a['aya_text'] as String))
        .join(' ');
    return compact(madinahScript('${s == 1 ? '${quran.basmala} ' : ''}$text'));
  }

  setUpAll(() async {
    quran = await QuranRepository.load();
    variants = VariantRepository({'warsh'});
    await variants.ensureLoaded(['warsh']);
    mutashabihat = await MutashabihatRepository.load();
    source = (jsonDecode(
      File('../tools/source/warshData_v10.json')
          .readAsStringSync()
          .replaceFirst('\uFEFF', ''),
    ) as List).cast<Map>();
    sourceAsset = jsonDecode(
      File('assets/data/reading_texts/warsh.json').readAsStringSync(),
    ) as Map;
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  Future<void> showPage(
    WidgetTester t,
    int page, {
    Size size = const Size(430, 860),
    DisplayMode mode = DisplayMode.hamesh,
    VoidCallback? onNumber,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    final theme = buildTheme(MushafPalette.light);
    final settings = ReaderSettings.memory(selected: {'warsh'}, mode: mode)
      ..displayed = 'warsh';
    await t.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: MushafPage(
              page: page,
              quran: quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: settings,
              onWordTap: (_, _) {},
              onPageNumberTap: onNumber,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  test('complete Warsh text round-trips all 114 source surahs and rebuilds identically', () {
    final base =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    expect(jsonEncode(buildWarshText(base, source)), jsonEncode(sourceAsset));
    expect(sourceAsset['ayahs'], hasLength(6236));
    final empty = <String>[];
    for (final a in sourceAsset['ayahs'] as List) {
      final anchor = quran.ayah(a[0] as int, a[1] as int);
      expect(a[2], hasLength(anchor.words.length));
      for (var w = 0; w < anchor.words.length; w++) {
        if (a[2][w] == '') empty.add('${a[0]}:${a[1]}:$w');
      }
    }
    // وَأَنْ replaces أو أن; هو is omitted in Nafi's reading at 57:24.
    expect(empty, ['40:26:13', '57:24:9']);
    for (var s = 1; s <= 114; s++) {
      final actual = (sourceAsset['ayahs'] as List)
          .where((a) => a[0] == s)
          .expand((a) => (a[2] as List).cast<String>())
          .join(' ');
      // A full alif of the source is written as Hafs's dagger alif where his
      // rasm has one (إِسْرَٰٓءِيلَ), and a hamza below the kashida above it
      // (خَٰسِـِٔينَ), a kashida apart (مِيكَـٰٓئِلَ): the same letters, either way.
      String alif(String t) =>
          t.replaceAll('ٰ', 'ا').replaceAll('ٕ', 'ٔ').replaceAll('ـ', '');
      expect(
        alif(compact(madinahScript(actual))),
        alif(expectedSurah(s)),
        reason: 'surah $s',
      );
    }
  });

  test('native Warsh verse boundaries match every KFGQPC source verse', () {
    final numbering = quran.numbering!;
    final mismatches = <String>[];
    for (final row in source) {
      final s = row['sura_no'] as int;
      final n = row['aya_no'] as int;
      final range = numbering.span('madani-last', s, n);
      final actual = [
        for (var a = range.first.ayah; a <= range.last.ayah; a++)
          for (
            var w = a == range.first.ayah ? range.first.word : 0;
            w <=
                (a == range.last.ayah
                    ? range.last.word
                    : quran.ayah(s, a).words.length - 1);
            w++
          )
            variants.sourceTextAt('warsh', s, a, w)!,
      ].join(' ');
      final expected = madinahScript(
        sourceWords(row['aya_text'] as String).join(' '),
      );
      if (skeleton(actual) != skeleton(expected)) {
        mismatches.add('Warsh $s:$n: ${range.first}–${range.last}');
      }
    }
    expect(mismatches, isEmpty);
  });

  test('empty annotation notes never erase Quran words; actual raw deletions remain possible', () {
    Variant v(String text, VariantKind kind, String rule, String description) =>
        Variant(
          riwayaId: 'warsh',
          surah: 24,
          ayah: 20,
          word: 7,
          count: 1,
          text: text,
          kind: kind,
          rule: rule,
          description: description,
        );
    expect(v('', VariantKind.farsh, 'kharouf', '').canReplaceText, isFalse);
    expect(v('', VariantKind.usul, '', '').canReplaceText, isFalse);
    expect(v('', VariantKind.farsh, '', 'بالإمالة').canReplaceText, isFalse);
    expect(v('', VariantKind.farsh, '', '').canReplaceText, isTrue);
    expect(variants.at(['warsh'], 24, 20, 7).where((v) => v.inHamesh), isEmpty);
  });

  test(
    'every exported shayan keeps a ya separate from its following hamza',
    () {
      var checked = 0;
      for (final a in sourceAsset['ayahs'] as List) {
        for (final (w, raw) in (a[2] as List).indexed) {
          if (!(raw as String).contains('شَئْ')) continue;
          final shown = variants.sourceTextAt(
            'warsh',
            a[0] as int,
            a[1] as int,
            w,
          )!;
          expect(shown, contains('شَيۡـٔ'), reason: '${a[0]}:${a[1]}:$w');
          expect(lettersOf(shown).map((l) => l[0]), ['ش', 'ي', 'ـ', 'ا']);
          checked++;
        }
      }
      expect(checked, 77);
    },
  );

  test('replacement waw and ya keep their vowel without the Maghribi dot', () {
    var checked = 0;
    for (final a in sourceAsset['ayahs'] as List) {
      for (final (w, raw) in (a[2] as List).indexed) {
        if (!RegExp('([وي])۬(?=[َُِ])').hasMatch(raw as String)) continue;
        final shown = variants.sourceTextAt(
          'warsh',
          a[0] as int,
          a[1] as int,
          w,
        )!;
        expect(shown, isNot(contains('۬')), reason: '${a[0]}:${a[1]}:$w');
        expect(shown, contains(RegExp('[وي]َ')));
        checked++;
      }
    }
    expect(checked, greaterThanOrEqualTo(30));
    expect(variants.sourceTextAt('warsh', 2, 225, 1), 'يُوَاخِذُكُمُ');
  });

  testWidgets('page 36 ibdal shows a plain waw with fatha', (t) async {
    addTearDown(t.view.reset);
    await showPage(t, 36);
    for (final w in [1, 7]) {
      final ink = t.widget<InkText>(find.byKey(ValueKey('word:2:225:$w')));
      expect(ink.text, contains('وَا'));
      expect(ink.text, isNot(contains('۬')));
      expect(lettersOf(ink.text).where((p) => p.startsWith('و')).single, 'وَ');
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('page 34 shayan retains its ya and the lin colour', (t) async {
    addTearDown(t.view.reset);
    await showPage(t, 34);
    for (final w in [9, 16]) {
      final ink = t.widget<InkText>(find.byKey(ValueKey('word:2:216:$w')));
      expect(ink.text, 'شَيۡـٔاٗ');
      expect(
        ink.parts!.where((p) => p.$1.startsWith('ي')).single.$2,
        MushafColors.green,
      );
    }
    expect(t.takeException(), isNull);
  });

  test(
    'repeated words and a joined source-export word retain individual anchors',
    () {
      for (var w = 0; w < 3; w++) {
        final text = variants.sourceTextAt('warsh', 17, 7, w)!;
        expect(text, isNotEmpty);
        expect(text.contains(' '), isFalse);
      }
      expect(
        variants.sourceTextAt('warsh', 41, 51, 5),
        isNot(contains('بِجَانِبِهِ')),
      );
      expect(
        variants.sourceTextAt('warsh', 41, 51, 6),
        contains('بِجَانِبِهِ'),
      );
    },
  );

  test('Maryam book lists do not create another word on ala or duplicate both readings', () {
    expect(variants.at(['warsh'], 19, 69, 7).where((v) => v.inHamesh), isEmpty);
    for (final (a, w) in [(69, 9), (70, 7)]) {
      final reading = variants
          .at(['warsh'], 19, a, w)
          .singleWhere((v) => v.kind == VariantKind.farsh);
      expect(reading.text, isNot(contains('،')));
    }
  });

  testWidgets(
    'actual word display across all 604 pages matches the complete Warsh source',
    (t) async {
      addTearDown(t.view.reset);
      await showPage(t, 1);
      final display = t.widget<MushafLines>(find.byType(MushafLines)).display!;
      final actual = <int, StringBuffer>{};
      final seen = <int>{};
      var words = 0;
      for (var p = 1; p <= 604; p++) {
        for (final line in quran.lines(p)!) {
          if (line is! TextLine) continue;
          for (final (ayah, w) in line.words) {
            final key = VariantRepository.key(ayah.surah, ayah.number, w);
            expect(
              seen.add(key),
              isTrue,
              reason: 'duplicate word on page $p: $key',
            );
            final shown = display(ayah, w);
            final rawSource = variants.sourceTextAt(
              'warsh',
              ayah.surah,
              ayah.number,
              w,
            )!;
            final marked = variants
                .at(['warsh'], ayah.surah, ayah.number, w)
                .map((v) => hamzaPairMaddText(v, rawSource))
                .whereType<String>()
                .firstOrNull;
            // His second hamza of two words, eased only: drawn on Hafs's
            // hamza with the tasheel circle, not as the source's bare alif.
            final eased = variants
                .at(['warsh'], ayah.surah, ayah.number, w)
                .any(
                  (v) =>
                      v.word == w &&
                      v.rule == 'tasheel_pair' &&
                      !v.usulWays.any((u) => u.contains('إبدال')),
                );
            expect(
              shown?.text ?? '',
              eased ? ayah.words[w] : marked ?? rawSource,
              reason: 'page $p ${ayah.surah}:${ayah.number}:$w',
            );
            // Only the explicitly tested display madd is additional to the
            // archived source; all other letters and marks remain exact.
            (actual[ayah.surah] ??= StringBuffer()).write(
              marked == null && !eased ? shown?.text ?? '' : rawSource,
            );
            words++;
          }
        }
      }
      for (var s = 1; s <= 114; s++) {
        expect(
          compact(actual[s].toString())
              .replaceAll('ٰ', 'ا')
              .replaceAll('ٕ', 'ٔ')
              .replaceAll('ـ', ''),
          // As above: dagger alif and hamza above as Hafs writes them.
          expectedSurah(s)
              .replaceAll('ٰ', 'ا')
              .replaceAll('ٕ', 'ٔ')
              .replaceAll('ـ', ''),
          reason: 'rendered surah $s',
        );
      }
      expect(words, greaterThan(77000));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'the reported Nur and Maryam words appear as actual Quran widgets',
    (t) async {
      addTearDown(t.view.reset);
      for (final p in [351, 305, 310]) {
        await showPage(t, p);
        final locations = p == 351
            ? [(24, 20, 5), (24, 20, 6), (24, 20, 7), (24, 20, 8)]
            : p == 305
            ? [(19, 8, 13)]
            : [
                (19, 69, 4),
                (19, 69, 5),
                (19, 69, 6),
                (19, 69, 7),
                (19, 69, 8),
                (19, 69, 9),
                (19, 70, 7),
                (19, 75, 7),
              ];
        for (final (s, a, w) in locations) {
          final word = t.widget<InkText>(find.byKey(ValueKey('word:$s:$a:$w')));
          expect(word.text, variants.sourceTextAt('warsh', s, a, w));
          expect(word.text, isNotEmpty);
        }
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('inline display uses the complete Warsh text too', (t) async {
    addTearDown(t.view.reset);
    await showPage(t, 351, mode: DisplayMode.inline);
    final text = t
        .widgetList<Text>(find.byType(Text))
        .map((v) => v.textSpan?.toPlainText() ?? v.data ?? '')
        .join(' ');
    expect(text, contains(variants.sourceTextAt('warsh', 24, 20, 7)!));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'page number is below the ornament in portrait and landscape and remains tappable',
    (t) async {
      addTearDown(t.view.reset);
      var taps = 0;
      for (final size in [const Size(430, 860), const Size(860, 430)]) {
        await showPage(t, 351, size: size, onNumber: () => taps++);
        final number = find.byKey(const ValueKey('page-number-351'));
        await t.ensureVisible(number);
        await t.pumpAndSettle();
        final frame = t.getRect(
          find.byKey(const ValueKey('mushaf-ornament-351')),
        );
        expect(t.getRect(number).top, greaterThanOrEqualTo(frame.bottom + 6));
        expect(
          find.ancestor(
            of: number,
            matching: find.byKey(const ValueKey('mushaf-ornament-351')),
          ),
          findsNothing,
        );
        await t.tap(number);
        expect(t.takeException(), isNull);
      }
      expect(taps, 2);
    },
  );

  for (final page in [310, 351]) {
    testWidgets('complete Warsh page $page preview', tags: 'golden', (t) async {
      addTearDown(t.view.reset);
      await showPage(t, page, size: const Size(600, 960));
      await expectLater(
        find.byType(MushafPage),
        matchesGoldenFile('goldens/p${page}_warsh_integrity.png'),
      );
      expect(t.takeException(), isNull);
    });
  }
}
