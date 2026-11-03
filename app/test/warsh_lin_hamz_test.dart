import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/lin_hamz.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/reading_colors.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import '../tool/build_warsh_usul.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  late Manzumat poems;
  late Kharouf book;

  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    variants = VariantRepository({'warsh'});
    await variants.ensureLoaded(['warsh']);
    mutashabihat = await MutashabihatRepository.load();
    poems = await Manzumat.load();
    book = await Kharouf.load();
  });

  Variant lin(int s, int a, int w) =>
      variants.at(['warsh'], s, a, w).singleWhere((v) => v.isLinHamz);

  test('detects sakin lin before hamza in vocalized and Uthmani forms', () {
    for (final word in [
      'شَيْءٍ',
      'شَےْءٖ',
      'شَىْءٖ',
      'شَيۡـٔٗا',
      'كَهَيْئَةِ',
      'كَهَيۡـَٔةِ',
      'ٱسْتَيْـَٔسُواْ',
      'سَوْءَةَ',
      'ٱلسَّوْءِ',
    ]) {
      expect(LinHamz.of(word), LinHamz.regular, reason: word);
    }
    for (final word in [
      'ٱلسُّوءِ',
      'سِيءَ',
      'شَاءَ',
      'بَيْتٍ',
      'خَوْفٍ',
      'سَيِّئَةً',
      'لَوْ أَنَّ',
    ]) {
      expect(LinHamz.of(word), isNull, reason: word);
    }
  });

  test(
    'all generated lin rules are annotation-only usul with separate exceptions',
    () {
      final counts = <LinHamz, int>{};
      for (var p = 1; p <= 604; p++) {
        for (final a in quran.page(p)) {
          // An ayah may span pages; count each on its starting page only.
          if (quran.pageOf(a.surah, a.number) != p) continue;
          for (final (w, text) in a.words.indexed) {
            final kind = LinHamz.of(text);
            if (kind == null) continue;
            final v = lin(a.surah, a.number, w);
            expect(v.rule, kind.rule);
            expect(v.kind, VariantKind.usul);
            expect(v.isUsul, isTrue);
            expect(v.inHamesh, isFalse);
            expect(v.canReplaceText, isFalse);
            expect(v.stopOnly, isFalse);
            expect(v.usulWays, kind.ways);
            expect(ReadingColors.of(v), MushafColors.green);
            expect(ReadingColors.forLabel(kind.label), MushafColors.green);
            counts[kind] = (counts[kind] ?? 0) + 1;
          }
        }
      }
      expect(counts, {
        LinHamz.regular: 297,
        LinHamz.sawat: 5,
        LinHamz.exception: 2,
      });
    },
  );

  test('the reported words have 4/6 in both wasl and waqf and never qasr', () {
    for (final (s, a, w) in [
      (2, 20, 23),
      (3, 49, 15),
      (5, 31, 9),
      (12, 80, 1),
      (12, 110, 2),
      (25, 40, 7),
    ]) {
      final v = lin(s, a, w);
      expect(v.rule, 'lin_hamz');
      expect(v.usulWays, hasLength(2));
      expect(v.usulWays.first, contains('٤ حركات'));
      expect(v.usulWays.last, contains('٦ حركات'));
      expect(v.usulWays.every((way) => way.contains('وصلًا ووقفًا')), isTrue);
      expect(v.usulWays.join(), isNot(contains('٢')));
    }
    expect(
      variants.at(['warsh'], 4, 148, 4).where((v) => v.isLinHamz),
      isEmpty,
    );
  });

  test('book lin faces are not backfilled as farsh anywhere in the Quran', () {
    var checked = 0;
    for (final e in book.entries) {
      for (final r in e.readings) {
        if (!r.riwayat.contains('warsh') ||
            r.text.isNotEmpty ||
            !r.how.contains('اللين') ||
            !RegExp(r'^ب?(التوسط|توسط)').hasMatch(r.how)) {
          continue;
        }
        final at = variants.at(['warsh'], e.surah, e.ayah, e.word).toList();
        if (!at.any((v) => v.isLinHamz)) continue;
        expect(
          at.where((v) => v.inHamesh && v.description == r.how),
          isEmpty,
          reason: '${e.surah}:${e.ayah}:${e.word} ${r.how}',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(40));
    for (final (s, a, w) in [(5, 110, 30), (25, 40, 7), (7, 20, 9)]) {
      expect(variants.at(['warsh'], s, a, w).where((v) => v.inHamesh), isEmpty);
      expect(lin(s, a, w).usulWays, isNotEmpty);
    }
    expect(variants.at(['warsh'], 5, 110, 36).any((v) => v.inHamesh), isTrue);
  });

  test(
    'mawudah and mawilan are the exceptions, sawat has its own faces',
    () {
      for (final (s, a, w) in [(18, 58, 18), (81, 8, 1)]) {
        final v = lin(s, a, w);
        expect(v.rule, 'lin_hamz_exception');
        expect(v.usulWays, ['القصر حركتان فقط وصلًا ووقفًا']);
      }
      for (final (s, a, w) in [
        (7, 20, 9),
        (7, 22, 7),
        (7, 26, 7),
        (7, 27, 14),
        (20, 121, 4),
      ]) {
        expect(lin(s, a, w).rule, 'lin_hamz_sawat');
        expect(lin(s, a, w).usulWays, LinHamz.sawat.ways);
      }
    },
  );

  test('lin and its exceptions cite their own Shatibiyya verses', () {
    final surahs = [for (final s in quran.surahs) s.nameAr];
    for (final (s, a, w, evidence) in [
      (2, 20, 23, {179, 180}),
      (7, 26, 7, {182}),
      (81, 8, 1, {182}),
    ]) {
      final v = lin(s, a, w);
      final ref = poems.referenceOf(
        v,
        quran.ayah(s, a).words[w],
        s,
        surahs,
        entries: book.at(s, a, w),
      );
      expect(ref.poem, Poem.shatibiyya);
      expect(ref.mention, evidence);
      expect(ref.chapter, contains('الْمَدِّ'));
    }
  });

  test('rebuilding rules is idempotent and leaves source words available', () {
    final base =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final source =
        jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
    final rows =
        (jsonDecode(File('assets/data/qiraat/warsh.json').readAsStringSync())
                as Map)['variants']
            as List;
    final before = jsonEncode(rows);
    correctWarshUsul(
      base,
      source,
      rows,
      sourceText: jsonDecode(
        File('assets/data/reading_texts/warsh.json').readAsStringSync(),
      ) as Map,
    );
    expect(jsonEncode(rows), before);
    expect(variants.sourceTextAt('warsh', 2, 20, 23), isNotEmpty);
    expect(variants.sourceTextAt('warsh', 81, 8, 1), isNotEmpty);
  });

  Future<void> showPage(WidgetTester t, int page, {String? displayed}) async {
    t.view.physicalSize = const Size(430, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..displayed = displayed;
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: page,
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
    await t.pumpAndSettle();
  }

  testWidgets(
    'lin uses its own usul heading, green letter and 4/6 faces with Hafs or Warsh displayed',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await showPage(t, 4, displayed: displayed);
        final word = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:20:23')),
        );
        expect(
          word.parts!.where((p) => p.$2 == MushafColors.green),
          hasLength(1),
        );
        final notes = find.byKey(const ValueKey('usul-notes'));
        expect(
          find.descendant(of: notes, matching: find.text('مد اللين المهموز:')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: notes,
            matching: find.textContaining('التوسط ٤ حركات وصلًا ووقفًا'),
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'page 126 keeps kahayati under lin usul with both base readings',
    (t) async {
      for (final displayed in [null, 'warsh']) {
        await showPage(t, 126, displayed: displayed);
        expect(
          find.byKey(
            const ValueKey('usul-reference:مد اللين المهموز:5:110:30:warsh'),
          ),
          findsOneWidget,
        );
        final word = t.widget<InkText>(
          find.byKey(const ValueKey('word:5:110:30')),
        );
        expect(word.parts!.any((p) => p.$2 == MushafColors.green), isTrue);
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('the exception shows qasr in the usul margin', (t) async {
    for (final page in [300, 586]) {
      await showPage(t, page);
      final notes = find.byKey(const ValueKey('usul-notes'));
      expect(
        find.descendant(
          of: notes,
          matching: find.text('مد اللين المهموز (مستثنى):'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: notes,
          matching: find.textContaining('القصر حركتان فقط وصلًا ووقفًا'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    }
  });
}
