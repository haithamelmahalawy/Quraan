import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/usul_guide.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/ui/poem_verse.dart';
import 'package:qiraat_mushaf/ui/usul_guide_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  late Manzumat manzumat;

  setUpAll(() async {
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    manzumat = await Manzumat.load();
    // Cached for the file: loaded here, not within one test's fake clock.
    await Kharouf.load();
    await variants.ensureLoaded([
      for (final q in qiraat)
        for (final r in q.riwayat) r.id,
    ]);
  });

  test('«اتخذتم، أخذتم» is one idgham on its word, for all who merge it', () {
    final sites = <(int, int, int)>{
      for (var p = 1; p <= quran.pageCount; p++)
        for (final a in quran.page(p))
          for (final (w, word) in a.words.indexed)
            if (word.contains('خَذۡت')) (a.surah, a.number, w),
    }.toList();
    expect(sites, hasLength(18));
    for (final id in [
      'shubah',
      'qalun',
      'ibn_wardan',
      'ibn_jammaz',
      'warsh',
      'hisham',
      'ibn_dhakwan',
      'rawh',
    ]) {
      for (final (s, a, w) in sites) {
        final told = [
          for (final v in variants.at([id], s, a, w))
            if (v.description.contains('إدغام الذال')) v,
        ];
        expect(told, hasLength(1), reason: '$id $s:$a:$w');
        // Told of its word alone (not «قل أتخذتم»), in the usul.
        expect(told.single.word, w, reason: '$id $s:$a:$w');
        expect(told.single.count, 1, reason: '$id $s:$a:$w');
        expect(told.single.rule, 'idgham_saghir', reason: '$id $s:$a:$w');
        expect(told.single.kind, VariantKind.usul, reason: '$id $s:$a:$w');
      }
    }
    // Ibn Kathir, Hafs and Ruways with izhar, as Hafs.
    for (final id in ['bazzi', 'qunbul', 'ruways']) {
      for (final (s, a, w) in sites) {
        expect(
          variants
              .at([id], s, a, w)
              .where((v) => v.description.contains('إدغام الذال')),
          isEmpty,
          reason: '$id $s:$a:$w',
        );
      }
    }
  });

  test('«فيغرقكم» has two faces for Ibn Wardan, one for Ibn Jammaz', () {
    List<Variant> farsh(String id) => [
      for (final v in variants.at([id], 17, 69, 12))
        if (v.kind == VariantKind.farsh) v,
    ];
    final wardan = farsh('ibn_wardan').single;
    expect(wardan.usulWays, [
      'إسكان الغين وتخفيف الراء، وهو المقدّم',
      'فتح الغين وتشديد الراء',
    ]);
    expect(wardan.description, startsWith('بالتاء وبوجهين:'));
    expect(
      farsh('ibn_jammaz').single.description,
      'بالتاء وإسكان الغين وتخفيف الراء',
    );
  });

  test('«سيئه» (الإسراء ٣٨) is worded alike by the verified readers', () {
    for (final id in ['qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ruways']) {
      final v = variants
          .at([id], 17, 38, 3)
          .singleWhere((v) => v.kind == VariantKind.farsh);
      expect(v.description, 'بفتح الهمزة وبعدها تاء منونة بالفتح', reason: id);
    }
  });

  test('every rule of every riwaya has its own explanation', () {
    final other = usulDefinition('أصول أخرى');
    for (final q in qiraat) {
      for (final r in q.riwayat) {
        for (final label in usulOfRiwaya(variants, quran, r.id).keys) {
          if (label == 'أصول أخرى') continue;
          expect(usulDefinition(label), isNot(other), reason: label);
        }
      }
    }
  });

  test('the rules taught in a chapter find it in both poems', () {
    for (final label in [
      'مد البدل',
      'النقل',
      'الإمالة',
      'إبدال الهمز',
      'الهمزتان من كلمتين',
      'الهمزتان المفتوحتان في كلمة',
      'ياءات الزوائد',
      'صلة هاء الضمير',
    ]) {
      for (final poem in Poem.values) {
        expect(
          usulChapterVerses(manzumat, poem, label),
          isNotEmpty,
          reason: '$label ${poem.nameAr}',
        );
      }
    }
  });

  test('the main chapters are divided into their kinds', () {
    Set<String> kinds(String label) => {
      for (final v in usulOfRiwaya(variants, quran, 'warsh')[label]!)
        usulKindOf(
          label,
          v,
          quran.ayah(v.surah, v.ayah).words[v.word],
          changedHamza: variants
              .at(['warsh'], v.surah, v.ayah, v.word)
              .any((o) => o.rule == 'naql'),
          lastOfAyah: v.word == quran.ayah(v.surah, v.ayah).words.length - 1,
        ),
    };
    expect(kinds('مد البدل'), isNot(contains('صور أخرى')));
    expect(
      kinds('مد البدل'),
      containsAll([
        'حرف المد الألف بعد همز ثابت',
        'حرف المد الواو بعد همز ثابت',
        'حرف المد الياء بعد همز ثابت',
        'حرف المد الألف بعد همز مغيَّر بالنقل',
      ]),
    );
    expect(
      kinds('النقل'),
      containsAll([
        'إلى لام التعريف',
        'إلى التنوين قبلها',
        'إلى الحرف الساكن آخر الكلمة قبلها',
      ]),
    );
    expect(
      kinds('تغليظ اللام'),
      containsAll(['بعد الصاد المفتوحة', 'بعد الطاء المفتوحة']),
    );
    expect(kinds('ترقيق الراء'), {
      'بعد ياء ساكنة أو مدية',
      'بعد كسرة لازمة',
      'بعد كسرة بينهما ساكن',
      'المستثنى',
    });
    final tarqiq = usulOfRiwaya(variants, quran, 'warsh')['ترقيق الراء']!;
    String tarqiqKind(Variant v) =>
        usulKindOf('ترقيق الراء', v, quran.ayah(v.surah, v.ayah).words[v.word]);
    expect(
      tarqiq.where((v) => tarqiqKind(v) == 'بعد كسرة لازمة'),
      hasLength(832),
    );
    expect(tarqiq.singleWhere((v) => tarqiqKind(v) == 'المستثنى').surah, 77);
    expect(
      kinds('التقليل'),
      containsAll([
        'ذوات الراء',
        'الألف قبل راء مكسورة',
        'رؤوس الآي',
        'عند الوقف فقط',
      ]),
    );
    expect(
      kinds('مد اللين المهموز'),
      containsAll(['اللين بالياء', 'اللين بالواو']),
    );
    final lin = usulOfRiwaya(variants, quran, 'warsh');
    expect(lin.keys.where((l) => l.contains('اللين')), ['مد اللين المهموز']);
    expect(lin['مد اللين المهموز'], hasLength(304));
    expect(
      kinds('مد اللين المهموز').where((k) => k.startsWith('مع مد البدل: ')),
      hasLength(1),
    );
    expect(
      kinds('مد اللين المهموز'),
      contains('المستثنى: القصر حركتان فقط وصلًا ووقفًا'),
    );
    expect(usulGuideLabel('مد اللين المهموز (مستثنى)'), 'مد اللين المهموز');
    expect(usulGuideLabel('الهمزتان من كلمة (المفتوحتان)'), 'الهمزتان من كلمة');
    expect(usulGuideLabel('الهمزتان من كلمتين'), 'الهمزتان من كلمتين');
    expect(lin.keys, isNot(contains('الهمزتان المفتوحتان في كلمة')));
    expect(lin.keys, isNot(contains('تسهيل الهمزتين في كلمة')));
    expect(lin.keys, isNot(contains('همزة الاستفهام مع همزة الوصل')));
    expect(lin.keys, isNot(contains('مد الفرق')));
    expect(lin.keys, isNot(contains('همزة هأنتم')));
    expect(usulGuideLabel('الهمزتان من كلمة (مد الفرق)'), 'الهمزتان من كلمة');
    // 19 + 2 + 36 + 34 words, and the 10 of مد الفرق.
    expect(lin['الهمزتان من كلمة'], hasLength(101));
    expect(usulGuideLabel('الهمز المفرد (الهمز المتحرك)'), 'الهمز المفرد');
    // هأنتم 4, the ibdal of the single hamza 986, مِنسَاتَهُۥ; the 80 of
    // «ٱلنَّبِيٓءُ» and its bab, the 12 of «هُزُؤًا، كُفُؤًا» and the 3 of
    // «وَٱلصَّٰبِـِٔينَ».
    expect(lin['الهمز المفرد'], hasLength(1086));
    expect(
      kinds('الهمز المفرد')
          .where((k) => !k.startsWith('همز «ائتنا» ابتداءً: ')),
      unorderedEquals([
        'الهمز المتحرك',
        'الإبدال واوًا',
        'الإبدال ألفًا',
        'الإبدال ياءً',
        'زيادة الهمزة',
        'حذف الهمزة',
      ]),
    );
    expect(
      lin['الهمز المفرد']!.where(
        (v) => usulKindOf(
          'الهمز المفرد',
          v,
          quran.ayah(v.surah, v.ayah).words[v.word],
        ).startsWith('همز «ائتنا» ابتداءً: '),
      ),
      hasLength(16),
    );
    expect(lin.keys, isNot(contains('إبدال الهمز')));
    expect(lin.keys, isNot(contains('الهمزات')));
    // Its 95 and the 29 of the second hamza changed; تشاء أنت is told once.
    expect(lin['الهمزتان من كلمتين'], hasLength(124));
    expect(kinds('الهمز المفرد').where((k) => k.contains('  ')), isEmpty);
    // With the 18 of «اتخذتم، أخذتم» (إدغام الذال في التاء).
    expect(lin['الإدغام'], hasLength(39));
    expect(lin['ترك السكت'], hasLength(3));
    expect(lin['النقل'], hasLength(3541));
    expect(lin['مد أنا'], hasLength(12));
    expect(lin.keys, isNot(contains('المدود')));
    expect(lin['المد المنفصل']!.single.surah, 98);
    expect(lin['المد المنفصل']!.single.description, 'بالمد');
    final two = kinds('الهمزتان من كلمة');
    expect(
      two.where((k) => k.startsWith('المفتوحتان قبل ساكن: ')),
      hasLength(1),
    );
    expect(
      two.where((k) => k.startsWith('المفتوحتان قبل متحرك: ')),
      hasLength(1),
    );
    expect(two.where((k) => k.startsWith('أرأيت: ')), hasLength(3));
    int count(String prefix) => lin['الهمزتان من كلمة']!
        .where((v) => twoHamzasKind(v) == prefix)
        .length;
    expect(count('المفتوحة والمكسورة'), 32);
    expect(count('المفتوحة والمضمومة'), 4);
    expect(count('المفتوحتان'), 21);
    expect(count('أرأيت'), 34);
    expect(count('مد الفرق'), 10);
    final farq = two
        .where((k) => k.startsWith('مد الفرق'))
        .map((k) => k.split(':').first)
        .toSet();
    expect(farq, {
      'مد الفرق (ءالذكرين)',
      'مد الفرق (ءالله)',
      'مد الفرق (ءالآن)',
      'مد الفرق (ءامنتم)',
      'مد الفرق (ءألهتنا)',
    });
  });

  test('the verified readers share the chapters of the hamzas', () {
    for (final id in ['hisham', 'ibn_dhakwan', 'ruways', 'rawh', 'shubah']) {
      final usul = usulOfRiwaya(variants, quran, id);
      for (final old in [
        'الهمزتان المفتوحتان في كلمة',
        'الهمزتان في كلمة',
        'تسهيل الهمزتين في كلمة',
        'الهمزتان المفتوحة والمكسورة في كلمة',
        'الهمزتان المفتوحة والمضمومة في كلمة',
        'إبدال الهمز',
        'تحقيق الهمز',
      ]) {
        expect(usul.keys, isNot(contains(old)), reason: '$id $old');
      }
    }
    final lin = usulOfRiwaya(variants, quran, 'warsh');
    final pairs = lin['الهمزتان من كلمتين']!;
    int pair(String kind) => pairs.where((v) => twoWordsKind(v) == kind).length;
    expect(pair('مفتوحتان'), 29);
    expect(pair('مكسورتان'), 17);
    expect(pair('مضمومتان'), 1);
    expect(pair('مضمومة فمكسورة'), 28);
    expect(pair('مفتوحة فمكسورة'), 19);
    expect(pair('مكسورة فمفتوحة'), 16);
    expect(pair('مضمومة فمفتوحة'), 13);
    expect(pair('مفتوحة فمضمومة'), 1);
    expect(
      usulGuideLabel('الهمزتان من كلمتين (مفتوحتان)'),
      'الهمزتان من كلمتين',
    );
    expect(usulKindRank('الهمزتان من كلمة', 'المفتوحتان'), 0);
    expect(usulKindRank('الهمزتان من كلمة', 'مد الفرق'), 4);
    expect(
      usulKindReason(
        'الهمز المفرد',
        lin['الهمز المفرد']!.first,
        'الإبدال واوًا',
      ),
      contains('الضمة'),
    );
    final ruwaysUsul = usulOfRiwaya(variants, quran, 'ruways');
    expect(ruwaysUsul.keys, isNot(contains('إشمام الصاد')));
    String ishmamKind(Variant v) =>
        usulKindOf('الإشمام', v, quran.ayah(v.surah, v.ayah).words[v.word]);
    expect(
      ruwaysUsul['الإشمام']!.where(
        (v) => ishmamKind(v).startsWith('إشمام حرف بحرف: '),
      ),
      hasLength(12),
    );
    expect(
      ruwaysUsul['الإشمام']!.where(
        (v) => ishmamKind(v).startsWith('إشمام حركة بحركة: '),
      ),
      hasLength(57),
    );
    expect(
      usulOfRiwaya(variants, quran, 'hisham').keys,
      contains('الوقف على الهمز'),
    );
    final hisham = usulOfRiwaya(variants, quran, 'hisham')['الهمزتان من كلمة']!;
    expect(hisham, hasLength(52));
    expect(
      usulOfRiwaya(variants, quran, 'ibn_dhakwan')['الهمزتان من كلمة'],
      hasLength(4),
    );
    // ءامنتم: for Ibn Amir its farsh and its usul together; Rawh and Shu'bah
    // its farsh alone.
    for (final id in ['hisham', 'ibn_dhakwan']) {
      final at = variants.at([id], 7, 123, 2);
      expect(at.where((v) => v.isUsul), hasLength(1), reason: id);
      expect(at.where((v) => !v.isUsul), hasLength(1), reason: id);
      expect(twoHamzasKind(at.singleWhere((v) => v.isUsul)), 'مد الفرق');
    }
    for (final id in ['rawh', 'shubah']) {
      expect(variants.at([id], 7, 123, 2).where((v) => v.isUsul), isEmpty);
    }
    final warsh = usulOfRiwaya(variants, quran, 'warsh')['الهمزتان من كلمة']!;
    bool sameWord(Variant v) => v.surah == 2 && v.ayah == 6 && v.word == 5;
    expect(
      twoHamzasKind(hisham.singleWhere(sameWord)),
      twoHamzasKind(warsh.singleWhere(sameWord)),
    );
    final ruways = usulOfRiwaya(variants, quran, 'ruways')['الهمزتان من كلمة']!;
    int ruwaysKind(String kind) =>
        ruways.where((v) => twoHamzasKind(v) == kind).length;
    expect(
      twoHamzasKind(ruways.singleWhere((v) => v.surah == 3 && v.ayah == 15)),
      'المفتوحة والمضمومة',
    );
    expect(ruwaysKind('المفتوحة والمكسورة'), greaterThan(0));
    expect(ruwaysKind('المفتوحتان'), greaterThan(0));
    expect(
      usulOfRiwaya(variants, quran, 'ruways')['الهمزتان من كلمتين'],
      hasLength(115),
    );
    expect(
      usulOfRiwaya(variants, quran, 'susi').keys,
      isNot(contains('الهمز المفرد')),
    );
  });

  test('Qalun, Ibn Kathir and Abu Jafar follow «أصول أصحاب الصلة»', () {
    Variant? rowOf(String id, int s, int a, int w, String rule) =>
        variants.at([id], s, a, w).where((v) => v.rule == rule).firstOrNull;
    final qalun = usulOfRiwaya(variants, quran, 'qalun');
    expect(qalun['صلة ميم الجمع']!.length, greaterThan(6000));
    final mim = variants
        .at(['qalun'], 1, 7, 3)
        .singleWhere((v) => v.description == 'بصلة ميم الجمع');
    expect(mim.usulWays, isEmpty);
    expect(mim.text, contains('مُۥ'));
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final usul = usulOfRiwaya(variants, quran, id);
      expect(usul['صلة ميم الجمع']!.length, greaterThan(5000), reason: id);
      expect(usul['الإخفاء'], isNotEmpty, reason: id);
      expect(
        rowOf(id, 2, 3, 1, 'ibdal_single')!.text,
        contains('يُو'),
        reason: id,
      );
    }
    // أئمة: the book, the file; not the old ibdal.
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      expect(rowOf(id, 9, 12, 10, 'tasheel_word')!.usulWays, [
        'تسهيل الهمزة الثانية بلا إدخال',
      ], reason: id);
    }
    expect(rowOf('ibn_wardan', 9, 12, 10, 'tasheel_word')!.usulWays, [
      'تسهيل الهمزة الثانية مع الإدخال',
    ]);
    // هار: Qalun's greater imala, not Warsh's taqlil.
    final har = variants.at(['qalun'], 9, 109, 16).single;
    expect(har.description, 'بالإمالة الكبرى');
    expect(usulOfRiwaya(variants, quran, 'qalun').keys, contains('الإمالة'));
    // The chapters new to them.
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      expect(rowOf(id, 19, 1, 0, 'fawatih')!.usulWays, ['التوسط', 'الإشباع']);
    }
    expect(
      usulOfRiwaya(variants, quran, 'bazzi')['تاءات البزي'],
      hasLength(30),
    );
    expect(rowOf('bazzi', 92, 14, 2, 'bazzi_ta')!.text, startsWith('تّ'));
    // What «الجامع» told that the earlier sources missed.
    for (final id in ['bazzi', 'qunbul']) {
      final ha = rowOf(id, 13, 7, 14, 'rasm_stop')!;
      expect(ha.stopOnly, isTrue, reason: id);
      expect(ha.stopText, endsWith('ي'), reason: id);
      expect(rowOf(id, 3, 35, 2, 'rasm_stop')!.stopOnly, isTrue, reason: id);
    }
    expect(usulOfRiwaya(variants, quran, 'qalun')['مد أنا'], hasLength(15));
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      expect(usulOfRiwaya(variants, quran, id)['مد أنا'], hasLength(12));
      expect(
        rowOf(id, 9, 44, 1, 'ibdal_single')!.text,
        contains('يَسۡتَاذِنُكَ'),
        reason: id,
      );
      expect(
        variants.at([id], 18, 51, 1).single.text,
        contains('أَشۡهَدۡنَٰهُمُ'),
      );
    }
    expect(variants.at(['qunbul'], 75, 1, 0).single.text, 'لَأُقۡسِمُ');
    // The stop signs of the Hafs page on every reader's word, one text.
    expect({
      for (final id in ['qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz'])
        variants.at([id], 2, 5, 4).single.text,
    }, hasLength(1));
    expect(variants.at(['bazzi'], 2, 5, 4).single.text, endsWith('ۖ'));
    // The separated madd short: no sign on the silah before a hamza.
    for (final id in ['qalun', 'ibn_wardan']) {
      expect(variants.at([id], 2, 13, 2).single.text, 'لَهُمُۥ', reason: id);
    }
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      // «السفهاء ألا»: one text with Qalun's and Ibn Kathir's, one row.
      expect(
        variants.at([id], 2, 13, 12).single.text,
        variants.at(['qalun'], 2, 13, 12).single.text,
        reason: id,
      );
      // «فلا خوف عليهم»: the ha read with kasra as Hafs, no farsh; the silah.
      expect(
        variants.at([id], 2, 38, 13).where((v) => v.kind == VariantKind.farsh),
        isEmpty,
      );
      expect(variants.at([id], 2, 38, 13).single.text, 'عَلَيۡهِمُۥ');
      // As Hafs reads them: no farsh.
      for (final (s, a, w) in [(7, 143, 8), (20, 87, 6), (43, 4, 1)]) {
        expect(
          variants.at([id], s, a, w).where((v) => v.kind == VariantKind.farsh),
          isEmpty,
          reason: '$id $s:$a',
        );
      }
      // Told on their own words.
      expect(variants.at([id], 18, 44, 8).single.text, 'عُقُبٗا');
      expect(variants.at([id], 19, 70, 7).single.text, 'صُلِيّٗا');
      expect(variants.at([id], 15, 45, 4).single.rule, 'first_sakin');
    }
    // «التقاء الساكنين»: the letters and the tanween with a damma for those
    // who read so, one rule for them all; Ibn Dhakwan's tanween as Hafs but
    // for برحمة and خبيثة; Asim's (Hafs's, Shu'bah's) kasra not told.
    int sakinin(String id) => [
      for (final s in quran.surahs)
        for (var a = 1; a <= s.ayahCount; a++)
          for (var w = 0; w < quran.ayah(s.number, a).words.length; w++)
            ...variants
                .at([id], s.number, a, w)
                .where((v) => v.word == w && v.rule == 'first_sakin'),
    ].length;
    for (final id in [
      'warsh',
      'qalun',
      'bazzi',
      'qunbul',
      'hisham',
      'ibn_wardan',
      'ibn_jammaz',
    ]) {
      expect(sakinin(id), 40, reason: id);
      expect(
        variants.at([id], 17, 20, 11).single.description,
        'بضم نون التنوين وصلاً لالتقاء الساكنين',
        reason: id,
      );
      expect(
        variants
            .at([id], 7, 195, 19)
            .singleWhere((v) => v.rule == 'first_sakin')
            .text,
        'قُلُ',
        reason: id,
      );
      expect(
        variants.at([id], 59, 16, 4).where((v) => v.rule == 'first_sakin'),
        isEmpty,
      );
    }
    expect(sakinin('ibn_dhakwan'), 30);
    expect(variants.at(['ibn_dhakwan'], 17, 20, 11), isEmpty);
    expect(
      variants.at(['ibn_dhakwan'], 7, 49, 6).single.usulWays,
      hasLength(2),
    );
    expect(sakinin('shubah'), 0);
    // Abu Ja'far's farsh read as Qalun's, told with the word after it in
    // his source: as Qalun's, one reading; a word after with its own vowel
    // (لعنةَ) still told with it.
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      final aj = variants.at([id], 2, 58, 15).single;
      final qalun = variants.at(['qalun'], 2, 58, 15).single;
      expect((aj.count, aj.text), (qalun.count, qalun.text));
      expect(
        compareReadings(
          repository: variants,
          ayah: quran.ayah(2, 58),
          word: 15,
          displayed: 'qalun',
          selected: {id},
        ),
        isEmpty,
        reason: id,
      );
      expect(variants.at([id], 7, 44, 23).single.count, 2);
    }
    // Abu Ja'far's farsh once told in it (يَبْطُشُونَ) back in the farsh.
    expect(
      variants.at(['ibn_wardan'], 7, 195, 7).single.kind,
      VariantKind.farsh,
    );
    expect(
      variants.at(['ibn_wardan'], 2, 173, 13).single.text,
      allOf(contains('طِ'), startsWith('ٱضۡ')),
    );
    // Shu'bah leaves Hafs's sakt as Warsh does: in the usul, not the farsh.
    for (final (s, a, w) in [(36, 52, 5), (75, 27, 1), (83, 14, 1)]) {
      bool own(Variant v) => v.rule != 'kharouf';
      final v = variants.at(['shubah'], s, a, w).singleWhere(own);
      expect(v.rule, 'no_sakt', reason: '$s:$a');
      expect(v.isUsul, isTrue, reason: '$s:$a');
      expect(
        v.description,
        variants.at(['warsh'], s, a, w).singleWhere(own).description,
      );
    }
    expect(variants.at(['shubah'], 83, 14, 2).single.isImala, isTrue);
    expect(
      variants.at(['shubah'], 18, 1, 10).map((v) => v.kind),
      contains(VariantKind.farsh),
    );
    // Abu Ja'far's two hamzas of a word written as Qalun's: one row.
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      expect(
        variants.at([id], 2, 6, 5).single.text,
        variants.at(['qalun'], 2, 6, 5).single.text,
        reason: id,
      );
    }
    expect(variants.at(['qalun'], 2, 6, 5).single.text, contains('ٰا۬'));
    expect(rowOf('bazzi', 93, 11, 3, 'takbir'), isNotNull);
    expect(rowOf('qunbul', 93, 11, 3, 'takbir'), isNull);
    expect(
      rowOf('qalun', 4, 5, 2, 'tasheel_pair_first')!.usulWays.first,
      contains('إسقاط الهمزة الأولى'),
    );
    // Their farsh keeps its rows.
    expect(variants.at(['qalun'], 2, 6, 5).single.usulWays, [
      'تسهيل الهمزة الثانية مع الإدخال',
    ]);
  });

  test('each difference of the Ashab al-Silah stands in its chapter', () {
    Variant only(String id, int s, int a, int w) =>
        variants.at([id], s, a, w).firstWhere((v) => v.word == w);
    for (final id in ['ibn_wardan', 'ibn_jammaz']) {
      // وَهۡوَ: of the book's farsh words, Abu Ja'far's as Qalun's.
      for (final place in const [(2, 29, 15), (2, 74, 6), (13, 3, 0)]) {
        final v = only(id, place.$1, place.$2, place.$3);
        expect(v.description, 'بإسكان الهاء', reason: id);
        expect(v.isUsul, isFalse, reason: id);
      }
      // «لهو» the noun is read as Hafs.
      expect(variants.at([id], 31, 6, 4), isEmpty, reason: id);
      // Two hamzas of two words: in their chapter, not the farsh.
      final pair = only(id, 2, 13, 12);
      expect(pair.rule, 'ibdal_waw', reason: id);
      expect(pair.isUsul, isTrue, reason: id);
      // Nothing as Hafs is told as his difference.
      expect(variants.at([id], 2, 11, 1), isEmpty, reason: id);
      // The face stays when the silah beside it goes to its own row.
      expect(
        variants.at([id], 29, 25, 7).single.shownDescription,
        contains('الإقلاب'),
        reason: id,
      );
      // A face told beside what is as Hafs is never lost with it.
      for (final (s, a, w, told) in const [
        (4, 58, 17, 'إسكان العين'),
        (4, 154, 12, 'إسكان العين'),
        (5, 2, 28, 'إسكان النون'),
        (34, 17, 5, 'بالياء'),
        (82, 9, 2, 'بالياء'),
        (28, 57, 13, 'بالتاء'),
      ]) {
        expect(
          variants.at([id], s, a, w).map((v) => v.description).join(' '),
          contains(told),
          reason: '$id $s:$a:$w',
        );
      }
      final usul = usulOfRiwaya(variants, quran, id);
      for (final off in ['تسهيل الهمز', 'المدود', 'الهمزات', 'أصول أخرى']) {
        expect(usul.keys, isNot(contains(off)), reason: '$id: $off');
      }
    }
    for (final id in ['qalun', 'bazzi', 'qunbul']) {
      // ياء الإضافة: the verified readers' chapter.
      final ya = variants.at([id], 2, 30, 23).single;
      expect(ya.rule, 'ya_idafa', reason: id);
      expect(usulOfRiwaya(variants, quran, id).keys, contains('ياءات الإضافة'));
    }
    // A word's letters are farsh, the silah beside them usul.
    final bazzi = variants.allOf('bazzi');
    final silah = {
      for (final v in bazzi)
        if (v.isUsul && v.description.contains('صلة'))
          '${v.surah}:${v.ayah}:${v.word}',
    };
    expect(
      bazzi.where(
        (v) =>
            !v.isUsul &&
            !v.description.contains('صلة') &&
            silah.contains('${v.surah}:${v.ayah}:${v.word}'),
      ),
      isNotEmpty,
    );
    // «فَٱدَّٰرَءۡتُمُۥ»: his hamza as Hafs's, the silah alone told.
    expect(
      variants.at(['bazzi'], 2, 72, 3).single.description,
      contains('صلة'),
    );
  });

  testWidgets('مد البدل of Warsh is explained, with examples and its verses', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PrimaryScrollController(
              controller: ScrollController(),
              child: UsulGuideSheet(
                label: 'مد البدل',
                riwayat: const ['warsh'],
                variants: variants,
                quran: quran,
              ),
            ),
          ),
        ),
      ),
    );
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await t.pump();
    expect(find.byKey(const ValueKey('usul-guide-definition')), findsOneWidget);
    expect(find.text('ورش عن نافع'), findsOneWidget);
    expect(find.text('مد البدل: بالقصر والتوسط والإشباع'), findsOneWidget);
    // «وَمَا بَعْدَ هَمْزٍ ثَابِتٍ أَوْ مُغَيَّرٍ»: the two verses of its rule.
    final verses = t.widgetList<PoemVerse>(find.byType(PoemVerse));
    expect(verses.map((v) => v.bayt.n), containsAll([171, 172]));
  });

  testWidgets('a chapter numbers its kinds, charted, its two words told', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PrimaryScrollController(
              controller: ScrollController(),
              child: UsulGuideSheet(
                label: 'الهمزتان من كلمتين',
                riwayat: const ['warsh'],
                variants: variants,
                quran: quran,
              ),
            ),
          ),
        ),
      ),
    );
    final chart = find.byKey(const ValueKey('usul-guide-chart:warsh'));
    for (var i = 0; i < 40 && chart.evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await t.pump();
    }
    expect(chart, findsOneWidget);
    expect(find.text('١- المتفقتان، مفتوحتان (٢٩)'), findsOneWidget);
    expect(find.text('٨- المختلفتان، مفتوحة فمضمومة (١)'), findsOneWidget);
    expect(find.textContaining('بعد الهمزة حرف ساكن'), findsWidgets);
    expect(find.textContaining('فتبدل واوًا'), findsOneWidget);
    expect(find.textContaining('وأنواع أخرى'), findsNothing);
  });

  testWidgets('a riwaya lists its usul, Hafs says why he has none', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: RiwayaUsulScreen(
          riwaya: 'warsh',
          variants: variants,
          quran: quran,
        ),
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('riwaya-usul:النقل')), findsOneWidget);
    await t.pumpWidget(
      MaterialApp(
        home: RiwayaUsulScreen(
          riwaya: hafsId,
          variants: variants,
          quran: quran,
        ),
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.textContaining('فنص المصحف المعروض هو'), findsOneWidget);
  });
}
