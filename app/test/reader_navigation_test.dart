import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/ui/book_pager.dart';
import 'package:qiraat_mushaf/ui/page_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('page slider', () {
    late QuranRepository quran, shamarly;

    setUpAll(() async {
      quran = await QuranRepository.load();
      shamarly = await QuranRepository.load(null, MushafEdition.shamarly);
    });

    Future<void> showSlider(
      WidgetTester tester, {
      required QuranRepository mushaf,
      int page = 10,
      ValueChanged<int>? onGo,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PageSlider(quran: mushaf, page: page, onGo: onGo ?? (_) {}),
          ),
        ),
      ),
    );

    testWidgets('previews a page and opens it within the same surah', (
      t,
    ) async {
      final opened = <int>[];
      await showSlider(t, mushaf: quran, onGo: opened.add);
      var slider = t.widget<Slider>(find.byType(Slider));
      expect(slider.min, 1);
      expect(slider.max, 604);
      expect(slider.divisions, 603);
      expect(slider.value, 10);

      slider.onChanged!(11);
      await t.pump();
      slider = t.widget<Slider>(find.byType(Slider));
      expect(slider.value, 11);
      expect(find.text('ص 11'), findsOneWidget);
      expect(slider.label, contains(quran.surah(2).nameAr));
      expect(slider.label, contains('11'));
      expect(opened, isEmpty);

      slider.onChangeEnd!(11);
      await t.pump();
      expect(opened, [11]);
    });

    testWidgets('previews surah changes and reaches the last page', (t) async {
      final opened = <int>[];
      await showSlider(t, mushaf: quran, onGo: opened.add);
      t.widget<Slider>(find.byType(Slider)).onChanged!(604);
      await t.pump();
      final slider = t.widget<Slider>(find.byType(Slider));
      final name = quran.surah(quran.page(604).first.surah).nameAr;
      expect(find.text('سورة $name'), findsOneWidget);
      expect(find.text('ص 604'), findsOneWidget);
      expect(slider.semanticFormatterCallback!(604), contains(name));
      expect(slider.semanticFormatterCallback!(604), contains('604'));
      slider.onChangeEnd!(604);
      expect(opened, [604]);
    });

    testWidgets('switching editions resets the preview and printed range', (
      t,
    ) async {
      await showSlider(t, mushaf: quran);
      t.widget<Slider>(find.byType(Slider)).onChanged!(604);
      await t.pump();
      await showSlider(t, mushaf: shamarly, page: shamarly.firstPage);
      final slider = t.widget<Slider>(find.byType(Slider));
      expect(slider.min, shamarly.firstPage);
      expect(slider.max, shamarly.lastPage);
      expect(slider.divisions, shamarly.pageCount - 1);
      expect(slider.value, shamarly.firstPage);
      expect(t.takeException(), isNull);
    });

    testWidgets('releasing on the current page leaves it in place', (t) async {
      final opened = <int>[];
      await showSlider(t, mushaf: quran, onGo: opened.add);
      t.widget<Slider>(find.byType(Slider)).onChangeEnd!(10);
      expect(opened, isEmpty);
    });
  });

  group('page swipes', () {
    late GlobalKey<BookPagerState> key;
    late List<int> changes;

    setUp(() {
      key = GlobalKey<BookPagerState>();
      changes = [];
    });

    Future<void> showPager(
      WidgetTester tester, {
      int index = 4,
      bool enabled = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 600,
              child: BookPager(
                key: key,
                itemCount: 10,
                initialIndex: index,
                enabled: enabled,
                onPageChanged: changes.add,
                itemBuilder: (_, i) => ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('Page $i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> settle(WidgetTester t) async {
      await t.pump();
      await t.pump(const Duration(milliseconds: 230));
      await t.pump();
    }

    testWidgets('short, gentle swipes turn promptly in both directions', (
      t,
    ) async {
      await showPager(t);
      await t.timedDrag(
        find.byType(BookPager),
        const Offset(65, 0),
        const Duration(milliseconds: 400),
      );
      await settle(t);
      expect(key.currentState!.index, 5);

      await t.timedDrag(
        find.byType(BookPager),
        const Offset(-65, 0),
        const Duration(milliseconds: 400),
      );
      await settle(t);
      expect(key.currentState!.index, 4);
      expect(changes, [5, 4]);
      expect(t.takeException(), isNull);
    });

    testWidgets('a light, short flick turns a page', (t) async {
      await showPager(t);
      await t.fling(find.byType(BookPager), const Offset(35, 0), 450);
      await settle(t);
      expect(key.currentState!.index, 5);
      expect(changes, [5]);
    });

    testWidgets('a page jump cancels an unfinished turn', (t) async {
      await showPager(t);
      final turn = key.currentState!.turn(1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      key.currentState!.jumpTo(8);
      await settle(t);
      await turn;
      expect(key.currentState!.index, 8);
      expect(changes, [8]);
    });

    testWidgets('a cancelled drag allows the next swipe to start fresh', (
      t,
    ) async {
      await showPager(t);
      final drag = await t.startGesture(t.getCenter(find.byType(BookPager)));
      await drag.moveBy(const Offset(80, 0));
      await t.pump();
      await drag.cancel();
      await settle(t);
      expect(key.currentState!.index, 4);
      expect(changes, isEmpty);

      await t.timedDrag(
        find.byType(BookPager),
        const Offset(-65, 0),
        const Duration(milliseconds: 400),
      );
      await settle(t);
      expect(key.currentState!.index, 3);
      expect(changes, [3]);
    });

    testWidgets('swipes respect the first and last pages', (t) async {
      await showPager(t, index: 0);
      await t.fling(find.byType(BookPager), const Offset(-120, 0), 600);
      await settle(t);
      expect(key.currentState!.index, 0);
      key.currentState!.jumpTo(9);
      await t.pump();
      await t.fling(find.byType(BookPager), const Offset(120, 0), 600);
      await settle(t);
      expect(key.currentState!.index, 9);
      expect(changes, [9]);
    });

    testWidgets('zoomed pages leave horizontal drags to panning', (t) async {
      await showPager(t, enabled: false);
      await t.fling(find.byType(BookPager), const Offset(120, 0), 600);
      await settle(t);
      expect(key.currentState!.index, 4);
      expect(changes, isEmpty);
    });
  });
}
