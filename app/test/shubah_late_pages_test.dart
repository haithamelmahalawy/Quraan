import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/book_readings.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import '../tool/correct_reviewed_farsh.dart';

class _BookBundle extends CachingAssetBundle {
  _BookBundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late MutashabihatRepository mutashabihat;
  late VariantRepository variants;
  Variant at(int s, int a, int w) => variants.at(['shubah'], s, a, w).single;

  setUpAll(() async {
    quran = await QuranRepository.load();
    mutashabihat = await MutashabihatRepository.load();
    variants = VariantRepository({'shubah'});
    await variants.ensureLoaded(['shubah']);
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  test('both unshuzu words retain kasr first and damm second', () async {
    const faces = 'بوجهين: الأول بكسر الشين وهو المقدم، والثاني بضم الشين';
    final book = await Kharouf.load();
    for (final (w, text) in [(15, 'ٱنشِزُواْ'), (16, 'فَٱنشِزُواْ')]) {
      final v = at(58, 11, w);
      expect(quran.pageOf(58, 11), 543);
      expect(v.text, text);
      expect(v.kind, VariantKind.farsh);
      expect(v.inHamesh, isTrue);
      expect(v.certified, isTrue);
      expect(v.bookWujuh, faces);
      expect(v.shownDescription, isNot(contains('الأول كحفص')));
      final source = book
          .at(58, 11, w)
          .singleWhere((e) => e.section == 'farsh');
      expect(
        source.readings.where(
          (r) => r.riwayat.contains('shubah') || r.disputed.contains('shubah'),
        ),
        hasLength(2),
      );
    }
  });

  test(
    'nurahu and amrahu keep the damma on ha without the extra waw description',
    () {
      expect(quran.pageOf(61, 8), 552);
      expect(quran.pageOf(65, 3), 558);
      expect(at(61, 8, 7).shownDescription, 'بالإدغام وفتح الراء وضم الهاء');
      expect(at(65, 3, 14).shownDescription, 'بفتح الراء وضم الهاء');
      expect(at(61, 8, 7).text, 'نُّورَهُۥ');
      expect(at(65, 3, 14).text, 'أَمۡرَهُۥۚ');
      expect(at(61, 8, 7).inHamesh, isTrue);
      expect(at(65, 3, 14).inHamesh, isTrue);
    },
  );

  test(
    'Jabrail is farsh with open jim and ra and a kasra hamza replacing ya',
    () {
      final v = at(66, 4, 14);
      expect(quran.pageOf(66, 4), 560);
      expect(v.text, 'وَجَبۡرَئِلُ');
      expect(v.kind, VariantKind.farsh);
      expect(v.shownDescription, 'بفتح الجيم والراء وهمزة مكسورة بدل الياء');
      expect(v.inHamesh, isTrue);
      expect(v.isUsul, isFalse);
    },
  );

  test('tuminun is absent while the independent tadhakkarun farsh is kept', () {
    expect(quran.pageOf(69, 41), 568);
    expect(variants.at(['shubah'], 69, 41, 6), isEmpty);
    expect(at(69, 42, 5).shownDescription, 'بتشديد الذال');
    final book =
        jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
    expect(
      (book['riwayat']['shubah'] as List).where(
        (p) => p[0] == 69 && p[1] == 41 && p[2] == 6,
      ),
      isEmpty,
    );
  });

  test('identical source groups do not reintroduce false farsh from an old data file', () async {
    final book =
        jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
    final entry = (book['entries'] as List).singleWhere(
      (e) => e[0] == 69 && e[1] == 41 && e[2] == 6 && e[4] == 'farsh',
    );
    final old = VariantRepository(
      {'shubah'},
      _BookBundle({
        'assets/data/qiraat/shubah.json': jsonEncode({
          'variants': [
            [69, 41, 6, 1, 'يؤمنون', 'f', 'بالياء'],
          ],
        }),
        'assets/data/kharouf.json': jsonEncode({
          'entries': [entry],
          'riwayat': {'shubah': []},
        }),
      }),
    );
    await old.ensureLoaded(['shubah']);
    expect(old.at(['shubah'], 69, 41, 6), isEmpty);
  });

  test('matching spelling does not erase a different vowel or a pronunciation note', () {
    List group(
      String text,
      List<String> readers,
      String how, {
      bool stop = false,
    }) => [text, readers, [], how, stop, false, []];
    final hafs = group('تؤمنون', ['hafs'], '');
    expect(bookReadingAsHafs(group('تؤمنون', ['shubah'], ''), [hafs]), isTrue);
    expect(
      bookReadingAsHafs(group('تؤمنون', ['shubah'], 'بالإمالة'), [hafs]),
      isFalse,
    );
    expect(
      bookReadingAsHafs(group('تؤمنون', ['shubah'], '', stop: true), [hafs]),
      isFalse,
    );
    expect(
      bookReadingAsHafs(group('نورَه', ['shubah'], ''), [
        group('نورِه', ['hafs'], ''),
      ]),
      isFalse,
    );
    expect(
      bookReadingAsHafs(group('', ['shubah'], ''), [
        group('', ['hafs'], ''),
      ]),
      isFalse,
    );
  });

  test(
    'a disputed Hafs face alone does not suppress an alternative reading',
    () async {
      final disputed = VariantRepository(
        {'shubah'},
        _BookBundle({
          'assets/data/qiraat/shubah.json': jsonEncode({
            'variants': [
              [58, 11, 15, 1, 'ٱنشِزُواْ', 'f', 'بكسر الشين'],
            ],
          }),
          'assets/data/kharouf.json': jsonEncode({
            'entries': [
              [
                58,
                11,
                15,
                1,
                'farsh',
                [
                  [
                    'انشُزوا',
                    ['hafs'],
                    ['shubah'],
                    '',
                    false,
                    false,
                    [],
                  ],
                ],
                [],
              ],
            ],
            'riwayat': {'shubah': []},
          }),
        }),
      );
      await disputed.ensureLoaded(['shubah']);
      expect(disputed.at(['shubah'], 58, 11, 15).single.text, 'ٱنشِزُواْ');
    },
  );

  test('min raq leaves the sakt in the usul, as Warsh', () {
    final v = variants
        .at(['shubah'], 75, 27, 1)
        .singleWhere((v) => v.rule == 'no_sakt');
    expect(quran.pageOf(75, 27), 578);
    expect(v.count, 1);
    expect(v.rule, 'no_sakt');
    expect(v.shownDescription, 'بالإدغام دون سكت');
    expect(v.isUsul, isTrue);
  });

  test('suda has stopping-only alif imala in usul', () {
    final v = at(75, 36, 4);
    expect(v.text, 'سُدَ۪ى');
    expect(v.shownDescription, 'بإمالة الألف وقفًا');
    expect(v.stopOnly, isTrue);
    expect(v.isImala, isTrue);
    expect(v.isUsul, isTrue);
  });

  test('both qawarira occurrences specify fath tanween in wasl', () {
    for (final (a, w) in [(15, 7), (16, 0)]) {
      final v = at(76, a, w);
      expect(quran.pageOf(76, a), 579);
      expect(v.text, 'قَوَارِيرٗا');
      expect(
        v.shownDescription,
        'بتنوين الراء بالفتح وصلًا، وإبدال التنوين ألفًا وقفًا',
      );
      expect(v.stopOnly, isFalse);
      expect(v.inHamesh, isTrue);
    }
  });

  test('bal ran leaves the sakt in the usul, its ra with imala', () {
    final v = at(83, 14, 1);
    expect(quran.pageOf(83, 14), 588);
    expect(v.count, 1);
    expect(v.rule, 'no_sakt');
    expect(v.shownDescription, 'بالإدغام دون سكت');
    expect(v.isUsul, isTrue);
    expect(at(83, 14, 2).isImala, isTrue);
    expect(at(83, 14, 2).isUsul, isTrue);
  });

  test('musada is farsh with a madd waw replacing hamza', () {
    final v = at(104, 8, 2);
    expect(quran.pageOf(104, 8), 601);
    expect(v.text, 'مُّوصَدَةٞ');
    expect(v.shownDescription, 'بإبدال الهمزة واوًا مدية');
    expect(v.kind, VariantKind.farsh);
    expect(v.inHamesh, isTrue);
    expect(v.isUsul, isFalse);
  });

  test('the reviewed rows survive regeneration without duplicates', () {
    final base =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final rows =
        (jsonDecode(File('assets/data/qiraat/shubah.json').readAsStringSync())
                as Map)['variants']
            as List;
    final before = jsonEncode(rows);
    correctReviewedFarsh('shubah', base, rows);
    expect(jsonEncode(rows), before);
    for (final (s, a, w) in [
      (58, 11, 15),
      (58, 11, 16),
      (61, 8, 7),
      (65, 3, 14),
      (66, 4, 14),
      (75, 27, 1),
      (75, 36, 4),
      (76, 15, 7),
      (76, 16, 0),
      (83, 14, 1),
      (104, 8, 2),
    ]) {
      expect(
        rows.where((r) => r[0] == s && r[1] == a && r[2] == w),
        hasLength(1),
      );
    }
  });

  testWidgets('reviewed late-page descriptions appear in their margins', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final theme = buildTheme(MushafPalette.light);
    for (final (page, description, count) in [
      (543, 'بوجهين: الأول بكسر الشين وهو المقدم، والثاني بضم الشين', 2),
      (552, 'بالإدغام وفتح الراء وضم الهاء', 1),
      (558, 'بفتح الراء وضم الهاء', 1),
      (560, 'بفتح الجيم والراء وهمزة مكسورة بدل الياء', 1),
      (579, 'بتنوين الراء بالفتح وصلًا، وإبدال التنوين ألفًا وقفًا', 2),
      (601, 'بإبدال الهمزة واوًا مدية', 1),
    ]) {
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
                settings: ReaderSettings.memory(selected: {'shubah'}),
                onWordTap: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining(description, findRichText: true),
        findsNWidgets(count),
        reason: 'page $page',
      );
      if (page == 578) {
        expect(find.textContaining('وقفًا', findRichText: true), findsWidgets);
        expect(find.textContaining('سُدَ۪ى', findRichText: true), findsWidgets);
      }
      expect(t.takeException(), isNull);
    }
  });
}
