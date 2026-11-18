import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/usul_text.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  setUpAll(() async {
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh', 'qunbul', 'khalaf_hamzah', 'khallad']);
  });

  Variant rule(int a, int w, String id) =>
      variants.at(['warsh'], 2, a, w).singleWhere((v) => v.rule == id);
  String text(Variant v) => usulReadingText(
    v,
    quran.ayah(v.surah, v.ayah),
    variants,
    previousAyah: v.word == 0 && v.ayah > 1
        ? quran.ayah(v.surah, v.ayah - 1)
        : null,
  );

  // «لِإِخۡوَٰنِهُمُ ٱلَّذِينَ» (الحشر ١١): the ha damma told with the word whose
  // sakin it meets (the user, 2026-11-17).
  test('the ha damma before a sakin is told with the next word', () {
    final v = variants
        .at(['khalaf_hamzah'], 59, 11, 6)
        .singleWhere((v) => v.rule == 'ha_damir');
    final words = text(v).split(' ');
    expect(words, hasLength(2));
    expect(words.first, contains('هُمُ'));
    expect(words.last, startsWith('ٱل'));
    expect(
      variants
          .at(['khalaf_hamzah'], 59, 11, 6)
          .where((v) => !v.isUsul && v.count == 2),
      isEmpty,
    );
  });

  // «عَلَيۡهُمۡ غَيۡرِ» and «عَلَيۡهُمۡ وَلَا» (الفاتحة ٧): no sakin after, the
  // word alone (the user, 2026-11-18).
  test('the ha damma with no sakin after is told alone', () {
    for (final w in [3, 6]) {
      final v = variants
          .at(['khalaf_hamzah'], 1, 7, w)
          .singleWhere((v) => v.rule == 'ha_damir');
      expect(text(v), 'عَلَيۡهُمۡ');
    }
  });

  // «عَظِيمٞ ۝ وَمِنَ» (البقرة ٧-٨): Khalaf's idgham without ghunna across the
  // ayah's end, told with the waw doubled (the user, 2026-11-18).
  test('the idgham without ghunna at an ayah end takes the next ayah', () {
    final v = variants
        .at(['khalaf_hamzah'], 2, 7, 11)
        .singleWhere((v) => v.rule == 'idgham_bila_ghunna');
    expect(v.count, 1);
    final shown = usulReadingText(
      v,
      quran.ayah(2, 7),
      variants,
      nextAyah: quran.ayah(2, 8),
    );
    expect(shown.split(' ').last, startsWith('وّ'));
    expect(
      variants
          .at(['khallad'], 2, 7, 11)
          .where((v) => v.rule == 'idgham_bila_ghunna'),
      isEmpty,
    );
  });

  test('naql replaces the Hafs spelling, also in its other usul examples', () {
    for (final id in ['naql', 'badal', 'tarqiq']) {
      expect(text(rule(4, 9, id)), 'وَبِالَاخِرَةِ');
      expect(text(rule(4, 9, id)), isNot(contains('أ')));
    }
    expect(text(rule(10, 8, 'naql')), 'عَذَابٌ اَلِيمُۢ');
    expect(text(rule(14, 8, 'naql')), 'خَلَوِاْ اِلَىٰ');
    expect(text(rule(107, 0, 'naql')), 'قَدِيرٌ اَلَمۡ');
    expect(text(rule(49, 3, 'naql')), 'مِّنَ اٰلِ');
    expect(text(rule(53, 1, 'naql')), 'وَإِذَ اٰتَيۡنَا');
  });

  test(
    'long alif ibdal has madd in both-word examples, not a restored hamza',
    () {
      final v = variants
          .at(['warsh'], 22, 65, 16)
          .singleWhere((v) => v.rule == 'tasheel_pair');
      expect(hamzaPairMaddText(v, 'ان'), 'آن');
      expect(hamzaPairMaddText(v, 'آن'), 'آن');
      expect(hamzaPairMaddText(v, 'أَن'), isNull);
      expect(text(v), endsWith(' آن'));
      const short = Variant(
        riwayaId: 'warsh',
        surah: 2,
        ayah: 133,
        word: 17,
        count: 1,
        text: 'إِذ',
        kind: VariantKind.hamza,
        rule: 'tasheel_pair',
        usulWays: ['إبدال الهمزة الثانية ألفًا مع القصر (حركتان)'],
      );
      expect(hamzaPairMaddText(short, 'اذ'), isNull);
    },
  );

  test(
    'stopping taqlil examples retain spelling without an ordinary imala dot',
    () {
      for (final (a, w) in [(2, 5), (213, 32), (222, 5)]) {
        final v = rule(a, w, 'taqlil_stop');
        expect(v.isStoppingTaqlil, isTrue);
        expect(text(v), isNot(contains('۪')));
        expect(text(v), contains('ى'));
      }
    },
  );

  test('mim silah keeps each narrator’s written connection and madd', () {
    final warsh = variants.at(['warsh'], 2, 6, 4).single;
    final qunbul = variants.at(['qunbul'], 2, 6, 4).single;
    expect(text(warsh), 'عَلَيۡهِمُۥٓ');
    expect(text(qunbul), 'عَلَيۡهِمُۥ');
    expect(text(warsh), isNot(text(qunbul)));
  });

  test('ibdal, imala and sakt retain the actual source writing', () {
    expect(text(rule(3, 1, 'ibdal_single')), 'يُومِنُونَ');
    final imala = variants.at(['warsh'], 2, 7, 7).single;
    expect(text(imala), imala.text);
    final sakt = variants
        .at(['khalaf_hamzah'], 2, 4, 9)
        .firstWhere((v) => v.text.isNotEmpty);
    expect(text(sakt), contains('ۜ'));
    final unlinked = variants.at(['warsh'], 25, 69, 6).single;
    expect(text(unlinked), 'فِيهِ');
    expect(text(unlinked), isNot(contains('ۦ')));
  });

  test(
    'description-only silah shows its letter without changing the vowel',
    () {
      final empty = VariantRepository({});
      String example(String word, String description) {
        final a = Ayah(surah: 2, number: 1, page: 2, juz: 1, words: [word]);
        return usulReadingText(
          Variant(
            riwayaId: 'qunbul',
            surah: 2,
            ayah: 1,
            word: 0,
            count: 1,
            text: '',
            kind: VariantKind.usul,
            description: description,
          ),
          a,
          empty,
        );
      }

      expect(example('عَلَيْهِمْ', 'بصلة ميم الجمع'), 'عَلَيْهِمُۥ');
      expect(example('عَلَيْهِمُۥ', 'بصلة ميم الجمع'), 'عَلَيْهِمُۥ');
      expect(example('بِهِ', 'بصلة هاء الضمير'), 'بِهِۦ');
      expect(example('لَهُ', 'بصلة الهاء'), 'لَهُۥ');
      expect(example('فِيهِۦ', 'بترك صلة الهاء'), 'فِيهِ');
      expect(example('عَلَيْهِمْ', 'بلا صلة الميم'), 'عَلَيْهِمْ');
    },
  );
}
