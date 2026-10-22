import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/library_search.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/home_screen.dart';
import 'package:qiraat_mushaf/ui/kharouf_section.dart';
import 'package:qiraat_mushaf/ui/poem_verse.dart';
import 'package:qiraat_mushaf/ui/reading_library_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Mushafs mushafs;
  late Manzumat poems;
  late Kharouf book;
  late MutashabihatRepository mutashabihat;
  setUpAll(() async {
    mushafs = await Mushafs.load();
    poems = await Manzumat.load();
    book = await Kharouf.load();
    mutashabihat = await MutashabihatRepository.load();
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> show(
    WidgetTester t, {
    Widget? screen,
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
    bool preview = false,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    MushafColors.use(dark ? Brightness.dark : Brightness.light);
    addTearDown(() => MushafColors.use(Brightness.light));
    final theme = buildTheme(dark ? MushafPalette.dark : MushafPalette.light);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: preview
            ? theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
              )
            : theme,
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar')],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen ?? ReadingLibraryScreen(quran: mushafs.madani),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
  }

  Finder scroll(String key) => find
      .descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> reveal(WidgetTester t, Finder target, String list) async {
    if (target.evaluate().isEmpty) {
      await t.scrollUntilVisible(target, 180, scrollable: scroll(list));
    }
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  Future<void> select(
    WidgetTester t,
    String label,
    String value,
    String list,
  ) async {
    final target = find.byKey(ValueKey('library-filter-$label'));
    await reveal(t, target, list);
    await t.tap(target);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text(value).last);
    await t.pumpAndSettle();
    await t.tap(find.text(value).last);
    await t.pumpAndSettle();
  }

  test(
    'library search handles diacritics, keyboard alefs and verse digits',
    () {
      expect(
        librarySearchMatches('الشاطبيه', librarySearchText('الشَّاطِبِيَّة')),
        isTrue,
      );
      expect(librarySearchMatches('أبواب', librarySearchText('ابواب')), isTrue);
      expect(librarySearchMatches('١٧١', librarySearchText('171')), isTrue);
      expect(librarySearchMatches('۱۷۱', librarySearchText('171')), isTrue);
      expect(
        librarySearchMatches('الدرة', librarySearchText('الشاطبية')),
        isFalse,
      );
    },
  );

  test('book browsing exposes each note once and preserves span indexing', () {
    expect(book.entries, hasLength(8096));
    expect(book.entries.toSet(), hasLength(book.entries.length));
    expect(() => book.entries.clear(), throwsUnsupportedError);
    for (final e in book.entries) {
      for (var w = e.word; w < e.word + e.count; w++) {
        expect(book.at(e.surah, e.ayah, w), contains(e));
      }
      expect(
        mushafs.madani.ayah(e.surah, e.ayah).words.length,
        greaterThanOrEqualTo(e.word + e.count),
      );
    }
  });

  testWidgets(
    'home library icon opens all three sources without changing reading',
    (t) async {
      final settings = ReaderSettings.memory(selected: {'warsh'})..page = 399;
      await show(
        t,
        size: const Size(320, 640),
        screen: HomeScreen(
          mushafs: mushafs,
          variants: VariantRepository({}),
          mutashabihat: mutashabihat,
          settings: settings,
        ),
      );
      await t.tap(find.byTooltip('المتون ومصادر القراءات'));
      await t.pumpAndSettle();
      expect(find.byType(ReadingLibraryScreen), findsOneWidget);
      for (final id in ['shatibiyya', 'durrah', 'tasheel']) {
        await reveal(
          t,
          find.byKey(ValueKey('library-$id')),
          'reading-library-list',
        );
      }
      expect(settings.page, 399);
      expect(settings.selected, {'warsh'});
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('source categories and name search combine and open the Durrah', (
    t,
  ) async {
    await show(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'المصادر'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-shatibiyya')), findsNothing);
    await reveal(
      t,
      find.byKey(const ValueKey('library-tasheel')),
      'reading-library-list',
    );
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'المتون'));
    await t.tap(find.widgetWithText(ChoiceChip, 'المتون'));
    await t.enterText(find.byKey(const ValueKey('library-search')), 'الدره');
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-tasheel')), findsNothing);
    expect(find.byKey(const ValueKey('library-shatibiyya')), findsNothing);
    await reveal(
      t,
      find.byKey(const ValueKey('library-durrah')),
      'reading-library-list',
    );
    await t.tap(find.byKey(const ValueKey('library-durrah')));
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
    expect(find.text('الأبيات المعروضة: 240 من 240'), findsOneWidget);
    expect(find.text(poems.verses(Poem.durrah).first.sadr), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'poem chapter filtering, Arabic number search, explanation and font controls',
    (t) async {
      await show(t, screen: const PoemLibraryScreen(poem: Poem.shatibiyya));
      expect(find.text('الأبيات المعروضة: 1173 من 1173'), findsOneWidget);
      final b = poems.verses(Poem.shatibiyya).firstWhere((b) => b.n == 171);
      await select(t, 'الباب', b.chapter, 'poem-library-list');
      final count = poems
          .verses(Poem.shatibiyya)
          .where((v) => v.chapter == b.chapter)
          .length;
      expect(find.text('الأبيات المعروضة: $count من 1173'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('poem-search')), '١٧١');
      await t.pumpAndSettle();
      expect(find.text('الأبيات المعروضة: 1 من 1173'), findsOneWidget);
      await reveal(t, find.byTooltip('شرح البيت 171'), 'poem-library-list');
      await t.tap(find.byTooltip('شرح البيت 171'));
      await t.pumpAndSettle();
      expect(
        find.text(poems.explanation(Poem.shatibiyya, 171)!.text),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('إخفاء شرح البيت 171'));
      await t.pumpAndSettle();
      expect(
        find.text(poems.explanation(Poem.shatibiyya, 171)!.text),
        findsNothing,
      );
      await t.tap(find.byTooltip('تكبير الخط'));
      await t.pumpAndSettle();
      expect(t.widget<PoemVerse>(find.byType(PoemVerse)).fontSize, 20);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Tasheel combines source filters and displays selected reading and quoted proof',
    (t) async {
      await show(
        t,
        size: const Size(540, 1100),
        screen: TasheelLibraryScreen(quran: mushafs.madani),
      );
      expect(find.text('المواضع المعروضة: 8096 من 8096'), findsOneWidget);
      await select(
        t,
        'السورة',
        mushafs.madani.surah(1).nameAr,
        'tasheel-library-list',
      );
      await select(t, 'الرواية', 'ورش', 'tasheel-library-list');
      await select(t, 'القسم', 'الفرش', 'tasheel-library-list');
      final tile = find.byKey(const ValueKey('tasheel-note-1-4-0-farsh'));
      await reveal(t, tile, 'tasheel-library-list');
      await t.tap(tile);
      await t.pumpAndSettle();
      final readings = t.widgetList<KharoufReadingText>(
        find.byType(KharoufReadingText),
      );
      expect(readings, isNotEmpty);
      expect(
        readings.every(
          (w) => w.riwayat.length == 1 && w.riwayat.contains('warsh'),
        ),
        isTrue,
      );
      final entry = book.at(1, 4, 0).first;
      expect(find.text(entry.verses.first), findsOneWidget);
      expect(find.text('الأبيات المستشهد بها في الكتاب'), findsOneWidget);
      await reveal(
        t,
        find.byKey(const ValueKey('tasheel-search')),
        'tasheel-library-list',
      );
      await t.enterText(
        find.byKey(const ValueKey('tasheel-search')),
        'كلمةغيرموجودة',
      );
      await t.pumpAndSettle();
      expect(find.text('المواضع المعروضة: 0 من 8096'), findsOneWidget);
      expect(find.text('لا توجد مواضع مطابقة.'), findsOneWidget);
      await t.tap(find.text('إظهار الجميع'));
      await t.pumpAndSettle();
      expect(find.text('المواضع المعروضة: 8096 من 8096'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'library and both readers fit compact dark landscape with larger text',
    (t) async {
      for (final screen in [
        ReadingLibraryScreen(quran: mushafs.madani),
        const PoemLibraryScreen(poem: Poem.durrah),
        TasheelLibraryScreen(quran: mushafs.madani),
      ]) {
        await show(
          t,
          screen: screen,
          dark: true,
          scale: 1.4,
          size: const Size(640, 360),
        );
        await t.drag(find.byType(ListView).first, const Offset(0, -500));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('graphical source library preview', tags: 'golden', (t) async {
    await show(t, preview: true, size: const Size(390, 1000));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/reading_library.png'),
    );
  });
}
