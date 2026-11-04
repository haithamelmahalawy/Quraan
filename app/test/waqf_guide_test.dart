import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/waqf_guide.dart';
import 'package:qiraat_mushaf/ui/waqf_guide_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
  });

  String bare(String t) =>
      t.replaceAll(RegExp('[ً-ٰٟۖ-ۭـٔٓ]'), '').replaceAll('ٱ', 'ا');
  String words(WaqfQuote q) {
    final all = quran.ayah(q.surah, q.ayah).words;
    final from = q.from < 0 ? all.length + q.from : q.from;
    return all.sublist(from, q.to ?? all.length).join(' ');
  }

  test('each example quotes the words it means', () {
    String of(int i, [int example = 0]) =>
        bare(words(waqfDegrees[i].examples[example].stop));
    expect(of(0), contains('المفلحون'));
    expect(bare(words(waqfDegrees[0].examples[0].next!)), contains('كفروا'));
    expect(of(1), contains('ينفقون'));
    expect(bare(words(waqfDegrees[1].examples[0].next!)), contains('يؤمنون'));
    expect(of(2), 'الحمد لله');
    expect(bare(words(waqfDegrees[2].examples[0].next!)), contains('العلمين'));
    expect(bare(words(waqfDegrees[2].examples[1].next!)), contains('الرحيم'));
    expect(of(3), endsWith('يستحي'));
    expect(of(3, 1), contains('للمصلين'));
    expect(of(3, 2), endsWith('إن الله'));
  });

  test('each sign stands on the word its example stops at', () {
    WaqfQuote stop(int i) => waqfSigns[i].examples.first.stop;
    expect(words(stop(0)), contains('ۘ')); // لازم، يسمعون
    expect(bare(words(stop(0))), endsWith('يسمعون'));
    expect(bare(words(waqfSigns[0].examples.first.next!)), 'والموتى');
    // «لا» is no sign of this mushaf's text.
    expect(waqfSigns[1].examples, isEmpty);
    expect(words(stop(2)), contains('ۚ')); // جائز، بالحق
    expect(bare(words(stop(2))), endsWith('بالحق'));
    expect(words(stop(3)), contains('ۖ')); // الوصل أولى، إلا هو
    expect(bare(words(stop(3))), endsWith('إلا هو'));
    expect(words(stop(4)), contains('ۗ')); // الوقف أولى، إلا قليل
    expect(bare(words(stop(4))), endsWith('إلا قليل'));
    expect('ۛ'.allMatches(words(stop(5))), hasLength(2)); // تعانق
  });

  testWidgets('the guide shows every kind and sign, without an overflow', (
    t,
  ) async {
    // Tall enough for it all at once, as narrow as a phone.
    t.view.physicalSize = const Size(380, 14000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WaqfGuideSheet(quran: quran)),
      ),
    );
    await t.pump();
    for (final e in [...waqfDegrees, ...waqfOthers, ...waqfSigns]) {
      expect(find.byKey(ValueKey('waqf-guide-${e.title}')), findsOneWidget);
    }
    expect(t.takeException(), isNull);
  });
}
