import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
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
    // هأنتم 4, the ibdal of the single hamza 986, مِنسَاتَهُۥ.
    expect(lin['الهمز المفرد'], hasLength(991));
    expect(
      kinds('الهمز المفرد')
          .where((k) => !k.startsWith('همز «ائتنا» ابتداءً: ')),
      unorderedEquals([
        'الهمز المتحرك',
        'الإبدال واوًا',
        'الإبدال ألفًا',
        'الإبدال ياءً',
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
    expect(lin['الإدغام'], hasLength(21));
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
      usulOfRiwaya(variants, quran, 'qalun').keys,
      isNot(contains('الهمز المفرد')),
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
