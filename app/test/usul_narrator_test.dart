import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/reading_colors.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

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

  Variant row(
    String narrator,
    int word,
    String rule,
    String description, {
    String text = '',
  }) => Variant(
    riwayaId: narrator,
    surah: 2,
    ayah: 13,
    word: word,
    count: 1,
    text: text,
    kind: VariantKind.usul,
    rule: rule,
    description: description,
  );

  test('written assimilation compares equally across farsh and usul classifications', () {
    final ayah = Ayah(
      surah: 1,
      number: 1,
      page: 1,
      juz: 1,
      words: ['ٱتَّخَذۡتُمُ'],
    );
    final rows = [
      for (final id in ['shubah', 'warsh', 'hisham', 'ibn_dhakwan'])
        Variant(
          riwayaId: id,
          surah: 1,
          ayah: 1,
          word: 0,
          count: 1,
          text: 'ٱتَّخَتُّمُ',
          kind: id == 'shubah' || id == 'warsh'
              ? VariantKind.farsh
              : VariantKind.usul,
          rule: id == 'shubah' || id == 'warsh' ? '' : 'idgham',
          description: 'بإدغام الذال في التاء',
        ),
    ];
    final repository = _Variants(rows);
    for (final base in ['hafs', 'shubah', 'warsh', 'hisham', 'ibn_dhakwan']) {
      for (final selected in [
        'hafs',
        'shubah',
        'warsh',
        'hisham',
        'ibn_dhakwan',
      ]) {
        final differences = compareReadings(
          repository: repository,
          ayah: ayah,
          word: 0,
          displayed: base == 'hafs' ? null : base,
          selected: [selected],
        );
        expect(
          differences.isNotEmpty,
          (base == 'hafs') != (selected == 'hafs'),
          reason: '$base / $selected',
        );
      }
    }
  });

  testWidgets(
    'each origin names only its owner and unselected Warsh contributes no badal',
    (t) async {
      t.view.physicalSize = const Size(1080, 2000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      final variants = _Variants([
        row('hisham', 1, 'ishmam', 'بإشمام كسرة القاف الضم'),
        row('ruways', 1, 'ishmam', 'بإشمام كسرة القاف الضم'),
        row('warsh', 3, 'badal', 'بمد البدل'),
      ]);
      for (final selected in [
        <String>{'hisham'},
        <String>{'hisham', 'warsh'},
        <String>{'hisham', 'ruways', 'warsh'},
      ]) {
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(MushafPalette.light),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: MushafPage(
                  page: 3,
                  quran: quran,
                  variants: variants,
                  mutashabihat: mutashabihat,
                  settings: ReaderSettings.memory(selected: selected)
                    ..displayed = 'hisham',
                  onWordTap: (_, _) {},
                ),
              ),
            ),
          ),
        );
        await t.pump();
        final ishmam = find.byKey(
          ValueKey(
            'usul-reference:الإشمام:2:13:1:${selected.contains('ruways') ? 'hisham,ruways' : 'hisham'}',
          ),
        );
        expect(ishmam, findsOneWidget);
        expect(
          find.byKey(const ValueKey('usul-reference:مد البدل:2:13:3:warsh')),
          selected.contains('warsh') ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('usul-reference:مد البدل:2:13:3:hisham')),
          findsNothing,
        );
        final qila = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:13:1')),
        );
        expect(qila.parts!.first.$2, ReadingColors.ishmam);
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'displayed narrator owns the colour when two rules target one letter',
    (t) async {
      t.view.physicalSize = const Size(1080, 2000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      // Deliberately overlapping fixture verifies ownership, not a recitation rule.
      final variants = _Variants([
        row('hisham', 1, 'ishmam', 'بإشمام كسرة القاف الضم'),
        row('warsh', 1, 'naql', 'بنقل حركة الهمزة إلى الساكن قبلها وصلاً'),
      ]);
      for (final base in ['hisham', 'warsh']) {
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(MushafPalette.light),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: MushafPage(
                  page: 3,
                  quran: quran,
                  variants: variants,
                  mutashabihat: mutashabihat,
                  settings: ReaderSettings.memory(selected: {'hisham', 'warsh'})
                    ..displayed = base,
                  onWordTap: (_, _) {},
                ),
              ),
            ),
          ),
        );
        await t.pump();
        final qila = t.widget<InkText>(
          find.byKey(const ValueKey('word:2:13:1')),
        );
        expect(
          qila.parts!.first.$2,
          base == 'hisham' ? ReadingColors.ishmam : ReadingColors.naql,
        );
        expect(t.takeException(), isNull);
      }
    },
  );
}

class _Variants extends VariantRepository {
  _Variants(this.rows)
    : super({'hisham', 'ibn_dhakwan', 'ruways', 'warsh', 'shubah'});
  final List<Variant> rows;
  @override
  bool isLoaded(String id) => available.contains(id);
  @override
  Iterable<Variant> at(Iterable<String> ids, int surah, int ayah, int word) =>
      rows.where(
        (v) =>
            ids.contains(v.riwayaId) &&
            v.surah == surah &&
            v.ayah == ayah &&
            v.word <= word &&
            word < v.word + v.count,
      );
}
