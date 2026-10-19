import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quranpedia_qiraat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/mutashabihat_sheet.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

const fonts = {'Hafs': 'hafs.18'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran, shamarly;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;

  setUpAll(() async {
    for (final MapEntry(key: family, value: file) in fonts.entries) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$file.ttf'))).load();
    }
    quran = await QuranRepository.load();
    shamarly = await QuranRepository.load(null, MushafEdition.shamarly);
    variants = await VariantRepository.discover();
    mutashabihat = await MutashabihatRepository.load();
    await variants.ensureLoaded(variants.available);
  });

  test('base text has 604 pages and 114 surahs', () {
    expect(quran.surahs, hasLength(114));
    expect(quran.page(1), hasLength(7));
    expect(quran.page(604).last.surah, 114);
    var ayahs = 0;
    for (var p = 1; p <= quran.pageCount; p++) {
      ayahs += quran.page(p).length;
    }
    expect(ayahs, 6236);
  });

  test('riwayat files are discovered from the asset folder', () {
    expect(
      variants.available,
      containsAll([
        'warsh',
        'qalun',
        'bazzi',
        'qunbul',
        'duri_abuamr',
        'susi',
        'shubah',
      ]),
    );
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
    expect(
      describe('warsh', 2, 9, 5),
      'بضم الياء وفتح الخاء وإثبات الألف وكسر الدال',
    );
  });

  Future<void> shot(
    WidgetTester tester,
    int page,
    ReaderSettings settings,
    String name, {
    QuranRepository? mushaf,
  }) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    // Labels in an Arabic font: the test environment has no system Arabic font.
    final theme = buildTheme(MushafPalette.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: page,
              quran: mushaf ?? quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: settings,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    // The hamesh is split after the first layout.
    await tester.pump();
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('page 1, Hafs only', tags: 'golden', (t) async {
    await shot(t, 1, ReaderSettings.memory(), 'p1_hafs');
  });

  testWidgets('Shamarly page 42: header over two lines, Nafi in the hamesh',
      tags: 'golden', (t) async {
    await shot(t, 42, ReaderSettings.memory(selected: {'warsh', 'qalun'}),
        'shamarly_p42', mushaf: shamarly);
  });

  testWidgets('page 3, Hafs only: the 15 printed lines', tags: 'golden', (
    t,
  ) async {
    await shot(t, 3, ReaderSettings.memory(), 'p3_hafs');
  });

  testWidgets(
    'page 1, Nafi + Ibn Kathir + Abu Amr highlighted',
    tags: 'golden',
    (t) async {
      await shot(
        t,
        1,
        ReaderSettings.memory(
          selected: {'warsh', 'qalun', 'bazzi', 'susi'},
          mode: DisplayMode.highlight,
        ),
        'p1_highlight',
      );
    },
  );

  testWidgets('page 2, Warsh inline', tags: 'golden', (t) async {
    await shot(
      t,
      2,
      ReaderSettings.memory(selected: {'warsh'}, mode: DisplayMode.inline),
      'p2_inline',
    );
  });

  testWidgets('page 2, rewritten as Warsh', tags: 'golden', (t) async {
    await shot(
      t,
      2,
      ReaderSettings.memory(selected: {'warsh'}, mode: DisplayMode.replace),
      'p2_replace',
    );
  });

  testWidgets('page 1, hamesh with three qiraat', tags: 'golden', (t) async {
    await shot(
      t,
      1,
      ReaderSettings.memory(
        selected: {'warsh', 'qalun', 'bazzi', 'qunbul', 'susi'},
      ),
      'p1_hamesh',
    );
  });

  testWidgets('page 601 (three surahs), hamesh', tags: 'golden', (t) async {
    await shot(
      t,
      601,
      ReaderSettings.memory(
        selected: {'warsh', 'qalun', 'duri_abuamr', 'susi', 'shubah'},
      ),
      'p601_hamesh',
    );
  });

  testWidgets(
    'page 225, Warsh in place: Madinah script, imala in green',
    tags: 'golden',
    (t) async {
      await shot(
        t,
        225,
        ReaderSettings.memory(selected: {'warsh'}, mode: DisplayMode.replace),
        'p225_warsh',
      );
    },
  );

  testWidgets(
    'page 3 shown in Warsh (badal green, tarqiq orange), Qalun against it',
    tags: 'golden',
    (t) async {
      await shot(
        t,
        3,
        ReaderSettings.memory(selected: {'warsh', 'qalun'})
          ..displayed = 'warsh',
        'p3_warsh_base',
      );
    },
  );

  testWidgets(
    'page 28 in Warsh: naql and alef of wasl without circles',
    tags: 'golden',
    (t) async {
      await shot(
        t,
        28,
        ReaderSettings.memory(selected: {'warsh'})..displayed = 'warsh',
        'p28_warsh_naql',
      );
    },
  );

  testWidgets(
    'pages 7 and 19 in Khalaf: sakt with its sign, no description in the '
    'text, no difference where only the ghunna differs',
    tags: 'golden',
    (t) async {
      for (final page in [7, 19]) {
        await shot(
          t,
          page,
          ReaderSettings.memory(selected: {'khalaf_hamzah'})
            ..displayed = 'khalaf_hamzah',
          'p${page}_khalaf',
        );
      }
    },
  );

  testWidgets(
    'page 2 and 13 in Warsh: only the naql and badal letters coloured',
    tags: 'golden',
    (t) async {
      for (final page in [2, 13]) {
        await shot(
          t,
          page,
          ReaderSettings.memory(selected: {'warsh'})..displayed = 'warsh',
          'p${page}_warsh_letters',
        );
      }
    },
  );

  testWidgets(
    'page 225, Hamzah and al-Kisa\'i: imala sign added',
    tags: 'golden',
    (t) async {
      await shot(
        t,
        225,
        ReaderSettings.memory(selected: {'khalaf_hamzah', 'duri_kisai'}),
        'p225_imala',
      );
    },
  );

  testWidgets(
    'page 269, Nafi'
    ' in the hamesh',
    tags: 'golden',
    (t) async {
      await shot(
        t,
        269,
        ReaderSettings.memory(selected: {'warsh', 'qalun'}),
        'p269_hamesh',
      );
    },
  );

  test('mutashabihat link similar ayahs and mark the shared words', () {
    // ٱلصَّلَوٰةَ وَمِمَّا رَزَقۡنَٰهُمۡ يُنفِقُونَ (2:3) ~ 8:3, 27:3, 31:4.
    expect(mutashabihat.isShared(2, 3, 4), isTrue);
    final places = mutashabihat.placesFor(2, 3, 4);
    expect(places.first.key, '2:3');
    expect(places.map((p) => p.key), containsAll(['8:3', '27:3', '31:4']));
    expect(mutashabihat.isShared(1, 1, 0), isFalse);
  });

  testWidgets('mutashabihat carousel', tags: 'golden', (t) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
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
            body: MutashabihatSheet(
              places: mutashabihat.placesFor(2, 3, 4),
              quran: quran,
              onGo: (_) {},
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MutashabihatSheet),
      matchesGoldenFile('goldens/mutashabihat.png'),
    );
  });

  test('Quranpedia qiraat are converted onto the Hafs words', () {
    Map<String, Object> rawi(int id) => {
      'rawi': {'id': id, 'name': ''},
    };
    // Hand-made response in the shape of GET /v1/ayah/{s}/{a}/qiraat.
    final response = [
      {
        'ayah_word': 'وَمَا يَخْدَعُونَ',
        'qiraat': [
          {
            'qiraa_text': 'وما يَخْدَعُونَ',
            'rewayat': [rawi(10), rawi(12)],
          },
          {
            'qiraa_text': '(وما يُخَادِعُونَ) بضم الياء وألف بعد الخاء',
            'rewayat': [rawi(7)],
          },
        ],
      },
      {
        'ayah_word': 'إِلَّا أَنفُسَهُمْ',
        'qiraat': [
          {
            'qiraa_text': 'بالفتح',
            'rewayat': [rawi(10)],
          },
          {
            'qiraa_text': 'بالإمالة',
            'rewayat': [rawi(17)],
          },
        ],
      },
    ];
    final ayah = quran.ayah(2, 9);
    final vs = QuranpediaQiraat.convert(ayah, response);
    final hisham = vs.singleWhere((v) => v.riwayaId == 'hisham');
    expect(ayah.words[hisham.word], 'وَمَا');
    expect(hisham.count, 2);
    expect(hisham.text, 'وما يُخَادِعُونَ');
    expect(hisham.description, 'بضم الياء وألف بعد الخاء');
    expect(hisham.kind, VariantKind.farsh);
    // Khallad reads like Hafs here; Hafs itself is never a variant.
    expect(
      vs.where((v) => v.riwayaId == 'khallad' || v.riwayaId == 'hafs'),
      isEmpty,
    );
    final ruways = vs.singleWhere((v) => v.riwayaId == 'ruways');
    expect(ruways.text, isEmpty);
    expect(ruways.description, 'بالإمالة');
    expect(ruways.kind, VariantKind.usul);
    // Word breaks differ between the texts: يَا عِبَادِ / يَٰعِبَادِ.
    final yaIbadi = quran.ayah(43, 68);
    final split = QuranpediaQiraat.convert(yaIbadi, [
      {
        'ayah_word': 'يَا عِبَادِ',
        'qiraat': [
          {
            'qiraa_text': '(يَا عِبَادِيَ) بإثبات الياء مفتوحة',
            'rewayat': [rawi(15)],
          },
        ],
      },
    ]).single;
    expect(yaIbadi.words[split.word], 'يَٰعِبَادِ');
    expect(split.count, 1);
  });
}
