import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/usul_guide.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
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
    expect(
      kinds('ترقيق الراء'),
      containsAll(['بعد ياء ساكنة أو مدية', 'بعد كسرة لازمة']),
    );
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
