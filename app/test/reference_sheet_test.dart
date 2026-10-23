import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/ui/reference_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Manzumat poems;
  late List<String> surahs;
  setUpAll(() async {
    poems = await Manzumat.load();
    await Kharouf.load();
    surahs = [for (final s in (await QuranRepository.load()).surahs) s.nameAr];
  });

  Bayt bayt(int n) => poems.verses(Poem.shatibiyya).firstWhere((b) => b.n == n);
  Variant reading({
    int ayah = 9,
    int word = 4,
    String rule = '',
    String text = 'وما يخادعون',
    VariantKind kind = VariantKind.farsh,
    String riwaya = 'warsh',
  }) => Variant(
    riwayaId: riwaya,
    surah: 2,
    ayah: ayah,
    word: word,
    count: 1,
    text: text,
    kind: kind,
    rule: rule,
  );

  Future<void> show(WidgetTester tester, Variant v, String word) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: PrimaryScrollController(
              controller: scroll,
              child: ReferenceSheet(
                readings: [v],
                word: word,
                surah: 2,
                surahNames: surahs,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('book proof first; remaining chapter opens and collapses', (
    tester,
  ) async {
    await show(tester, reading(), 'وما يخدعون');
    expect(find.text(bayt(445).sadr), findsOneWidget);
    expect(find.text(bayt(446).sadr), findsNothing);
    expect(
      find.text('الدليل المقتبس في التسهيل لقراءات التنزيل'),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('عرض المزيد ('));
    await tester.pumpAndSettle();
    expect(find.text(bayt(446).sadr), findsOneWidget);
    await tester.ensureVisible(find.text('إخفاء المزيد').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إخفاء المزيد').first);
    await tester.pumpAndSettle();
    expect(find.text(bayt(446).sadr), findsNothing);
    expect(find.text(bayt(445).sadr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each bayt explanation toggles independently by icon or verse', (
    tester,
  ) async {
    await show(
      tester,
      reading(
        ayah: 4,
        word: 9,
        rule: 'badal',
        text: '',
        kind: VariantKind.usul,
      ),
      'بالآخرة',
    );
    final a = poems.explanation(Poem.shatibiyya, 171)!;
    final b = poems.explanation(Poem.shatibiyya, 172)!;
    expect(a.text, isNot(b.text));
    expect(find.text(a.text), findsNothing);
    expect(find.text(b.text), findsNothing);
    await tester.tap(find.byTooltip('شرح البيت 171'));
    await tester.pumpAndSettle();
    expect(find.text(a.text), findsOneWidget);
    expect(find.text(b.text), findsNothing);
    await tester.ensureVisible(find.byTooltip('شرح البيت 172'));
    await tester.tap(find.byTooltip('شرح البيت 172'));
    await tester.pumpAndSettle();
    expect(find.text(a.text), findsOneWidget);
    expect(find.text(b.text), findsOneWidget);
    await tester.ensureVisible(find.text(bayt(171).sadr));
    await tester.tap(find.text(bayt(171).sadr));
    await tester.pumpAndSettle();
    expect(find.text(a.text), findsNothing);
    expect(find.text(b.text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmatched evidence shows the whole chapter automatically', (
    tester,
  ) async {
    for (final (riwaya, poem) in [
      ('warsh', Poem.shatibiyya),
      ('ibn_wardan', Poem.durrah),
    ]) {
      final v = reading(
        ayah: 1,
        word: 0,
        text: 'كلمةغيرموجودة',
        riwaya: riwaya,
      );
      await show(tester, v, 'كلمةغيرموجودة');
      final expected = poems.referenceOf(v, 'كلمةغيرموجودة', 2, surahs);
      expect(expected.mention, isEmpty);
      expect(find.text('أبيات الباب كاملة'), findsOneWidget);
      expect(
        find.byKey(ValueKey('${poem.name}-${expected.verses.first.n}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('${poem.name}-${expected.verses.last.n}')),
        findsOneWidget,
      );
      expect(find.textContaining('عرض المزيد ('), findsNothing);
      expect(find.text('إخفاء المزيد'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('proof and open explanation survive phone rotation', (
    tester,
  ) async {
    await show(tester, reading(), 'وما يخدعون');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('شرح البيت 445'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('شرح البيت 445'));
    await tester.pumpAndSettle();
    final explanation = poems.explanation(Poem.shatibiyya, 445)!.text;
    expect(find.text(explanation), findsOneWidget);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.text(explanation), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
