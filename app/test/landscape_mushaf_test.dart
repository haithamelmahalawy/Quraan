import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/book_pager.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/mushaf_zoom.dart';
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
    expect(
      t.getSize(find.byKey(const ValueKey('mushaf-print'))).height,
      greaterThan(432 * 1.6),
    );
    final print = t.widget<MushafLines>(find.byType(MushafLines));
    expect(print.lines, mushafs.of(MushafEdition.madani).lines(3));
    expect(controller(t).position.maxScrollExtent, greaterThan(200));
    await t.drag(central(), const Offset(0, -230));
    await t.pumpAndSettle();
    expect(controller(t).offset, greaterThan(100));
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
    final target = t.getTopLeft(find.byKey(const ValueKey('word:2:10:0'))).dy;
    controller(t).jumpTo(target - print.top);
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
