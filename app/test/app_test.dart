import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

const fonts = {
  'Hafs': 'hafs.18',
  'Warsh': 'warsh.10',
  'Qaloon': 'qaloon.10',
  'Bazzi': 'bazzi.7',
  'Qumbul': 'qumbul.7',
  'Doori': 'doori.9',
  'Soosi': 'soosi.9',
  'Shouba': 'shouba.8',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;

  setUpAll(() async {
    for (final MapEntry(key: family, value: file) in fonts.entries) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$file.ttf')))
          .load();
    }
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(variants.available);
  });

  test('base text has 604 pages and 114 surahs', () {
    expect(quran.surahs, hasLength(114));
    expect(quran.page(1), hasLength(7));
    expect(quran.page(604).last.surah, 114);
    var ayahs = 0;
    for (var p = 1; p <= QuranRepository.pageCount; p++) {
      ayahs += quran.page(p).length;
    }
    expect(ayahs, 6236);
  });

  test('riwayat files are discovered from the asset folder', () {
    expect(variants.available, containsAll(
        ['warsh', 'qalun', 'bazzi', 'qunbul', 'duri_abuamr', 'susi', 'shubah']));
  });

  test('known variants', () {
    String? read(String id, int s, int a, int w) =>
        variants.at([id], s, a, w).firstOrNull?.text;

    // مَٰلِكِ يَوۡمِ ٱلدِّينِ — Nafi', Ibn Kathir, Abu Amr read مَلِكِ.
    expect(read('warsh', 1, 4, 0), 'مَلِكِ');
    expect(read('bazzi', 1, 4, 0), 'مَلِكِ');
    expect(read('shubah', 1, 4, 0), isNull);
    // Silat mim al-jam' for Ibn Kathir in عَلَيۡهِمۡ (1:7), tagged usul.
    final silah = variants.at(['bazzi'], 1, 7, 3).single;
    expect(silah.text, 'عَلَيۡهِمُۥ');
    expect(silah.kind, VariantKind.usul);
    // وَسَارِعُوٓاْ (3:133) without the waw for Nafi'.
    expect(read('warsh', 3, 133, 0), 'سَارِعُوٓاْ');
  });

  test('variants carry an Arabic description of the change', () {
    String? describe(String id, int s, int a, int w) =>
        variants.at([id], s, a, w).firstOrNull?.description;

    expect(describe('warsh', 1, 4, 0), 'بحذف الألف');
    expect(describe('bazzi', 1, 7, 3), 'بصلة ميم الجمع');
    // وَمَا يَخۡدَعُونَ (2:9) read يُخَٰدِعُونَ by Nafi'.
    expect(describe('warsh', 2, 9, 5),
        'بضم الياء وفتح الخاء وإثبات الألف وكسر الدال');
  });

  Future<void> shot(WidgetTester tester, int page, ReaderSettings settings,
      String name) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    // Labels in an Arabic font: the test environment has no system Arabic font.
    final theme = buildTheme();
    await tester.pumpWidget(MaterialApp(
      theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Hafs')),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MushafPage(
            page: page,
            quran: quran,
            variants: variants,
            settings: settings,
            onWordTap: (_, _) {},
          ),
        ),
      ),
    ));
    await expectLater(
        find.byType(MushafPage), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('page 1, Hafs only', (t) async {
    await shot(t, 1, ReaderSettings.memory(), 'p1_hafs');
  });

  testWidgets('page 1, Nafi + Ibn Kathir + Abu Amr highlighted', (t) async {
    await shot(
        t,
        1,
        ReaderSettings.memory(
            selected: {'warsh', 'qalun', 'bazzi', 'susi'},
            mode: DisplayMode.highlight),
        'p1_highlight');
  });

  testWidgets('page 2, Warsh inline', (t) async {
    await shot(
        t,
        2,
        ReaderSettings.memory(selected: {'warsh'}, mode: DisplayMode.inline),
        'p2_inline');
  });

  testWidgets('page 2, rewritten as Warsh', (t) async {
    await shot(
        t,
        2,
        ReaderSettings.memory(selected: {'warsh'}, mode: DisplayMode.replace),
        'p2_replace');
  });

  testWidgets('page 1, hamesh with three qiraat', (t) async {
    await shot(
        t,
        1,
        ReaderSettings.memory(
            selected: {'warsh', 'qalun', 'bazzi', 'qunbul', 'susi'}),
        'p1_hamesh');
  });

  testWidgets('page 601 (three surahs), hamesh', (t) async {
    await shot(
        t,
        601,
        ReaderSettings.memory(
            selected: {'warsh', 'qalun', 'duri_abuamr', 'susi', 'shubah'}),
        'p601_hamesh');
  });

  testWidgets('page 269, Nafi'' in the hamesh', (t) async {
    await shot(t, 269, ReaderSettings.memory(selected: {'warsh', 'qalun'}),
        'p269_hamesh');
  });
}
