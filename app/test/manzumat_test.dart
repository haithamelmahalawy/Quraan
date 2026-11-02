import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Manzumat manzumat;
  late List<String> surahs;
  late Kharouf book;
  setUpAll(() async {
    manzumat = await Manzumat.load();
    book = await Kharouf.load();
    surahs = [for (final s in (await QuranRepository.load()).surahs) s.nameAr];
  });

  Reference ref(
    String riwaya,
    int surah,
    String hafs, {
    String text = '',
    String description = '',
    String rule = '',
    VariantKind kind = VariantKind.farsh,
  }) => manzumat.referenceOf(
    Variant(
      riwayaId: riwaya,
      surah: surah,
      ayah: 1,
      word: 0,
      count: 1,
      text: text,
      kind: kind,
      description: description,
      rule: rule,
    ),
    hafs,
    surah,
    surahs,
  );

  test('an isri quotes bayt 765 of the book for Warsh', () {
    const v = Variant(
      riwayaId: 'warsh',
      surah: 20,
      ayah: 77,
      word: 4,
      count: 2,
      text: 'أَنِ اِ۪سْرِ',
      kind: VariantKind.farsh,
      description:
          'بوصل الهمزة، ويلزم منه كسر النون وصلاً، والابتداء بهمزة مكسورة',
      rule: '',
    );
    final r = manzumat.referenceOf(
      v,
      'أَنۡ أَسۡرِ',
      20,
      surahs,
      entries: book.at(20, 77, 4),
    );
    expect(r.fromBook, isTrue);
    expect(r.mention, {765});
  });

  test('fa-sri and an isri quote bayt 765, the bab of dhikran bayt 346', () {
    for (final (surah, ayah, word) in [
      (11, 81, 8),
      (15, 65, 0),
      (44, 23, 0),
      (26, 52, 3),
    ]) {
      final v = Variant(
        riwayaId: 'warsh',
        surah: surah,
        ayah: ayah,
        word: word,
        count: 1,
        text: 'فَاسْرِ',
        kind: VariantKind.farsh,
        description: 'بوصل الهمزة',
        rule: '',
      );
      final r = manzumat.referenceOf(
        v,
        'فَأَسۡرِ',
        surah,
        surahs,
        entries: book.at(surah, ayah, word),
      );
      expect(r.mention, {765}, reason: '$surah:$ayah');
    }
    final ra = ref(
      'warsh',
      20,
      'ذِكۡرٗا',
      description: 'بوجهين: تفخيم الراء وترقيقها',
      rule: 'tarqiq',
      kind: VariantKind.usul,
    );
    expect(ra.mention, {346});
  });

  test(
    'every araayta of the question is Warsh usul quoting bayt 638',
    () async {
      final quran = await QuranRepository.load();
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded(['warsh']);
      final question = RegExp('^أَ(فَ)?رَءَيۡت');
      var seen = 0;
      for (final surah in quran.surahs) {
        for (var a = 1; a <= surah.ayahCount; a++) {
          for (final (w, word) in quran.ayah(surah.number, a).words.indexed) {
            if (!question.hasMatch(word)) continue;
            seen++;
            final farsh = variants
                .at(['warsh'], surah.number, a, w)
                .singleWhere((v) => v.rule == 'tasheel_word');
            expect(farsh.isUsul, isTrue);
            expect(farsh.usulWays, hasLength(2));
            expect(
              farsh.description,
              contains('تسهيل الهمزة الثانية، أو إبدالها ألفًا'),
            );
            final r = manzumat.referenceOf(
              farsh,
              word,
              surah.number,
              surahs,
              entries: book.at(surah.number, a, w),
            );
            expect(r.mention, contains(638), reason: '${surah.number}:$a');
          }
        }
      }
      expect(seen, 34);
    },
  );

  test('yuha of al-Anbiya quotes bayt 783 for Warsh', () {
    for (final (ayah, word) in [(7, 5), (25, 7)]) {
      final v = Variant(
        riwayaId: 'warsh',
        surah: 21,
        ayah: ayah,
        word: word,
        count: 1,
        text: 'يُوح۪ىٰٓ',
        kind: VariantKind.farsh,
        description: 'بالياء وتقليل الحاء وإبدال الياء ألفًا مقصورة مع المد',
        rule: '',
      );
      expect(v.isUsul, isFalse);
      final r = manzumat.referenceOf(
        v,
        'نُوحِيٓ',
        21,
        surahs,
        entries: book.at(21, ayah, word),
      );
      expect(r.mention, contains(783), reason: '21:$ayah');
    }
  });

  test('wa-ana and fa-ana before hamza quote bayt 521 for Warsh', () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh']);
    for (final (surah, ayah, word) in [
      (6, 163, 5),
      (7, 143, 38),
      (40, 42, 10),
      (43, 81, 5),
      (60, 1, 35),
    ]) {
      final v = variants
          .at(['warsh'], surah, ayah, word)
          .singleWhere((r) => r.description == 'بالمد');
      final r = manzumat.referenceOf(
        v,
        quran.ayah(surah, ayah).words[word],
        surah,
        surahs,
        entries: book.at(surah, ayah, word),
      );
      expect(r.mention, {521}, reason: '$surah:$ayah');
    }
  });

  test('ana before hamza points to bayt 521 in Baqarah with book priority', () {
    for (final id in ['warsh', 'qalun']) {
      final v = Variant(
        riwayaId: id,
        surah: 2,
        ayah: 258,
        word: 20,
        count: 1,
        text: 'أَنَآ',
        kind: VariantKind.usul,
        description: 'بالمد',
      );
      final direct = manzumat.referenceOf(v, 'أَنَا۠', 2, surahs);
      expect(direct.mention, {521});
      expect(direct.chapter, 'سُوْرَةُ الْبَقَرَةِ');
      final cited = manzumat.referenceOf(
        v,
        'أَنَا۠',
        2,
        surahs,
        entries: book.at(2, 258, 20),
      );
      expect(cited.mention, {521});
      expect(cited.fromBook, isTrue);
      expect(
        cited.verses.singleWhere((b) => b.n == 521).sadr,
        contains('وَمَدُّ'),
      );
    }
  });

  test('the whole of both poems', () {
    expect(manzumat.verses(Poem.shatibiyya), hasLength(1173));
    expect(manzumat.verses(Poem.durrah).length, greaterThanOrEqualTo(240));
  });

  test('a farsh: the chapter of its surah, the verse naming the word', () {
    final r = ref('warsh', 2, 'يَخۡدَعُونَ', text: 'يُخَٰدِعُونَ');
    expect((r.poem, r.chapter), (Poem.shatibiyya, 'سُوْرَةُ الْبَقَرَةِ'));
    expect(r.mention, contains(445));
    expect(
      ref('hisham', 2, 'يَكۡذِبُونَ', text: 'يُكَذِّبُونَ').mention,
      contains(446),
    );
    // مَلِكِ (1:4): the Shatibiyya for the seven, the Durrah for Abu Ja'far.
    expect(ref('hisham', 1, 'مَٰلِكِ', text: 'مَلِكِ').mention, contains(108));
    final durrah = ref('ibn_wardan', 1, 'مَٰلِكِ', text: 'مَلِكِ');
    expect(durrah.poem, Poem.durrah);
    expect(durrah.mention, contains(10));
  });

  test('the usul: the chapter of the rule', () {
    String chapter(
      String riwaya, {
      String description = '',
      String rule = '',
    }) => ref(
      riwaya,
      2,
      'ءَامَنُواْ',
      description: description,
      rule: rule,
      kind: VariantKind.usul,
    ).chapter;
    expect(skeleton(chapter('warsh', rule: 'badal')), contains('لمد'));
    expect(
      skeleton(chapter('warsh', rule: 'ya_zaida')),
      contains(skeleton('الزوائد')),
    );
    expect(skeleton(chapter('warsh', rule: 'tarqiq')), contains('لرت'));
    expect(skeleton(chapter('warsh', rule: 'taghliz')), contains('للمت'));
    expect(skeleton(chapter('khalaf_hamzah', rule: 'sakt')), contains('نقل'));
    expect(
      skeleton(chapter('duri_kisai', description: 'بالإمالة')),
      contains('لمله'),
    );
  });

  test(
    'Ibn Dhakwan\'s imala of شاء and زاد cites «وَجَاءَ ابْنُ ذَكْوَانٍ»',
    () {
      Set<int> mention(String hafs) => ref(
        'ibn_dhakwan',
        2,
        hafs,
        description: 'بالإمالة',
        kind: VariantKind.usul,
      ).mention;
      expect(mention('شَآءَ'), {319});
      expect(mention('جَآءَهُمۡ'), {319});
      expect(mention('وَزَادَهُۥ'), {319, 320});
      expect(mention('عِمۡرَٰنَ'), {332, 333});
      expect(mention('ٱلۡإِكۡرَامِ'), {332, 333});
      expect(mention('حِمَارِكَ'), {332, 333});
    },
  );

  test(
    'Ibn Dhakwan\'s imala of التوراة cites «وَإِضْجَاعُكَ التَّوْرَاةَ»',
    () {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ibn_dhakwan',
          surah: 3,
          ayah: 3,
          word: 9,
          count: 1,
          text: 'ٱلتَّوۡر۪ىٰةَ',
          kind: VariantKind.usul,
          description: 'بالإمالة',
        ),
        'ٱلتَّوۡرَىٰةَ',
        3,
        surahs,
      );
      expect(r.mention, {546});
    },
  );

  test(
    'Ibn Amir قتلوا with the shadda cites «بِمَا قُتِلُوا التَّشْدِيدُ لَبَّى»',
    () {
      Set<int> mention(String id, int surah, int ayah, int word, String text) =>
          manzumat
              .referenceOf(
                Variant(
                  riwayaId: id,
                  surah: surah,
                  ayah: ayah,
                  word: word,
                  count: 1,
                  text: text,
                  kind: VariantKind.farsh,
                  description: 'بتشديد التاء',
                ),
                'قُتِلُواْ',
                surah,
                surahs,
              )
              .mention;
      expect(mention('hisham', 3, 168, 7, 'قُتِّلُواْ'), {576});
      expect(mention('ibn_dhakwan', 3, 169, 3, 'قُتِّلُواْ'), {576});
      expect(mention('hisham', 3, 195, 25, 'وَقُتِّلُواْ'), {576, 577});
      expect(mention('ibn_dhakwan', 22, 58, 6, 'قُتِّلُواْ'), {576});
    },
  );

  test('Ibn Amir وسيصلون cites «يَصْلَوْنَ ضُمَّ كَمْ صَفَا»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 4,
          ayah: 10,
          word: 11,
          count: 1,
          text: 'وَسَيُصۡلَوۡنَ',
          kind: VariantKind.farsh,
          description: 'بضم الياء',
        ),
        'وَسَيَصۡلَوۡنَ',
        4,
        surahs,
      );
      expect(r.mention, {588});
    }
  });

  test('al-Hajj and al-Naba are not taken for al-Hijr and al-Anbiya', () {
    String chapter(int surah) => manzumat
        .referenceOf(
          Variant(
            riwayaId: 'hisham',
            surah: surah,
            ayah: 1,
            word: 0,
            count: 1,
            text: '',
            kind: VariantKind.farsh,
          ),
          '',
          surah,
          surahs,
        )
        .chapter;
    expect(skeleton(chapter(22)), contains('لحج'));
    expect(skeleton(chapter(22)), isNot(contains('لحجر')));
    expect(skeleton(chapter(15)), contains('لحجر'));
    expect(skeleton(chapter(78)), contains('لنب'));
    expect(skeleton(chapter(21)), contains('لنبي'));
  });

  test('Hisham stopping on the hamza cites its own chapter', () {
    final r = manzumat.referenceOf(
      Variant(
        riwayaId: 'hisham',
        surah: 52,
        ayah: 24,
        word: 5,
        count: 1,
        text: '',
        kind: VariantKind.usul,
        description: 'وقفًا: إبدالها واوًا ساكنة، أو تسهيلها بالروم',
        rule: 'hisham_waqf',
        stopOnly: true,
      ),
      'لُؤۡلُؤٞ',
      52,
      surahs,
    );
    expect(skeleton(r.chapter), contains('وقف'));
    expect(r.mention, contains(236));
    expect(r.mention, isNot(contains(223)));
  });

  test('Ibn Dhakwan عيون، شيوخ، جيوب cite «يَكْسِرَانِ عُيُوناً»', () {
    for (final (surah, ayah, text, hafs, verses) in [
      (26, 57, 'وَعِيُونٖ', 'وَعُيُونٖ', {628}),
      (36, 34, 'ٱلۡعِيُونِ', 'ٱلۡعُيُونِ', {628}),
      (40, 67, 'شِيُوخٗا', 'شُيُوخٗا', {628}),
      (24, 31, 'جِيُوبِهِنَّ', 'جُيُوبِهِنَّۖ', {628, 629}),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ibn_dhakwan',
          surah: surah,
          ayah: ayah,
          word: 0,
          count: 1,
          text: text,
          kind: VariantKind.farsh,
          description: 'بكسر العين',
        ),
        hafs,
        surah,
        surahs,
      );
      expect(r.mention, verses, reason: '$surah:$ayah');
      expect(skeleton(r.chapter), contains('لمده'));
    }
  });

  test('Ibn Dhakwan رأى cites the farsh of al-An\'am', () {
    for (final (text, stop, verses) in [
      ('ر۪ء۪اهَا', false, {646, 647}),
      ('ر۪ء۪ا', false, {646}),
      ('ر۪ء۪ا', true, {648, 649}),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ibn_dhakwan',
          surah: 27,
          ayah: 10,
          word: 3,
          count: 1,
          text: text,
          kind: VariantKind.usul,
          description: 'بإمالة الراء والهمزة',
          stopOnly: stop,
        ),
        'رَءَاهَا',
        27,
        surahs,
      );
      expect(r.mention, verses, reason: '$text $stop');
    }
  });

  test('Ibn Amir يا أبت and فزع يومئذ cite their verses', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs, verse, chapter) in [
        (19, 42, 'يَٰٓأَبَتَ', 'يَٰٓأَبَتِ', 772, 'يوسف'),
        (28, 26, 'يَٰٓأَبَتَ', 'يَٰٓأَبَتِ', 772, 'يوسف'),
        (27, 89, 'فَزَعِ يَوۡمِئِذٍ', 'فَزَعٖ يَوۡمَئِذٍ', 761, 'هود'),
        (30, 54, 'ضُعۡفٗا', 'ضَعۡفٗا', 722, 'الأنفال'),
        (35, 9, 'مَّيۡتٖ', 'مَّيِّتٖ', 550, 'عمران'),
        (36, 68, 'نَنۡكُسۡهُ', 'نُنَكِّسۡهُ', 991, 'يس'),
        (37, 17, 'أَوۡ ءَابَآؤُنَا', 'أَوَءَابَآؤُنَا', 996, 'الصافات'),
        (37, 102, 'يَٰبُنَيِّ', 'يَٰبُنَيَّ', 757, 'هود'),
        (39, 7, 'يَرۡضَهۡ', 'يَرۡضَهُ', 164, 'الكناية'),
        (40, 26, 'وَأَن', 'أَوۡ أَن', 1010, 'المؤمن'),
        (44, 47, 'فَٱعۡتُلُوهُ', 'فَٱعۡتِلُوهُ', 1030, 'الدخان'),
        (40, 26, 'يَظۡهَرَ', 'يُظۡهِرَ', 1011, 'المؤمن'),
        if (id == 'ibn_dhakwan')
          (41, 51, 'وَنَآءَ', 'وَنَـَٔا', 826, 'الإسراء'),
        (48, 10, 'فَسَنُؤۡتِيهِ', 'فَسَيُؤۡتِيهِ', 1041, 'محمد'),
        (58, 21, 'وَرُسُلِىَ', 'وَرُسُلِيٓ', 402, 'ياءات الإضافة'),
        if (id == 'ibn_dhakwan')
          (98, 6, 'ٱلۡبَرِيٓـَٔةِ', 'ٱلۡبَرِيَّةِ', 1116, 'العلق'),
        (77, 6, 'نُذُرًا', 'نُذۡرًا', 618, 'المائدة'),
        if (id == 'hisham') ...[
          (76, 4, 'سَلَٰسِلًا', 'سَلَٰسِلَاْ', 1093, 'القيامة'),
          (76, 16, 'قَوَارِيرَا', 'قَوَارِيرَاْ', 1095, 'القيامة'),
        ],
        (75, 20, 'يُحِبُّونَ', 'تُحِبُّونَ', 1092, 'القيامة'),
        (75, 21, 'وَيَذَرُونَ', 'وَتَذَرُونَ', 1092, 'القيامة'),
        (73, 6, 'وِطَآءً', 'وَطۡـٔٗا', 1088, 'سورة ن'),
        (73, 9, 'رَبِّ', 'رَّبُّ', 1088, 'سورة ن'),
        (64, 17, 'يُضَعِّفۡهُ', 'يُضَٰعِفۡهُ', 516, 'البقرة'),
        (57, 11, 'فَيُضَعِّفَهُۥ', 'فَيُضَٰعِفَهُۥ', 516, 'البقرة'),
        (2, 245, 'فَيُضَعِّفَهُۥ', 'فَيُضَٰعِفَهُۥ', 516, 'البقرة'),
        (4, 40, 'يُضَعِّفۡهَا', 'يُضَٰعِفۡهَا', 516, 'البقرة'),
        (25, 69, 'يُضَعَّفُ', 'يُضَٰعَفۡ', 516, 'البقرة'),
        if (id == 'hisham')
          (52, 37, 'ٱلۡمُصَۜيۡطِرُونَ', 'ٱلۡمُصَۣيۡطِرُونَ', 1048, 'محمد'),
        (7, 172, 'ذُرِّيَّٰتِهِمۡ', 'ذُرِّيَّتَهُمۡ', 706, 'الأعراف'),
        (36, 41, 'ذُرِّيَّٰتِهِمۡ', 'ذُرِّيَّتَهُمۡ', 707, 'الأعراف'),
        (52, 21, 'ذُرِّيَّٰتُهُم', 'ذُرِّيَّتُهُم', 707, 'الأعراف'),
        (52, 21, 'ذُرِّيَّٰتِهِمۡ', 'ذُرِّيَّتَهُمۡ', 706, 'الأعراف'),
        if (id == 'ibn_dhakwan') ...[
          (48, 29, 'شَطَـَٔهُۥ', 'شَطۡـَٔهُۥ', 1043, 'محمد'),
          (48, 29, 'فَأَزَرَهُۥ', 'فَـَٔازَرَهُۥ', 1043, 'محمد'),
        ],
        if (id == 'ibn_dhakwan')
          (46, 19, 'وَلِنُوَفِّيَهُمْ', 'وَلِيُوَفِّيَهُمۡ', 1035, 'الأحقاف'),
        if (id == 'hisham')
          (46, 17, 'أَتَعِدَآنِّيٓ', 'أَتَعِدَانِنِيٓ', 1035, 'الأحقاف'),
        (31, 13, 'يَٰبُنَيِّ', 'يَٰبُنَيَّ', 757, 'هود'),
        (56, 48, 'أَوۡ ءَابَآؤُنَا', 'أَوَءَابَآؤُنَا', 996, 'الصافات'),
        (3, 27, 'ٱلۡمَيۡتِ', 'ٱلۡمَيِّتِ', 550, 'عمران'),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            description: text.contains('يۡت') ? 'بإسكان الياء مخففة' : '',
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, contains(verse), reason: '$id $surah:$ayah');
        expect(skeleton(r.chapter), contains(skeleton(chapter)));
      }
    }
  });

  test('Ibn Amir ندخله، نعذبه، نكفر cite «وَنُدْخِلْهُ نُونٌ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs) in [
        (4, 13, 'نُدْخِلۡهُ', 'يُدۡخِلۡهُ'),
        (4, 14, 'نُدْخِلۡهُ', 'يُدۡخِلۡهُ'),
        (48, 17, 'نُدْخِلْهُ', 'يُدۡخِلۡهُ'),
        (48, 17, 'نُعَذِّبْهُ', 'يُعَذِّبۡهُ'),
        (64, 9, 'نُكَفِّرْ', 'يُكَفِّرۡ'),
        (64, 9, 'وَنُدْخِلْهُ', 'وَيُدۡخِلۡهُ'),
        (65, 11, 'نُدۡخِلۡهُ', 'يُدۡخِلۡهُ'),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            description: 'بالنون',
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, {592}, reason: '$id $surah:$ayah $text');
        expect(skeleton(r.chapter), contains(skeleton('النساء')));
      }
    }
  });

  test('Ibn Amir without Hafs\'s sakt cites «وَالْبَاقُونَ لاَ سَكْتَ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs, kind, rule, verse) in [
        (18, 1, 'عِوَجٗا', 'عِوَجَاۜ', VariantKind.farsh, '', 830),
        (36, 52, 'مَّرۡقَدِنَا', 'مَّرۡقَدِنَاۜ', VariantKind.farsh, '', 831),
        (
          75,
          27,
          'مَن رَّاقٖ',
          'مَنۡۜ رَاقٖ',
          VariantKind.usul,
          'idgham_saghir',
          831,
        ),
        (
          83,
          14,
          'بَل رَّانَ',
          'بَلۡۜ رَانَ',
          VariantKind.usul,
          'idgham_saghir',
          831,
        ),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: kind,
            rule: rule,
            description: 'بإدغام',
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, {verse}, reason: '$id $surah:$ayah');
        expect(skeleton(r.chapter), contains(skeleton('الكهف')));
      }
    }
  });

  test('Ibn Amir «مُوصَدَةٌ» cites «وَمُؤْصَدَةٌ فَاهْمِزْ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah) in [(90, 20), (104, 8)]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 2,
            count: 1,
            text: 'مُوصَدَةٌ',
            kind: VariantKind.hamza,
            description: 'إبدال الهمزة واوًا ساكنة',
          ),
          'مُّؤۡصَدَةُۢ',
          surah,
          surahs,
        );
        expect(r.mention, {1114}, reason: '$id $surah:$ayah');
      }
    }
  });

  test(
    'Ruways «ٱللَّهُ» when starting (14:2) cites «وَطِبْ رَفْعَ أَللهِ»',
    () {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'ruways',
          surah: 14,
          ayah: 2,
          word: 0,
          count: 1,
          text: '',
          kind: VariantKind.farsh,
          description: 'بالرفع «ٱللَّهُ» ابتداءً، وبالخفض وصلاً كحفص',
        ),
        'ٱللَّهِ',
        14,
        surahs,
      );
      expect(r.mention, {138});
    },
  );

  test('Yaqub الرهب (28:32) cites the Shatibiyya, the Durrah being silent', () {
    for (final id in ['ruways', 'rawh']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 28,
          ayah: 32,
          word: 13,
          count: 1,
          text: 'الرَّهَبِ',
          kind: VariantKind.farsh,
          description: 'بفتح الراء والهاء',
        ),
        'ٱلرَّهۡبِ',
        28,
        surahs,
      );
      expect(r.poem, Poem.shatibiyya, reason: id);
      expect(r.mention, {947}, reason: id);
    }
  });

  test('Yaqub stopping on the kaf of ويكأن (28:82) cites the Durrah', () {
    for (final id in ['ruways', 'rawh']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 28,
          ayah: 82,
          word: 6,
          count: 1,
          text: '',
          kind: VariantKind.usul,
          description: 'بالوقف على الكاف',
          rule: 'rasm_stop',
        ),
        'وَيۡكَأَنَّ',
        28,
        surahs,
      );
      expect(r.mention, {51}, reason: id);
    }
  });

  test('Yaqub الظنون and her sisters cite the Shatibiyya (Abu Amr)', () {
    for (final (a, w) in [(10, 15), (66, 10), (67, 7)]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'rawh',
          surah: 33,
          ayah: a,
          word: w,
          count: 1,
          text: 'ٱلظُّنُونَ',
          kind: VariantKind.farsh,
          description: 'بحذف الألف وصلاً ووقفًا',
        ),
        'ٱلظُّنُونَا۠',
        33,
        surahs,
      );
      expect(r.poem, Poem.shatibiyya, reason: '33:$a');
      expect(r.mention, {969}, reason: '33:$a');
    }
  });

  test('Yaqub يصدقني (28:34) cites «وَيُصَدِّقْ فِه»', () {
    for (final id in ['ruways', 'rawh']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 28,
          ayah: 34,
          word: 9,
          count: 1,
          text: 'يُصَدِّقۡنِي',
          kind: VariantKind.farsh,
          description: 'بإسكان القاف',
        ),
        'يُصَدِّقُنِيٓۖ',
        28,
        surahs,
      );
      expect(r.mention, {176}, reason: id);
    }
  });

  test('Ibn Amir قل رب, لؤلؤ and سواء cite their verses', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (surah, ayah, text, hafs, verse) in [
        (21, 4, 'قُل رَّبِّي', 'قَالَ رَبِّي', 887),
        (21, 112, 'قُل رَّبِّ', 'قَٰلَ رَبِّ', 887),
        (22, 23, 'وَلُؤۡلُؤٖاْ', 'وَلُؤۡلُؤٗاۖ', 895),
        (35, 33, 'وَلُؤۡلُؤٖ', 'وَلُؤۡلُؤٗاۖ', 895),
        (22, 25, 'سَوَآءٌ', 'سَوَآءً', 895),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
          ),
          hafs,
          surah,
          surahs,
        );
        expect(r.mention, {verse}, reason: '$id $surah:$ayah');
      }
    }
  });

  test('Ibn Amir أشدد وأشركه cite «وَشَامٍ قَطْعُ أَشْدُدْ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      for (final (ayah, text, hafs, description) in [
        (31, 'أَشۡدُدۡ', 'ٱشۡدُدۡ', 'بهمزة قطع مفتوحة'),
        (32, 'وَأُشۡرِكۡهُ', 'وَأَشۡرِكۡهُ', 'بضم الهمزة'),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: id,
            surah: 20,
            ayah: ayah,
            word: 0,
            count: 1,
            text: text,
            kind: VariantKind.farsh,
            description: description,
          ),
          hafs,
          20,
          surahs,
        );
        expect(r.mention, {873}, reason: '$id $text');
      }
    }
  });

  test('Ibn Amir وأحل cites «وَضَمٌّ وَكَسْرٌ فِي أَحَلَّ صِحَابُهُ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 4,
          ayah: 24,
          word: 10,
          count: 1,
          text: 'وَأَحَلَّ',
          kind: VariantKind.farsh,
          description: 'بفتح الهمزة والحاء',
        ),
        'وَأُحِلَّ',
        4,
        surahs,
      );
      expect(r.mention, {597});
    }
  });

  test('Ibn Amir فتيلا انظر cites «وَضَمُّكَ أُولَى السَّاكِنَيْنِ»', () {
    Set<int> mention(String id, int ayah, int word, String hafs) => manzumat
        .referenceOf(
          Variant(
            riwayaId: id,
            surah: 4,
            ayah: ayah,
            word: word,
            count: 1,
            text: '',
            kind: VariantKind.farsh,
            description: 'بضم نون التنوين لالتقاء الساكنين',
          ),
          hafs,
          4,
          surahs,
        )
        .mention;
    expect(mention('hisham', 49, 13, 'فَتِيلًا'), {495, 496});
    expect(mention('hisham', 50, 0, 'ٱنظُرۡ'), {495, 496});
    expect(mention('ibn_dhakwan', 49, 13, 'فَتِيلًا'), {495, 497, 498});
    // «قَدِ اسْتُهْزِئَ» is named in the verse, with damma for both.
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 6,
          ayah: 10,
          word: 0,
          count: 1,
          text: 'وَلَقَدُ',
          kind: VariantKind.farsh,
          description: 'بضم الدال لالتقاء الساكنين',
        ),
        'وَلَقَدِ',
        6,
        surahs,
      );
      expect(r.mention, {495, 496}, reason: id);
    }
  });

  test(
    'Ibn Amir هزؤا cites «وَهُزْؤاً وَكُفْؤاً في السَّوَاكِنِ فُصِّلَا»',
    () {
      for (final (surah, ayah, word) in [
        (2, 67, 12),
        (5, 57, 8),
        (45, 35, 5),
      ]) {
        final r = manzumat.referenceOf(
          Variant(
            riwayaId: 'hisham',
            surah: surah,
            ayah: ayah,
            word: word,
            count: 1,
            text: 'هُزُؤٗا',
            kind: VariantKind.farsh,
            description: 'بإبدال الواو همزة',
          ),
          'هُزُوٗا',
          surah,
          surahs,
        );
        expect(r.mention, {460, 461}, reason: '$surah:$ayah');
      }
    },
  );

  test('Hisham أئنكم: two ways and «وَقَبْلَ الْكَسْرِ خُلْفٌ لَهُ»', () {
    Set<int> mention(int surah, int ayah, List<String> ways) => manzumat
        .referenceOf(
          Variant(
            riwayaId: 'hisham',
            surah: surah,
            ayah: ayah,
            word: 0,
            count: 1,
            text: 'أَٰئِنَّكُمۡ',
            kind: VariantKind.usul,
            description: ways.join('؛ '),
            rule: 'tasheel_word',
            usulText: 'أَئِنَّكُمۡ',
            usulWays: ways,
          ),
          'أَئِنَّكُمۡ',
          surah,
          surahs,
        )
        .mention;
    expect(
      mention(6, 19, [
        'تحقيق الهمزة الثانية مع الإدخال',
        'تحقيق الهمزة الثانية دون إدخال',
      ]),
      {196},
    );
    expect(mention(26, 41, ['تحقيق الهمزة الثانية مع الإدخال']), {
      196,
      197,
      198,
    });
  });

  test('Ibn Amir يس والقرآن cites «وَيَاسِيْنَ أَظْهِرْ»', () {
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: 36,
          ayah: 1,
          word: 0,
          count: 1,
          text: '',
          kind: VariantKind.usul,
          description: 'بإدغام النون من «يسٓ» في واو «وَٱلۡقُرۡءَانِ» بغنة',
          rule: 'idgham_saghir',
        ),
        'يسٓ',
        36,
        surahs,
      );
      expect(r.mention, {281}, reason: id);
    }
  });

  test(
    'ishmam cites «وَقِيلَ وَغِيضَ» or «وَحِيلَ… وَسِيءَ» in every surah',
    () {
      Set<int> mention(String id, int surah, int ayah, String hafs, String d) =>
          manzumat
              .referenceOf(
                Variant(
                  riwayaId: id,
                  surah: surah,
                  ayah: ayah,
                  word: 0,
                  count: 1,
                  text: '',
                  kind: VariantKind.usul,
                  description: d,
                  rule: 'ishmam',
                ),
                hafs,
                surah,
                surahs,
              )
              .mention;
      const qaf = 'بإشمام كسرة القاف ضمًّا', sin = 'بإشمام كسرة السين ضمًّا';
      expect(mention('hisham', 2, 11, 'قِيلَ', qaf), {447});
      expect(mention('hisham', 4, 61, 'قِيلَ', qaf), {447});
      expect(mention('hisham', 11, 44, 'وَغِيضَ', 'بإشمام كسرة الغين ضمًّا'), {
        447,
      });
      expect(mention('ibn_dhakwan', 39, 71, 'وَسِيقَ', sin), {448});
      expect(mention('ibn_dhakwan', 11, 77, 'سِيٓءَ', sin), {448});
    },
  );

  test('Ibn Amir أخذتم cites «فَازَ اتَخَذْتُمْ أَخَذْتُمْ»', () {
    for (final (id, s, a, text) in [
      ('hisham', 2, 51, 'ٱتَّخَذتُّمُ'),
      ('ibn_dhakwan', 3, 81, 'وَأَخَذتُّمۡ'),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: id,
          surah: s,
          ayah: a,
          word: 0,
          count: 1,
          text: text,
          kind: VariantKind.usul,
          description: 'بإدغام الذال في التاء',
          rule: 'idgham_saghir',
        ),
        text,
        s,
        surahs,
      );
      expect(r.mention, {283}, reason: id);
    }
  });

  test('Ibn Amir لي and معي cite «مَا كَانَ لِيْ اثْنَيْنِ مَعْ مَعِيْ»', () {
    for (final (s, a, text) in [
      (14, 22, 'لِى'),
      (38, 23, 'وَلِى'),
      (7, 105, 'مَعِى'),
    ]) {
      final r = manzumat.referenceOf(
        Variant(
          riwayaId: 'hisham',
          surah: s,
          ayah: a,
          word: 0,
          count: 1,
          text: text,
          kind: VariantKind.farsh,
          description: 'بإسكان الياء',
        ),
        text,
        s,
        surahs,
      );
      expect(r.mention, {417}, reason: '$s:$a');
    }
  });

  test('every جاء and شاء of Ibn Dhakwan, on its own word, cites bayt 319', () {
    final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync());
    final words = {
      for (final a in quran['ayahs'] as List)
        '${a[0]}:${a[1]}': (a[4] as String).split(' '),
    };
    final data = jsonDecode(
      File('assets/data/qiraat/ibn_dhakwan.json').readAsStringSync(),
    );
    var checked = 0;
    for (final v in data['variants'] as List) {
      final hafs = words['${v[0]}:${v[1]}']![v[2] as int];
      final bare = hafs.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '');
      if (!RegExp('^[وفل]?[شج][اآ]ء').hasMatch(bare)) continue;
      final reading = Variant(
        riwayaId: 'ibn_dhakwan',
        surah: v[0] as int,
        ayah: v[1] as int,
        word: v[2] as int,
        count: v[3] as int,
        text: v[4] as String,
        kind: VariantKind.fromCode(v[5] as String),
        description: v[6] as String,
      );
      if (!reading.isImala) continue;
      expect(reading.count, 1, reason: '${v[0]}:${v[1]}:${v[2]}');
      expect(
        manzumat.referenceOf(reading, hafs, reading.surah, surahs).mention,
        {319},
        reason: '${v[0]}:${v[1]}:${v[2]} $hafs',
      );
      checked++;
    }
    expect(checked, greaterThan(200));
  });

  test('Hisham\'s أؤنبئكم cites «وَفي آلِ عِمْرَانَ رَووْا لِهِشَامِهِمْ»', () {
    final r = manzumat.referenceOf(
      Variant(
        riwayaId: 'hisham',
        surah: 3,
        ayah: 15,
        word: 1,
        count: 1,
        text: 'أَٰؤُنَبِّئُكُم',
        kind: VariantKind.usul,
        description:
            'بوجهين: تحقيق الهمزة الثانية مع الإدخال؛ أو تحقيقها دون إدخال',
        rule: 'tasheel_word',
        usulText: 'أَؤُنَبِّئُكُم',
      ),
      'أَؤُنَبِّئُكُم',
      3,
      surahs,
    );
    expect(r.mention, {200, 201});
  });

  Variant reading({
    String rule = 'naql',
    int ayah = 4,
    int word = 9,
    VariantKind kind = VariantKind.usul,
  }) => Variant(
    riwayaId: 'warsh',
    surah: 2,
    ayah: ayah,
    word: word,
    count: 1,
    text: '',
    kind: kind,
    rule: rule,
  );

  test('book citations take priority and stay within the selected rule', () {
    final v = reading();
    final r = manzumat.referenceOf(
      v,
      'بالآخرة',
      2,
      surahs,
      entries: book.at(2, 4, 9),
    );
    expect(r.fromBook, isTrue);
    expect(r.mention, {226});
    expect(r.bookExplanation[226], contains('بنقل حركة الهمزة'));
    // The same note quotes madd al-badal and Hamzah's sakt as well.
    // They belong to the other rules, rather than this naql selection.
    final badal = manzumat.referenceOf(
      reading(rule: 'badal'),
      'بالآخرة',
      2,
      surahs,
      entries: book.at(2, 4, 9),
    );
    expect(badal.mention, {171, 172});
    expect(badal.fromBook, isTrue);
  });

  test('quotations spanning bayts retain both and exclude the other poem', () {
    expect(
      manzumat.quotedVerses(
        Poem.shatibiyya,
        'وما بعد همز ثابت أو مغير، فقصر وقد يروى لورش مطولا، '
        'ووسطه قوم كآمن هؤلاء، ءآلهة آتى للإيمان مثلا',
      ),
      {171, 172},
    );
    expect(manzumat.quotedVerses(Poem.shatibiyya, 'يخدعون اعلم حجى'), isEmpty);
    expect(manzumat.quotedVerses(Poem.durrah, 'يخدعون اعلم حجى'), contains(62));
    expect(manzumat.quotedVerses(Poem.shatibiyya, 'الله'), isEmpty);
  });

  test(
    'two-word hamza rules select that chapter rather than one-word hamzas',
    () {
      for (final rule in ['tasheel_pair', 'ibdal_waw', 'ibdal_ya']) {
        final r = ref(
          'warsh',
          2,
          'السفهاء ألا',
          rule: rule,
          kind: VariantKind.usul,
        );
        expect(skeleton(r.chapter), contains(skeleton('كلمتين')));
        expect(r.mention, isNotEmpty);
        expect(r.mention.every((n) => n >= 202 && n <= 213), isTrue);
      }
      expect(
        ref(
          'warsh',
          2,
          'ءأنذرتهم',
          rule: 'tasheel_word',
          kind: VariantKind.usul,
        ).mention,
        {183, 184},
      );
    },
  );

  test('unknown words and common prose are never a whole-chapter proof', () {
    expect(ref('warsh', 2, 'كلمةغيرموجودة').mention, isEmpty);
    expect(ref('warsh', 2, 'الله الذين').mention, isEmpty);
  });

  test(
    'every Shatibiyya bayt has sourced commentary, including shared passages',
    () {
      for (final b in manzumat.verses(Poem.shatibiyya)) {
        final e = manzumat.explanation(Poem.shatibiyya, b.n);
        expect(e, isNotNull, reason: 'Bayt ${b.n}');
        expect(e!.text.length, greaterThan(20));
        expect(e.source, contains('أبو شامة'));
        expect(e.url, startsWith('https://'));
        expect(e.group, contains(b.n));
      }
      expect(
        manzumat.explanation(Poem.shatibiyya, 183)!.text,
        isNot(manzumat.explanation(Poem.shatibiyya, 226)!.text),
      );
      expect(manzumat.explanation(Poem.durrah, 183), isNull);
    },
  );
}
