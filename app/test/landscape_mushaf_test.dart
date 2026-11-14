import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/book_pager.dart';
import 'package:qiraat_mushaf/ui/mushaf_decor.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/mushaf_zoom.dart';
import 'package:qiraat_mushaf/ui/page_slider.dart';
import 'package:qiraat_mushaf/ui/reader_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Mushafs mushafs;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    mushafs = await Mushafs.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh']);
    mutashabihat = await MutashabihatRepository.load();
  });

  Future<void> show(
    WidgetTester t,
    Size size, {
    VariantRepository? repository,
    bool margins = true,
    QuranRepository? quran,
    int number = 3,
    ReaderSettings? settings,
    bool reader = false,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    final s = settings ?? ReaderSettings.memory(selected: {'warsh'});
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light).copyWith(
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Hafs'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: reader
              ? ReaderScreen(
                  mushafs: mushafs,
                  variants: variants,
                  mutashabihat: mutashabihat,
                  settings: s,
                )
              : Scaffold(
                  body: MushafPage(
                    page: number,
                    quran: quran ?? mushafs.of(MushafEdition.madani),
                    variants: repository ?? variants,
                    mutashabihat: mutashabihat,
                    settings: s,
                    showHamesh: margins,
                    onWordTap: (_, _) {},
                  ),
                ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Finder central() => find.byKey(const ValueKey('landscape-page-scroll'));
  ScrollController controller(WidgetTester t) =>
      t.widget<SingleChildScrollView>(central()).controller!;

  testWidgets(
    'the lamp lights the differences or puts them out, beside «الرواة»',
    (t) async {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..page = 3
        ..qcfFont = false
        ..compareHafs = true
        ..displayed = 'warsh';
      await show(t, const Size(432, 800), settings: settings, reader: true);
      // The top bar folded at first, the icon of a menu on its handle (the
      // user, 2026-11-13): opened.
      expect(find.byKey(const ValueKey('top-bar-menu-icon')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('top-bar-toggle')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('top-bar-menu-icon')), findsNothing);
      final lamp = find.byKey(const ValueKey('glow-lamp'));
      final glowing = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Alerting',
      );
      final rays = find.byKey(const ValueKey('glow-rays'));
      final similar = find.byKey(const ValueKey('mutashabihat-toggle'));
      expect(lamp.hitTestable(), findsOneWidget);
      expect(similar.hitTestable(), findsOneWidget);
      // In the top bar, beside «الرواة», at its left.
      final at = t.getRect(lamp.hitTestable());
      final riwayat = t.getRect(
        find.byKey(const ValueKey('riwayat-panel-toggle')).hitTestable(),
      );
      expect(at.right, lessThan(riwayat.left));
      expect(riwayat.left - at.right, lessThan(12));
      expect((at.center.dy - riwayat.center.dy).abs(), lessThan(2));
      expect(t.getRect(similar.hitTestable()).right, lessThan(at.left));
      expect(glowing, findsNothing);
      expect(rays, findsNothing);
      // Out: nothing moves, so nothing is drawn again and again.
      await t.pump(const Duration(seconds: 1));
      expect(t.binding.hasScheduledFrame, isFalse);
      await t.tap(lamp);
      await t.pump();
      expect(settings.diffAlert, DiffAlert.glow);
      expect(glowing, findsWidgets);
      expect(rays, findsOneWidget);
      // Lit, nothing moves either: the rays drawn still (their flicker kept
      // a weak phone drawing the whole screen without a touch).
      await t.pump(const Duration(seconds: 2));
      expect(t.binding.hasScheduledFrame, isFalse);
      await t.tap(lamp);
      await t.pump();
      expect(settings.diffAlert, isNull);
      // The neighbours put out a moment after the page in sight.
      await t.pump(const Duration(seconds: 1));
      expect(glowing, findsNothing);
      expect(rays, findsNothing);
      await t.tap(similar);
      await t.pump();
      expect(settings.showMutashabihat, isFalse);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );

  testWidgets('two quick taps on the page: full screen, two more: back', (
    t,
  ) async {
    await show(t, const Size(412, 900), reader: true);
    bool full() => t
        .widgetList<MushafPage>(find.byType(MushafPage))
        .every((p) => !p.showHamesh);
    var clock = const Duration(seconds: 1);
    Future<void> twice() async {
      // On the frame, beside the lines: a tap on the lines opens a word.
      final lines = t.getRect(find.byType(MushafLines).last);
      final at = Offset(lines.left - 6, lines.center.dy);
      // Two taps with their times, 150ms apart.
      clock += const Duration(seconds: 5);
      for (final time in [clock, clock + const Duration(milliseconds: 150)]) {
        final g = await t.createGesture();
        await g.down(at, timeStamp: time);
        await g.up(timeStamp: time + const Duration(milliseconds: 50));
        await t.pump(const Duration(milliseconds: 80));
      }
      await t.pumpAndSettle();
      // The neighbours drawn again a moment after the page in sight.
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
    }

    expect(full(), isFalse);
    await twice();
    // The page enlarged as by «ملء الشاشة», not zoomed in on the place.
    expect(full(), isTrue);
    expect(find.byTooltip('ملء الشاشة'), findsNothing);
    await twice();
    expect(full(), isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'two quick taps in the middle of an ayah: full screen, no sheet',
    (t) async {
      await show(t, const Size(412, 900), reader: true);
      bool full() => t
          .widgetList<MushafPage>(find.byType(MushafPage))
          .every((p) => !p.showHamesh);
      bool sheet() => find.byType(BottomSheet).evaluate().isNotEmpty;
      // A word in the middle of the text.
      final at = t.getCenter(find.byType(MushafLines).last);
      Future<void> tap(Duration time) async {
        final g = await t.createGesture();
        await g.down(at, timeStamp: time);
        await g.up(timeStamp: time + const Duration(milliseconds: 50));
      }

      await tap(const Duration(seconds: 10));
      await t.pump(const Duration(milliseconds: 100));
      await tap(const Duration(seconds: 10, milliseconds: 150));
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      // The neighbours drawn again a moment after the page in sight.
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(full(), isTrue);
      // Neither the witnesses nor the ayah's sheet opened.
      expect(sheet(), isFalse);
      // Once: a moment later, the word opens.
      await tap(const Duration(seconds: 20));
      await t.pump(const Duration(milliseconds: 100));
      expect(sheet(), isFalse);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 500));
      expect(sheet(), isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('«الرواة» in the top bar lets the panel down and up', (t) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..page = 3
      ..qcfFont = false;
    await show(t, const Size(432, 800), settings: settings, reader: true);
    // The top bar folded at first, the icon of a menu on its handle (the
    // user, 2026-11-13): opened.
    expect(find.byKey(const ValueKey('top-bar-menu-icon')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('top-bar-toggle')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('top-bar-menu-icon')), findsNothing);
    final button = find.byKey(const ValueKey('riwayat-panel-toggle'));
    final panel = find.byKey(const ValueKey('riwayat-panel'));
    expect(button, findsOneWidget);
    expect(panel, findsNothing);
    // Its icon, its name and an arrow down while the riwayat are hidden,
    // up while they show (the user, 2026-11-13).
    final down = find.descendant(
      of: button,
      matching: find.byKey(const ValueKey('riwayat-arrow-down')),
    );
    final up = find.descendant(
      of: button,
      matching: find.byKey(const ValueKey('riwayat-arrow-up')),
    );
    expect(down, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.groups_rounded)),
      findsOneWidget,
    );
    // After «المدينة».
    expect(
      t.getRect(button).right,
      lessThan(t.getRect(find.text('المدينة')).left),
    );
    await t.tap(button);
    await t.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(t.getRect(panel).top, greaterThan(t.getRect(button).bottom));
    expect(up, findsOneWidget);
    expect(down, findsNothing);
    // A touch outside it, on the mushaf, folds it away, and opens nothing
    // (the user, 2026-11-13); let down again.
    await t.tapAt(t.getCenter(find.byType(MushafPage).last));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(panel, findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(panel, findsOneWidget);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(panel, findsNothing);
    // Folding the bar away folds the riwayat with it; their tab is then over
    // the page's header, the lamp beside it.
    await t.tap(button);
    await t.pumpAndSettle();
    expect(panel, findsOneWidget);
    await t.tap(find.byKey(const ValueKey('top-bar-toggle')));
    await t.pumpAndSettle();
    expect(panel, findsNothing);
    final tab = button.hitTestable();
    expect(tab, findsOneWidget);
    final lamp = t.getRect(
      find.byKey(const ValueKey('glow-lamp')).hitTestable(),
    );
    expect(lamp.right, lessThan(t.getRect(tab).left + 1));
    expect(lamp.height, lessThan(24));
    await t.tap(tab);
    await t.pumpAndSettle();
    expect(panel, findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  testWidgets('held, the lamp opens the usul it lights, each switched apart', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..page = 3
      ..qcfFont = false
      ..compareHafs = true
      ..displayed = 'warsh';
    await show(t, const Size(432, 800), settings: settings, reader: true);
    // The top bar folded at first, the icon of a menu on its handle (the
    // user, 2026-11-13): opened.
    expect(find.byKey(const ValueKey('top-bar-menu-icon')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('top-bar-toggle')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('top-bar-menu-icon')), findsNothing);
    // Lit, pumped by the clock.
    settings.diffAlert = DiffAlert.glow;
    await t.pump();
    // The neighbours lit a moment after the page in sight.
    await t.pump(const Duration(seconds: 1));
    final glowing = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Alerting',
    );
    final all = glowing.evaluate().length;
    expect(all, greaterThan(0));
    Future<void> open() async {
      await t.longPress(find.byKey(const ValueKey('glow-lamp')));
      for (
        var i = 0;
        i < 50 && find.byType(SwitchListTile).evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      await t.pump(const Duration(seconds: 1));
    }

    await open();
    expect(find.text('أصول التوهج'), findsOneWidget);
    // Every asl on at first.
    final switches = find.byType(SwitchListTile);
    expect(switches, findsWidgets);
    expect(
      t.widgetList<SwitchListTile>(switches).every((s) => s.value),
      isTrue,
    );
    final first = t.widget<SwitchListTile>(switches.first);
    final label = (first.key! as ValueKey<String>).value.substring(
      'glow-usul:'.length,
    );
    await t.tap(switches.first);
    await t.pump();
    // «الوقف على الهمز» unlit at first, not one of Warsh's.
    expect(settings.unlitUsul, {ReaderSettings.unlitAtFirst, label});
    expect(t.widget<SwitchListTile>(switches.first).value, isFalse);
    // None, then all again.
    await t.tap(find.byKey(const ValueKey('glow-usul-none')));
    await t.pump();
    expect(
      t.widgetList<SwitchListTile>(switches).every((s) => !s.value),
      isTrue,
    );
    await t.pageBack();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(glowing.evaluate().length, lessThan(all));
    await open();
    await t.tap(find.byKey(const ValueKey('glow-usul-all')));
    await t.pump();
    expect(settings.unlitUsul, isEmpty);
    await t.pageBack();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    settings.diffAlert = null;
    expect(glowing.evaluate().length, all);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  testWidgets(
    'landscape bars collapse independently without covering the page',
    (t) async {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..page = 3
        ..qcfFont = false;
      await show(t, const Size(800, 432), settings: settings, reader: true);
      final top = find.byKey(const ValueKey('top-bar-toggle'));
      final bottom = find.byKey(const ValueKey('bottom-bar-toggle'));
      final current = find.byType(MushafPage).last;
      expect(top.hitTestable(), findsOneWidget);
      expect(bottom.hitTestable(), findsOneWidget);
      expect(find.byType(Slider).hitTestable(), findsNothing);
      final full = t.getRect(current);
      expect(full.height, closeTo(432 - 48, 1));
      expect(full.top, greaterThanOrEqualTo(t.getRect(top).bottom));
      expect(full.bottom, lessThanOrEqualTo(t.getRect(bottom).top));

      final scroll = t
          .widget<SingleChildScrollView>(
            find.descendant(of: current, matching: central()),
          )
          .controller!;
      scroll.jumpTo(180);
      await t.pumpAndSettle();
      await t.tap(top);
      await t.pump();
      await t.pump(const Duration(milliseconds: 160));
      final halfway = t.getSize(current).height;
      await t.pumpAndSettle();
      final topOpen = t.getRect(current);
      expect(halfway, lessThan(full.height));
      expect(halfway, greaterThan(topOpen.height));
      expect(find.byType(Slider).hitTestable(), findsNothing);
      expect(scroll.offset, closeTo(180, .1));

      await t.tap(bottom);
      await t.pumpAndSettle();
      expect(find.byType(Slider).hitTestable(), findsOneWidget);
      final bothOpen = t.getRect(current);
      expect(bothOpen.height, closeTo(topOpen.height - 44, 1));
      expect(bothOpen.bottom, lessThanOrEqualTo(t.getRect(bottom).top));
      expect(
        t.getRect(find.byType(PageSlider)).top,
        greaterThanOrEqualTo(t.getRect(bottom).bottom),
      );
      await t.tap(top);
      await t.tap(bottom);
      await t.pumpAndSettle();
      expect(t.getSize(current).height, full.height);
      expect(settings.page, 3);

      t.view.physicalSize = const Size(432, 800);
      await t.pumpAndSettle();
      // Upright, the top bar folds away too, open at first; the bottom one
      // stays.
      expect(top, findsOneWidget);
      expect(bottom, findsNothing);
      expect(find.byType(Slider).hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );

  testWidgets('landscape enlarges the print and scrolls its original lines', (
    t,
  ) async {
    await show(t, const Size(432, 800));
    final portrait = t
        .widget<InkText>(find.byKey(const ValueKey('word:2:6:0')))
        .style
        .fontSize!;
    await show(t, const Size(800, 432));
    final landscape = t
        .widget<InkText>(find.byKey(const ValueKey('word:2:6:0')))
        .style
        .fontSize!;
    final pageWords = t.widgetList<InkText>(
      find.byWidgetPredicate(
        (w) =>
            w is InkText &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('word:'),
      ),
    );
    expect(pageWords.map((w) => w.style.fontSize).toSet(), hasLength(1));
    expect(pageWords.map((w) => w.style.fontFamily).toSet(), {'Hafs'});
    expect(landscape, greaterThan(portrait * 1.15));
    // The lines taller than the screen, scrolled within the frame.
    expect(t.getSize(find.byType(MushafLines)).height, greaterThan(432 * 1.3));
    final print = t.widget<MushafLines>(find.byType(MushafLines));
    expect(print.lines, mushafs.of(MushafEdition.madani).lines(3));
    expect(controller(t).position.maxScrollExtent, greaterThan(200));
    final frame = find.byKey(const ValueKey('mushaf-ornament-3'));
    final before = t.getRect(frame);
    await t.drag(central(), const Offset(0, -230));
    await t.pumpAndSettle();
    expect(controller(t).offset, greaterThan(100));
    // The frame stays, its bands always in sight (the user, 2026-11-13).
    expect(t.getRect(frame), before);
    expect(t.takeException(), isNull);
  });

  testWidgets('margins follow visible words and use larger text', (t) async {
    await show(t, const Size(800, 432), repository: _StudyVariants(variants));
    final farsh = find.byKey(const ValueKey('landscape-farsh-margin'));
    final usul = find.byKey(const ValueKey('landscape-usul-margin'));
    final note = find.byKey(const ValueKey('landscape-note:2:6:0'));
    expect(note, findsOneWidget);
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(t.getRect(farsh).left, greaterThanOrEqualTo(print.right));
    expect(t.getRect(usul).right, lessThanOrEqualTo(print.left));
    final labels = t.widgetList<Text>(
      find.descendant(of: usul, matching: find.byType(Text)),
    );
    expect(
      labels.any((w) => w.data == 'الأصول' && w.style!.fontSize! >= 12),
      isTrue,
    );
    final words = t.widgetList<RichText>(
      find.descendant(of: note, matching: find.byType(RichText)),
    );
    expect(words.any((w) => w.text.toPlainText().contains('السطر')), isTrue);
    // Its line cut by the frame, half of it above: no note for it (the
    // user, 2026-11-13); whole again, its note back.
    final word = t.getRect(find.byKey(const ValueKey('word:2:6:0')));
    final window = t.getRect(central());
    final at = controller(t).offset;
    controller(t).jumpTo(at + word.center.dy - window.top);
    await t.pumpAndSettle();
    expect(note, findsNothing);
    controller(t).jumpTo(at);
    await t.pumpAndSettle();
    expect(note, findsOneWidget);
    final target = t.getTopLeft(find.byKey(const ValueKey('word:2:10:0'))).dy;
    // Its line wholly in sight, a little below the frame.
    controller(t).jumpTo(target - t.getRect(central()).top - 20);
    await t.pumpAndSettle();
    expect(note, findsNothing);
    expect(find.byKey(const ValueKey('landscape-note:2:10:0')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('dense margins scroll independently and retain every note', (
    t,
  ) async {
    await show(
      t,
      const Size(800, 360),
      repository: _StudyVariants(variants, dense: true),
    );
    final farsh = t.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('landscape-farsh-scroll')),
    );
    expect(farsh.controller!.position.maxScrollExtent, greaterThan(100));
    final pageOffset = controller(t).offset;
    await t.drag(
      find.byKey(const ValueKey('landscape-farsh-scroll')),
      const Offset(0, -180),
    );
    await t.pumpAndSettle();
    expect(farsh.controller!.offset, greaterThan(0));
    expect(controller(t).offset, pageOffset);
    expect(find.byKey(const ValueKey('bottom-notes')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the last section and page number remain reachable', (t) async {
    await show(t, const Size(800, 432), repository: _StudyVariants(variants));
    controller(t).jumpTo(controller(t).position.maxScrollExtent);
    await t.pumpAndSettle();
    final (ayah, word) = mushafs
        .of(MushafEdition.madani)
        .lines(3)!
        .whereType<TextLine>()
        .last
        .words
        .last;
    final last = find.byKey(
      ValueKey('word:${ayah.surah}:${ayah.number}:$word'),
    );
    expect(last, findsOneWidget);
    expect(t.getRect(last).overlaps(t.getRect(central())), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('full screen and Shamarly also read in scrolling sections', (
    t,
  ) async {
    for (final edition in MushafEdition.values) {
      final q = mushafs.of(edition);
      await show(
        t,
        const Size(740, 360),
        margins: false,
        quran: q,
        number: q.firstPage,
      );
      expect(
        find.byKey(const ValueKey('landscape-farsh-margin')),
        findsNothing,
      );
      expect(controller(t).position.maxScrollExtent, greaterThan(0));
      expect(t.takeException(), isNull);
    }
  });

  testWidgets(
    'rotation keeps the page and restores portrait spread preference',
    (t) async {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..page = 3
        ..twoPages = true
        ..qcfFont = false;
      await show(t, const Size(800, 432), settings: settings, reader: true);
      expect(t.widget<BookPager>(find.byType(BookPager)).itemCount, 604);
      expect(settings.twoPages, isTrue);
      await show(t, const Size(432, 800), settings: settings, reader: true);
      expect(t.widget<BookPager>(find.byType(BookPager)).itemCount, 302);
      expect(settings.page, 3);
      expect(find.byKey(const ValueKey('landscape-reader')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );

  testWidgets('vertical reading and horizontal page turns work together', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..page = 3
      ..qcfFont = false;
    await show(t, const Size(800, 432), settings: settings, reader: true);
    final current = find.descendant(
      of: find.byType(MushafPage).last,
      matching: central(),
    );
    final scroll = t.widget<SingleChildScrollView>(current).controller!;
    await t.drag(current, const Offset(0, -150));
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(50));
    expect(settings.page, 3);
    await t.fling(current, const Offset(80, 0), 600);
    await t.pumpAndSettle();
    expect(settings.page, 4);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  testWidgets(
    'compact landscape phones keep enlarged margins without overflow',
    (t) async {
      await show(t, const Size(568, 320));
      expect(find.byKey(const ValueKey('landscape-reader')), findsOneWidget);
      expect(controller(t).position.maxScrollExtent, greaterThan(100));
      controller(t).jumpTo(controller(t).position.maxScrollExtent);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'small pinches zoom in and out in both orientations without turning',
    (t) async {
      for (final size in [const Size(432, 800), const Size(800, 432)]) {
        final settings = ReaderSettings.memory(selected: {'warsh'})
          ..page = 3
          ..qcfFont = false;
        await show(t, size, settings: settings, reader: true);
        final current = find.byType(MushafPage).last;
        final zoom = t.widget<MushafZoom>(
          find.descendant(of: current, matching: find.byType(MushafZoom)),
        );
        final center = t.getCenter(current);
        final first = await t.startGesture(
          center - const Offset(60, 0),
          pointer: 1,
        );
        final second = await t.startGesture(
          center + const Offset(60, 0),
          pointer: 2,
        );
        await t.pump();
        await first.moveBy(const Offset(-4, 0));
        await second.moveBy(const Offset(4, 0));
        await first.up();
        await second.up();
        await t.pumpAndSettle();
        final scale = zoom.controller.value.getMaxScaleOnAxis();
        expect(scale, greaterThan(1.08));
        expect(settings.page, 3);
        expect(t.widget<BookPager>(find.byType(BookPager)).enabled, isFalse);
        final before = zoom.controller.value.getTranslation().x;
        await t.drag(current, const Offset(-28, 0));
        await t.pumpAndSettle();
        expect(zoom.controller.value.getTranslation().x, lessThan(before));
        expect(zoom.controller.value.getMaxScaleOnAxis(), scale);
        expect(settings.page, 3);
        final a = await t.startGesture(
          center - const Offset(60, 0),
          pointer: 3,
        );
        final b = await t.startGesture(
          center + const Offset(60, 0),
          pointer: 4,
        );
        await t.pump();
        await a.moveBy(const Offset(5, 0));
        await b.moveBy(const Offset(-5, 0));
        await a.up();
        await b.up();
        await t.pumpAndSettle();
        expect(zoom.controller.value.getMaxScaleOnAxis(), 1);
        expect(t.widget<BookPager>(find.byType(BookPager)).enabled, isTrue);
        await t.fling(current, const Offset(80, 0), 600);
        await t.pumpAndSettle();
        expect(settings.page, 4);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'adding a second finger during a scroll immediately starts zoom',
    (t) async {
      await show(t, const Size(800, 432));
      final center = t.getCenter(central());
      final first = await t.startGesture(
        center - const Offset(60, 0),
        pointer: 1,
      );
      await first.moveBy(const Offset(0, -20));
      await t.pump();
      await first.moveBy(const Offset(0, -45));
      await t.pump();
      expect(controller(t).offset, greaterThan(0));
      final offset = controller(t).offset;
      final second = await t.startGesture(
        center + const Offset(60, -65),
        pointer: 2,
      );
      await t.pump();
      await first.moveBy(const Offset(-5, 0));
      await second.moveBy(const Offset(5, 0));
      await t.pump();
      expect(
        t
            .widget<MushafZoom>(find.byType(MushafZoom))
            .controller
            .value
            .getMaxScaleOnAxis(),
        greaterThan(1.1),
      );
      expect(controller(t).offset, closeTo(offset, .01));
      await first.up();
      await second.up();
      await t.pumpAndSettle();
      await t.tap(find.text('حجم الصفحة'));
      await t.pumpAndSettle();
      expect(
        t.widget<MushafZoom>(find.byType(MushafZoom)).controller.value,
        Matrix4.identity(),
      );
      await t.drag(central(), const Offset(0, -100));
      await t.pumpAndSettle();
      expect(controller(t).offset, greaterThan(offset + 30));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'a second finger cancels an initial page turn and zooms the current page',
    (t) async {
      final settings = ReaderSettings.memory(selected: {'warsh'})
        ..page = 3
        ..qcfFont = false;
      await show(t, const Size(432, 800), settings: settings, reader: true);
      final current = find.byType(MushafPage).last;
      final zoom = t.widget<MushafZoom>(
        find.descendant(of: current, matching: find.byType(MushafZoom)),
      );
      final center = t.getCenter(current);
      final first = await t.startGesture(
        center - const Offset(60, 0),
        pointer: 1,
      );
      await first.moveBy(const Offset(45, 0));
      await t.pump();
      final second = await t.startGesture(
        center + const Offset(105, 0),
        pointer: 2,
      );
      await t.pump();
      await first.moveBy(const Offset(-5, 0));
      await second.moveBy(const Offset(5, 0));
      await first.up();
      await second.up();
      await t.pumpAndSettle();
      expect(settings.page, 3);
      expect(zoom.controller.value.getMaxScaleOnAxis(), greaterThan(1.1));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );

  testWidgets('landscape phone preview with matching margins', tags: 'golden', (
    t,
  ) async {
    await show(t, const Size(900, 420));
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/landscape_warsh_top.png'),
    );
    controller(t).jumpTo(280);
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MushafPage),
      matchesGoldenFile('goldens/landscape_warsh_middle.png'),
    );
  });

  // «شكل المصحف»: its ring over the page, the page in sight below it; a look
  // touched put on at once, the ring left open to try another (the user,
  // 2026-11-14).
  testWidgets('the ring of the looks over the page puts one on at once', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..page = 3
      ..qcfFont = false;
    await show(t, const Size(432, 800), settings: settings, reader: true);
    await t.tap(find.byKey(const ValueKey('top-bar-toggle')));
    await t.pumpAndSettle();
    final button = find.byKey(const ValueKey('mushaf-style-button'));
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pump(const Duration(milliseconds: 400));
    final ring = find.byKey(const ValueKey('mushaf-style-ring'));
    expect(ring, findsOneWidget);
    // The page below it, in sight.
    final page = t.getRect(find.byType(MushafPage).last);
    expect(page.top, greaterThanOrEqualTo(t.getRect(ring).bottom - 1));
    expect(page.height, greaterThan(400));
    await t.tap(find.byKey(const ValueKey('mushaf-style-emerald')));
    await t.pump(const Duration(milliseconds: 400));
    expect(settings.mushafStyle, 'emerald');
    expect(ring, findsOneWidget);
    // A touch outside it, on the mushaf: folded away, nothing else done.
    await t.tapAt(t.getCenter(find.byType(MushafPage).last));
    await t.pump(const Duration(milliseconds: 400));
    expect(ring, findsNothing);
    expect(find.byKey(const ValueKey('page-navigator')), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    // Opened again, closed by its button again.
    await t.tap(button);
    await t.pump(const Duration(milliseconds: 400));
    expect(ring, findsOneWidget);
    await t.tap(button);
    await t.pump(const Duration(milliseconds: 400));
    expect(ring, findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  // «السور والصفحات»: a touch where no word is shows two wheels, a surah's
  // and a page's, each following the other and the mushaf going there at
  // once; a touch anywhere puts them away; a double tap is full screen, not
  // the wheels (the user, 2026-11-14).
  testWidgets('a touch where no word is shows the wheels of surahs and pages', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})
      ..page = 3
      ..qcfFont = false;
    await show(t, const Size(432, 800), settings: settings, reader: true);
    final navigator = find.byKey(const ValueKey('page-navigator'));
    // On the frame's side band, beside the lines: no word there.
    final band = t.getRect(find.byKey(const ValueKey('mushaf-ornament-3')));
    final empty = Offset(band.left + 6, band.center.dy);
    Future<void> tapAt(Offset at, Duration time) async {
      final g = await t.createGesture();
      await g.down(at, timeStamp: time);
      await g.up(timeStamp: time + const Duration(milliseconds: 40));
      await t.pump();
    }

    await tapAt(empty, const Duration(seconds: 10));
    expect(navigator, findsNothing, reason: 'Not before a double tap could');
    await t.pump(const Duration(milliseconds: 300));
    expect(navigator, findsOneWidget);
    FixedExtentScrollController wheel(String key) =>
        t.widget<ListWheelScrollView>(find.byKey(ValueKey(key))).controller!
            as FixedExtentScrollController;
    // A surah turned to: its first page, the mushaf there, the page's wheel
    // with it.
    final quran = mushafs.of(MushafEdition.madani);
    wheel('surah-wheel').jumpToItem(2);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(seconds: 1));
    expect(settings.page, quran.surah(3).startPage);
    expect(
      wheel('page-wheel').selectedItem,
      quran.surah(3).startPage - quran.firstPage,
    );
    // A page turned to: its surah's wheel with it.
    final page = quran.surah(4).startPage + 2;
    wheel('page-wheel').jumpToItem(page - quran.firstPage);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(seconds: 1));
    expect(settings.page, page);
    expect(wheel('surah-wheel').selectedItem, 3);
    // Put away by a touch elsewhere.
    await t.tapAt(const Offset(20, 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(navigator, findsNothing);
    // A double tap: full screen, the wheels not shown.
    final now = t.getRect(find.byKey(ValueKey('mushaf-ornament-$page')));
    final spot = Offset(now.left + 6, now.center.dy);
    await tapAt(spot, const Duration(seconds: 30));
    await tapAt(spot, const Duration(seconds: 30, milliseconds: 150));
    await t.pump(const Duration(milliseconds: 600));
    expect(navigator, findsNothing);
    expect(find.byKey(const ValueKey('exit-full-screen')), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  // The opening pages (al-Fatiha, the first of al-Baqara): the text in a
  // window within an illuminated border; the others as they were (the user,
  // 2026-11-14). A surah's name in its banner read on the page in every look.
  testWidgets('the two opening pages alone have the illuminated border', (
    t,
  ) async {
    for (final (number, opening) in const [(1, true), (2, true), (3, false)]) {
      await show(
        t,
        const Size(432, 800),
        number: number,
        settings: ReaderSettings.memory(selected: const {}),
      );
      final frame = t.widget<OrnamentFrame>(
        find.byKey(ValueKey('mushaf-ornament-$number')),
      );
      expect(frame.opening, opening, reason: '$number');
      expect(t.takeException(), isNull);
    }
    for (final look in MushafStyle.values) {
      MushafColors.use(Brightness.light, look);
      final ink = MushafColors.frameInk.computeLuminance();
      final page = MushafColors.page.computeLuminance();
      expect(
        (page + .05) / (ink + .05),
        greaterThanOrEqualTo(4.5),
        reason: look.name,
      );
    }
    MushafColors.use(Brightness.light);
  });

  // No hamesh or usul beside it: the page as wide as beside one, in the
  // middle, its lines as large as then and as many in sight (the user,
  // 2026-11-14).
  testWidgets('a page with no notes keeps the width it has beside one', (
    t,
  ) async {
    await show(
      t,
      const Size(800, 432),
      repository: VariantRepository(const {}),
      settings: ReaderSettings.memory(selected: const {}),
    );
    expect(find.byKey(const ValueKey('landscape-farsh-margin')), findsNothing);
    expect(find.byKey(const ValueKey('landscape-usul-margin')), findsNothing);
    final print = t.getRect(find.byKey(const ValueKey('mushaf-print')));
    expect(print.width, closeTo(800 - 240, 1));
    expect(print.left, closeTo(800 - print.right, 1));
    expect(t.takeException(), isNull);
  });
}

class _StudyVariants extends VariantRepository {
  _StudyVariants(this.source, {this.dense = false}) : super({'warsh'});
  final VariantRepository source;
  final bool dense;

  @override
  bool isLoaded(String id) => id == 'warsh';

  @override
  Iterable<Variant> at(
    Iterable<String> ids,
    int surah,
    int ayah,
    int word,
  ) sync* {
    yield* source.at(ids, surah, ayah, word);
    if (!ids.contains('warsh') || (!dense && word != 0)) return;
    yield Variant(
      riwayaId: 'warsh',
      surah: surah,
      ayah: ayah,
      word: word,
      count: 1,
      text: 'قِرَاءَة',
      kind: VariantKind.farsh,
      description: 'بفتح الحرف وتغيير الحركة في هذا السطر رقم $word',
    );
  }
}
