import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/usul_text.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';
import 'package:qiraat_mushaf/ui/usul_labels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late MutashabihatRepository mutashabihat;

  setUpAll(() async {
    quran = await QuranRepository.load();
    mutashabihat = await MutashabihatRepository.load();
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  /// The word as the page of [id] draws it.
  Future<String?> shown(WidgetTester t, String id, int s, int a, int w) async {
    final variants = VariantRepository({id});
    await t.runAsync(() => variants.ensureLoaded([id]));
    final ayah = quran.ayah(s, a);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: ayah.page,
              quran: quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: ReaderSettings.memory(selected: {id})
                ..page = ayah.page
                ..displayed = id
                ..qcfFont = false,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump();
    final display = t.widget<MushafLines>(find.byType(MushafLines)).display!;
    return display(ayah, w)?.text;
  }

  for (final id in ['qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz']) {
    testWidgets("$id: the separated madd short has no sign on the page", (
      t,
    ) async {
      addTearDown(t.view.reset);
      t.view.physicalSize = const Size(620, 1000);
      t.view.devicePixelRatio = 1;
      // «مَآ أُوتِيتُمۡ» (آل عمران ٧٣), with Hafs's madd sign.
      final words = quran.ayah(3, 73).words;
      final at = [
        for (var i = 0; i + 1 < words.length; i++)
          if (words[i].contains('ٓ') && words[i + 1].startsWith('أ')) i,
      ].first;
      final text = await shown(t, id, 3, 73, at);
      expect(text, isNot(contains('ٓ')));
    });
  }

  test('the first of two sakins tells its letter, joined', () {
    expect(
      firstSakinNote('بضم نون التنوين وصلاً لالتقاء الساكنين'),
      'بضم نون التنوين وصلًا',
    );
    expect(firstSakinNote('بضم النون لالتقاء الساكنين'), 'بضم النون وصلًا');
  });

  test('a word with a farsh is cited for its farsh alone', () {
    Variant row(String id, VariantKind kind, String d, {String rule = ''}) =>
        Variant(
          riwayaId: id,
          surah: 3,
          ayah: 120,
          word: 13,
          count: 1,
          text: 'x',
          kind: kind,
          description: d,
          rule: rule,
        );
    final farsh = row('qalun', VariantKind.farsh, 'بكسر الضاد وإسكان الراء');
    final silah = row('qalun', VariantKind.usul, 'بصلة ميم الجمع');
    final usulOnly = row('ibn_wardan', VariantKind.usul, 'بصلة ميم الجمع');
    final compared = row('bazzi', VariantKind.farsh, '', rule: 'comparison');
    final silahOfCompared = row('bazzi', VariantKind.usul, 'بصلة ميم الجمع');
    expect(citedReadings([silah, farsh, usulOnly, compared, silahOfCompared]), [
      farsh,
      compared,
    ]);
  });

  test("Ibn Wardan's «مِلُ» is told in the naql, not the hamza", () {
    const v = Variant(
      riwayaId: 'ibn_wardan',
      surah: 3,
      ayah: 91,
      word: 10,
      count: 1,
      text: 'مِلُ',
      kind: VariantKind.hamza,
      description: 'بضم اللام وحذف الهمزة',
      rule: 'naql',
    );
    expect(usulOf(v), ['النقل']);
  });

  test(
    "Qalun's «أَنۢبِئَآءَ»: Hafs's word in the hamesh, the body changed",
    () async {
      final variants = VariantRepository({'qalun', 'bazzi'});
      await variants.ensureLoaded(['qalun', 'bazzi']);
      final notes = otherBodyNotes(
        variants,
        quran.ayah(3, 112),
        27,
        'qalun',
        const ['bazzi'],
        const [],
      );
      expect(notes.map((v) => v.riwayaId), ['bazzi']);
      final singular = otherBodyNotes(
        variants,
        quran.ayah(3, 84),
        18,
        'qalun',
        const ['bazzi'],
        const [],
      );
      expect(singular.map((v) => v.riwayaId), ['bazzi']);
    },
  );

  for (final id in ['qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz']) {
    testWidgets('$id: no separated madd drawn anywhere in the mushaf', (
      t,
    ) async {
      addTearDown(t.view.reset);
      t.view.physicalSize = const Size(620, 1000);
      t.view.devicePixelRatio = 1;
      await shown(t, id, 1, 1, 0);
      final display = t.widget<MushafLines>(find.byType(MushafLines)).display!;
      final signed = RegExp('ٓ(ا[ْ۟]?)?[ۖ-ۜ]*\$');
      final bad = <String>[];
      var sites = 0;
      for (var s = 1; s <= 114; s++) {
        for (var a = 1; a <= quran.surah(s).ayahCount; a++) {
          final ayah = quran.ayah(s, a);
          for (var w = 0; w + 1 < ayah.words.length; w++) {
            if (!signed.hasMatch(ayah.words[w]) ||
                !RegExp('^[ءأإآ]').hasMatch(ayah.words[w + 1])) {
              continue;
            }
            sites++;
            final text = display(ayah, w)?.text;
            if (text != null && signed.hasMatch(text)) {
              bad.add('$s:$a:$w $text');
            }
          }
        }
      }
      expect(sites, greaterThan(2900));
      expect(bad, isEmpty);
    });
  }

  testWidgets('ha antum in the hamesh: a row for each face', (t) async {
    addTearDown(t.view.reset);
    t.view.physicalSize = const Size(620, 2600);
    t.view.devicePixelRatio = 1;
    const ids = {'qalun', 'bazzi', 'qunbul', 'ibn_wardan'};
    final variants = VariantRepository(ids);
    await t.runAsync(() => variants.ensureLoaded(ids));
    final ayah = quran.ayah(3, 66);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: ayah.page,
              quran: quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: ReaderSettings.memory(selected: ids)
                ..page = ayah.page
                ..displayed = 'qalun'
                ..qcfFont = false,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pump();
    for (final face in [
      'إثبات الألف وهمزة مسهلة',
      'إثبات الألف وهمزة محققة بعدها',
      'حذف الألف مع تحقيق الهمزة',
    ]) {
      expect(
        find.text(face, skipOffstage: false),
        findsOneWidget,
        reason: face,
      );
    }
  });

  testWidgets(
    "Ibn Kathir's «يُؤَدِّهِۦ»: the sign of the silah, no madd over it",
    (t) async {
      addTearDown(t.view.reset);
      t.view.physicalSize = const Size(620, 1000);
      t.view.devicePixelRatio = 1;
      for (final id in ['bazzi', 'qunbul']) {
        for (final w in [7, 15]) {
          final text = await shown(t, id, 3, 75, w);
          expect(text, contains('ۦ'));
          expect(text, isNot(contains('ٓ')));
        }
      }
    },
  );
}
