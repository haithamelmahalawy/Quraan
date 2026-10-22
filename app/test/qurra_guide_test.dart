import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/qurra_biographies.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/home_screen.dart';
import 'package:qiraat_mushaf/ui/qurra_guide_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Mushafs mushafs;
  late MutashabihatRepository mutashabihat;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    mushafs = await Mushafs.load();
    mutashabihat = await MutashabihatRepository.load();
  });

  test(
    'biographies cover the canonical catalog and distinguish shared people',
    () {
      expect(
        readerBiographies.map((b) => b.qiraaId).toSet(),
        qiraat.map((q) => q.id).toSet(),
      );
      final narrators = [for (final b in readerBiographies) ...b.narrators];
      expect(narrators, hasLength(20));
      expect(narrators.map((n) => n.riwayaId).toSet(), {
        for (final q in qiraat)
          for (final r in q.riwayat) r.id,
      });
      for (final b in readerBiographies) {
        expect(
          b.narrators.map((n) => n.riwayaId).toList(),
          b.qiraa.riwayat.map((r) => r.id).toList(),
        );
        expect(b.brief, isNotEmpty);
        for (final n in b.narrators) {
          expect(n.fullName, isNotEmpty);
          expect(n.brief, isNotEmpty);
        }
      }
      expect(
        readerBiographies.where((b) => b.group == RecitationGroup.seven),
        hasLength(7),
      );
      expect(
        readerBiographies.where((b) => b.group == RecitationGroup.three),
        hasLength(3),
      );
      final byCity = {
        for (final c in RecitationCity.values)
          c: readerBiographies.where((b) => b.city == c).length,
      };
      expect(byCity[RecitationCity.kufa], 3);
      expect(byCity[RecitationCity.basra], 2);
      expect(byCity[RecitationCity.madinah], 2);
      expect(byCity[RecitationCity.makkah], 1);
      expect(byCity[RecitationCity.damascus], 1);
      expect(byCity[RecitationCity.baghdad], 1);
      expect(narrators.where((n) => n.personId == 'duri'), hasLength(2));
      expect(
        narrators.singleWhere((n) => n.riwayaId == 'warsh').city,
        RecitationCity.egypt,
      );
      expect(
        narrators.singleWhere((n) => n.riwayaId == 'susi').city,
        RecitationCity.raqqa,
      );
      expect(biographySources, isNotEmpty);
    },
  );

  Future<void> show(
    WidgetTester t, {
    Widget? home,
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    double scale = 1,
    bool actualFont = false,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    MushafColors.use(brightness);
    addTearDown(() => MushafColors.use(Brightness.light));
    final theme = buildTheme(
      brightness == Brightness.dark ? MushafPalette.dark : MushafPalette.light,
    );
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: actualFont
              ? theme.textTheme.apply(fontFamily: 'Hafs')
              : null,
        ),
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar')],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home ?? const QurraGuideScreen(),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder guideScroll() => find
      .descendant(
        of: find.byKey(const ValueKey('qurra-guide-list')),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> top(WidgetTester t) async {
    t.state<ScrollableState>(guideScroll()).position.jumpTo(0);
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await top(t);
      await t.scrollUntilVisible(f, 160, scrollable: guideScroll());
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> applyFilters(
    WidgetTester t, {
    RecitationCity? city,
    RecitationGroup? group,
    bool allCities = false,
  }) async {
    await tap(t, find.byTooltip('تصفية الدليل'));
    if (group != null) {
      await tap(t, find.widgetWithText(ChoiceChip, group.nameAr));
    }
    if (city != null) await tap(t, find.byKey(ValueKey('city-${city.name}')));
    if (allCities) await tap(t, find.byKey(const ValueKey('city-all')));
    await tap(t, find.byKey(const ValueKey('apply-guide-filters')));
  }

  Future<void> search(WidgetTester t, String text) async {
    await top(t);
    await t.enterText(find.byKey(const ValueKey('biography-search')), text);
    await t.pumpAndSettle();
  }

  String count(WidgetTester t) =>
      t.widget<Text>(find.byKey(const ValueKey('biography-count'))).data!;

  testWidgets('home icon opens the guide without changing reader settings', (
    t,
  ) async {
    final settings = ReaderSettings.memory(selected: {'warsh'})..page = 399;
    await show(
      t,
      home: HomeScreen(
        mushafs: mushafs,
        variants: VariantRepository({}),
        mutashabihat: mutashabihat,
        settings: settings,
      ),
    );
    await tap(t, find.byTooltip('القراء العشرة ورواتهم'));
    expect(find.byType(QurraGuideScreen), findsOneWidget);
    expect(count(t), contains('١٠'));
    expect(settings.page, 399);
    expect(settings.selected, {'warsh'});
    expect(t.takeException(), isNull);
  });

  testWidgets('city and seven/three filters combine and can be reset', (
    t,
  ) async {
    await show(t);
    await applyFilters(t, city: RecitationCity.basra);
    expect(count(t), 'النتائج: ٢ من القراء');
    await applyFilters(t, group: RecitationGroup.three);
    expect(count(t), 'النتائج: ٣ من القراء');
    await applyFilters(t, city: RecitationCity.basra);
    expect(count(t), 'النتائج: ١ من القراء');
    expect(find.byKey(const ValueKey('reader-yaqub')), findsOneWidget);
    await search(t, 'اسم غير موجود');
    expect(
      find.text('لا توجد نتائج مطابقة للبحث والتصنيف الحالي.'),
      findsOneWidget,
    );
    await tap(t, find.text('إظهار الجميع'));
    expect(count(t), 'النتائج: ١٠ من القراء');
  });

  testWidgets(
    'narrators use their own cities and preserve their reading links',
    (t) async {
      await show(t);
      await tap(t, find.text('الرواة'));
      expect(count(t), 'النتائج: ٢٠ رواية');
      await applyFilters(t, city: RecitationCity.egypt);
      expect(count(t), 'النتائج: ١ رواية');
      expect(find.text('ورش عن نافع'), findsOneWidget);
      await applyFilters(t, allCities: true);
      await search(t, 'الدُّوري');
      expect(count(t), 'النتائج: ٢ رواية');
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('narrator-duri_abuamr')),
        200,
        scrollable: guideScroll(),
      );
      expect(find.text('الدوري عن أبي عمرو'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('narrator-duri_kisai')),
        250,
        scrollable: guideScroll(),
      );
      expect(find.text('الدوري عن الكسائي'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a narrator search opens the relevant short biographies', (
    t,
  ) async {
    await show(t);
    await search(t, 'قنبل');
    expect(count(t), 'النتائج: ١ من القراء');
    final qunbul = readerBiographies
        .firstWhere((b) => b.qiraaId == 'ibn_kathir')
        .narrators[1];
    await t.scrollUntilVisible(
      find.text(qunbul.brief),
      250,
      scrollable: guideScroll(),
    );
    expect(find.text(qunbul.brief), findsOneWidget);
    expect(find.text(qunbul.fullName), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('filter drafts can be cancelled and combined before applying', (
    t,
  ) async {
    await show(t);
    await tap(t, find.byTooltip('تصفية الدليل'));
    await tap(t, find.byKey(const ValueKey('city-basra')));
    Navigator.of(t.element(find.byKey(const ValueKey('guide-filter-scroll'))))
        .pop();
    await t.pumpAndSettle();
    expect(count(t), 'النتائج: ١٠ من القراء');
    await applyFilters(
      t,
      group: RecitationGroup.three,
      city: RecitationCity.basra,
    );
    expect(count(t), 'النتائج: ١ من القراء');
    expect(find.text('البصرة'), findsWidgets);
    await tap(t, find.byTooltip('تصفية الدليل'));
    await tap(t, find.text('مسح التصفية'));
    await tap(t, find.byKey(const ValueKey('apply-guide-filters')));
    expect(count(t), 'النتائج: ١٠ من القراء');
  });

  testWidgets('compact dark landscape and large Arabic text remain usable', (
    t,
  ) async {
    await show(
      t,
      size: const Size(640, 360),
      brightness: Brightness.dark,
      scale: 1.4,
    );
    await applyFilters(t, city: RecitationCity.basra);
    await tap(t, find.byTooltip('عن الدليل ومصادره'));
    expect(find.text(biographySources.first.title), findsOneWidget);
    await tap(t, find.text('إغلاق'));
    await show(
      t,
      size: const Size(320, 640),
      brightness: Brightness.dark,
      scale: 1.4,
    );
    await top(t);
    await t.scrollUntilVisible(
      find.byType(TextField),
      140,
      scrollable: guideScroll(),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('home and offline reader guide previews', tags: 'golden', (
    t,
  ) async {
    await show(
      t,
      actualFont: true,
      brightness: Brightness.dark,
      home: HomeScreen(
        mushafs: mushafs,
        variants: VariantRepository({}),
        mutashabihat: mutashabihat,
        settings: ReaderSettings.memory(),
      ),
    );
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_qurra_guide_icon.png'),
    );
    await tap(t, find.byTooltip('القراء العشرة ورواتهم'));
    await expectLater(
      find.byType(QurraGuideScreen),
      matchesGoldenFile('goldens/qurra_guide_readers.png'),
    );
  });

  testWidgets('narrator city and brief preview', tags: 'golden', (t) async {
    await show(t, actualFont: true, size: const Size(390, 1000));
    await tap(t, find.text('الرواة'));
    await applyFilters(t, city: RecitationCity.egypt);
    await expectLater(
      find.byType(QurraGuideScreen),
      matchesGoldenFile('goldens/qurra_guide_warsh.png'),
    );
  });

  testWidgets('graphical city filtering preview', tags: 'golden', (t) async {
    await show(t, actualFont: true, size: const Size(390, 844));
    await tap(t, find.byTooltip('تصفية الدليل'));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qurra_guide_filters_3d.png'),
    );
  });
}
