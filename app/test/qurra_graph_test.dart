import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/qurra_biographies.dart';
import 'package:qiraat_mushaf/data/qurra_graph.dart';
import 'package:qiraat_mushaf/ui/qurra_graph_view.dart';
import 'package:qiraat_mushaf/ui/qurra_guide_screen.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('the graph includes all ten readers, twenty transmission roles and eight cities', () {
    final graph = QurraGraph.build();
    expect(graph.readerCount, 10);
    expect(graph.narratorCount, 20);
    expect(graph.nodes, hasLength(39));
    expect(graph.nodes.map((n) => n.id).toSet(), hasLength(39));
    expect(
      graph.edges.where((e) => e.kind == QurraEdgeKind.transmission),
      hasLength(20),
    );
    expect(
      graph.edges.where((e) => e.kind == QurraEdgeKind.samePerson),
      hasLength(2),
    );
    final ids = graph.nodes.map((n) => n.id).toSet();
    for (final e in graph.edges) {
      expect(ids, contains(e.from));
      expect(ids, contains(e.to));
    }
    final warsh = graph.nodes.firstWhere((n) => n.id == 'narrator-warsh');
    expect(warsh.city, RecitationCity.egypt);
    expect(
      graph.edges,
      contains((
        from: 'city-egypt',
        to: 'narrator-warsh',
        kind: QurraEdgeKind.classification,
      )),
    );
    for (final narrator in graph.nodes.where(
      (n) => n.kind == QurraNodeKind.narrator,
    )) {
      final parent = graph.nodes.singleWhere(
        (n) => n.id == 'reader-${narrator.reader!.qiraaId}',
      );
      // Below his reader, on the same side of the cone.
      expect(
        math.sqrt(
          math.pow(narrator.position.x - parent.position.x, 2) +
              math.pow(narrator.position.z - parent.position.z, 2),
        ),
        lessThan(1),
      );
      expect(narrator.position.y, greaterThan(parent.position.y));
    }
    expect(
      graph.edges,
      contains((
        from: 'reader-nafi',
        to: 'narrator-warsh',
        kind: QurraEdgeKind.transmission,
      )),
    );
  });

  test('filters retain relationship context and distinguish narrator and reader cities', () {
    final basra = QurraGraph.build(city: RecitationCity.basra);
    expect((basra.readerCount, basra.narratorCount), (2, 4));
    final egypt = QurraGraph.build(
      city: RecitationCity.egypt,
      narratorCity: true,
    );
    expect((egypt.readerCount, egypt.narratorCount), (1, 1));
    expect(
      egypt.nodes.map((n) => n.id),
      containsAll([
        'city-madinah',
        'city-egypt',
        'reader-nafi',
        'narrator-warsh',
      ]),
    );
    expect(QurraGraph.build(city: RecitationCity.egypt).nodes, isEmpty);
    final three = QurraGraph.build(group: RecitationGroup.three);
    expect((three.readerCount, three.narratorCount), (3, 6));
    final duri = QurraGraph.build(query: 'الدوري');
    expect((duri.readerCount, duri.narratorCount), (2, 2));
    expect(
      duri.edges.where((e) => e.kind == QurraEdgeKind.samePerson),
      hasLength(1),
    );
    expect(QurraGraph.build(query: 'غيرموجود').nodes, isEmpty);
  });

  test('camera rotates world coordinates with perspective and bounded zoom and pitch', () {
    final camera = QurraGraphCamera();
    addTearDown(camera.dispose);
    const size = Size(500, 600), point = GraphPoint3(2, 1, .7);
    final start = projectQurraPoint(point, size, camera);
    camera.orbit(.5, .2);
    final rotated = projectQurraPoint(point, size, camera);
    expect((start.point - rotated.point).distance, greaterThan(5));
    expect(rotated.depth, isNot(start.depth));
    camera.orbit(math.pi * 2, 0);
    expect(
      (projectQurraPoint(point, size, camera).point - rotated.point).distance,
      lessThan(.0001),
    );
    camera.frame(100, Offset.zero);
    camera.orbit(0, 100);
    expect(camera.zoom, 3.5);
    expect(camera.pitch, 1.35);
    camera.reset();
    expect(
      (projectQurraPoint(point, size, camera).point - start.point).distance,
      lessThan(.0001),
    );
  });

  Future<void> show(
    WidgetTester t, {
    Widget? child,
    Size size = const Size(390, 844),
    bool dark = false,
    bool reduced = false,
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
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: child ?? const QurraGuideScreen(),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pumpAndSettle();
  }

  QurraGraph graph(WidgetTester t) =>
      t.widget<QurraGraphView>(find.byType(QurraGraphView)).graph;
  QurraGraphCamera camera(WidgetTester t) =>
      t.widget<QurraGraphView>(find.byType(QurraGraphView)).camera;

  testWidgets('one finger drag turns the 3D scene and moves its nodes', (
    t,
  ) async {
    await show(t);
    final c = camera(t);
    final (yaw, pitch) = (c.yaw, c.pitch);
    final asim = find.byKey(const ValueKey('graph-node-reader-asim'));
    final before = t.getCenter(asim);
    await t.drag(
      find.byKey(const ValueKey('qurra-3d-canvas')),
      const Offset(90, 30),
    );
    await t.pumpAndSettle();
    expect(c.yaw, isNot(yaw));
    expect(c.pitch, greaterThan(pitch));
    expect((t.getCenter(asim) - before).distance, greaterThan(10));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'a city of the legend stands out with its readers and narrators',
    (t) async {
      await show(t);
      final kufa = find.byKey(const ValueKey('graph-legend-kufa'));
      await t.ensureVisible(kufa);
      await t.pumpAndSettle();
      await t.tap(kufa);
      await t.pumpAndSettle();
      double opacity(String id) => t
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(ValueKey('graph-node-$id')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity('reader-asim'), greaterThan(.35));
      expect(opacity('narrator-hafs'), greaterThan(.35));
      expect(opacity('reader-nafi'), lessThan(.2));
      await t.tap(kufa);
      await t.pumpAndSettle();
      expect(opacity('reader-nafi'), greaterThan(.35));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'a reader stands above his narrators, apart, all around the scene',
    (t) async {
      final c = QurraGraphCamera();
      addTearDown(c.dispose);
      await show(
        t,
        size: const Size(360, 700),
        child: Scaffold(
          body: QurraGraphView(
            graph: QurraGraph.build(query: 'عاصم'),
            camera: c,
            onSelect: (_) {},
          ),
        ),
      );
      final parent = find.byKey(const ValueKey('graph-node-reader-asim'));
      final shubah = find.byKey(const ValueKey('graph-node-narrator-shubah'));
      final hafs = find.byKey(const ValueKey('graph-node-narrator-hafs'));
      for (final yaw in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
        c.orbit(yaw - c.yaw, 0);
        await t.pumpAndSettle();
        final p = t.getRect(parent), a = t.getRect(shubah), b = t.getRect(hafs);
        expect(a.overlaps(b), isFalse);
        expect(p.center.dy, lessThan(math.min(a.center.dy, b.center.dy)));
        for (final r in [p, a, b]) {
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(360));
        }
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets('a small pinch over a name zooms without opening a biography', (
    t,
  ) async {
    final c = QurraGraphCamera();
    addTearDown(c.dispose);
    final selected = <String>[];
    await show(
      t,
      child: Scaffold(
        body: QurraGraphView(
          graph: QurraGraph.build(query: 'ورش'),
          camera: c,
          onSelect: (node) => selected.add(node.id),
        ),
      ),
    );
    final name = find.byKey(const ValueKey('graph-node-narrator-warsh'));
    final center = t.getCenter(name);
    final first = await t.startGesture(center - const Offset(5, 0), pointer: 1);
    final second = await t.startGesture(
      center + const Offset(5, 0),
      pointer: 2,
    );
    await t.pump();
    await first.moveTo(center - const Offset(8, 0));
    await second.moveTo(center + const Offset(8, 0));
    await t.pump();
    await first.up();
    await second.up();
    await t.pumpAndSettle();
    expect(c.zoom, greaterThan(1.3));
    expect(selected, isEmpty);
    await t.tap(name);
    await t.pumpAndSettle();
    expect(selected, ['narrator-warsh']);
  });

  testWidgets(
    'the home guide starts as a graph and tapping a searched narrator opens his biography',
    (t) async {
      await show(t);
      expect(graph(t).nodes, hasLength(39));
      expect(find.byKey(const ValueKey('qurra-guide-list')), findsNothing);
      await t.enterText(find.byKey(const ValueKey('biography-search')), 'ورش');
      await t.pumpAndSettle();
      expect((graph(t).readerCount, graph(t).narratorCount), (1, 1));
      final node = find.byKey(const ValueKey('graph-node-narrator-warsh'));
      await t.tapAt(t.getCenter(node));
      await t.pumpAndSettle();
      final warsh = readerBiographies.first.narrators.firstWhere(
        (n) => n.riwayaId == 'warsh',
      );
      expect(find.text(warsh.fullName), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(warsh.city.nameAr),
        ),
        findsOneWidget,
      );
      expect(find.text(warsh.title), findsOneWidget);
      await t.tap(find.text('العودة إلى الشبكة'));
      await t.pumpAndSettle();
      expect(find.byType(QurraGraphView), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'rotation mode orbits, two fingers zoom and pan, and reset restores browsing',
    (t) async {
      final c = QurraGraphCamera();
      addTearDown(c.dispose);
      await show(
        t,
        child: Scaffold(
          body: QurraGraphView(
            graph: QurraGraph.build(),
            camera: c,
            onSelect: (_) {},
          ),
        ),
      );
      final start = c.yaw;
      await t.drag(
        find.byKey(const ValueKey('qurra-3d-canvas')),
        const Offset(80, 25),
      );
      await t.pumpAndSettle();
      expect(c.yaw, isNot(start));
      final center = t.getCenter(find.byKey(const ValueKey('qurra-3d-canvas')));
      final a = await t.startGesture(center - const Offset(40, 0), pointer: 1);
      final b = await t.startGesture(center + const Offset(40, 0), pointer: 2);
      await t.pump();
      await a.moveTo(center - const Offset(65, -15));
      await b.moveTo(center + const Offset(65, 15));
      await t.pump();
      expect(c.zoom, greaterThan(1.1));
      expect(c.pan.distance, greaterThan(1));
      await b.up();
      await t.pump();
      final zoomBeforeNewFinger = c.zoom;
      final third = await t.startGesture(
        center + const Offset(65, 15),
        pointer: 3,
      );
      await t.pump();
      await a.moveTo(center - const Offset(69, -15));
      await third.moveTo(center + const Offset(69, 15));
      await t.pump();
      expect(c.zoom, greaterThanOrEqualTo(zoomBeforeNewFinger * .95));
      await a.up();
      await third.up();
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('إعادة ضبط المنظور'));
      await t.pumpAndSettle();
      expect(c.yaw, start);
      expect(c.zoom, 1);
      expect(c.pan, Offset.zero);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'turning brings another city to the front, thicker and clear, with a click',
    (t) async {
      final sounds = <Object?>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemSound.play') sounds.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await show(t);
      final c = camera(t);
      double opacity(String id) => t
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(ValueKey('graph-node-$id')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      // Baghdad (Khalaf) faces the screen at the start, Madinah aside.
      expect(opacity('reader-khalaf'), greaterThan(.8));
      expect(opacity('reader-nafi'), lessThanOrEqualTo(.5));
      c.orbit(math.pi, 0);
      await t.pumpAndSettle();
      expect(sounds, isNotEmpty);
      expect(opacity('reader-khalaf'), lessThanOrEqualTo(.5));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('automatic rotation can be paused and manual drag stops it', (
    t,
  ) async {
    await show(t);
    await t.tap(find.byTooltip('دوران تلقائي'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    final yaw = camera(t).yaw;
    await t.pump(const Duration(milliseconds: 120));
    expect(camera(t).yaw, isNot(yaw));
    await t.tap(find.byTooltip('إيقاف الدوران'));
    await t.pumpAndSettle();
    final paused = camera(t).yaw;
    await t.pump(const Duration(milliseconds: 300));
    expect(camera(t).yaw, paused);
    await t.tap(find.byTooltip('دوران تلقائي'));
    await t.pump();
    await t.drag(
      find.byKey(const ValueKey('qurra-3d-canvas')),
      const Offset(40, 0),
    );
    await t.pumpAndSettle();
    expect(camera(t).rotating, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'graph filters combine group and city while the optional list remains available',
    (t) async {
      await show(t);
      await t.tap(find.byTooltip('تصفية الدليل'));
      await t.pumpAndSettle();
      await t.tap(
        find.widgetWithText(ChoiceChip, RecitationGroup.three.nameAr),
      );
      await t.pumpAndSettle();
      final basra = find.byKey(const ValueKey('city-basra'));
      await t.ensureVisible(basra);
      await t.pumpAndSettle();
      await t.tap(basra);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('apply-guide-filters')));
      await t.pumpAndSettle();
      expect((graph(t).readerCount, graph(t).narratorCount), (1, 2));
      expect(graph(t).nodes.map((n) => n.id), contains('reader-yaqub'));
      await t.tap(find.byTooltip('عرض القائمة'));
      await t.pumpAndSettle();
      expect(find.byType(QurraGraphView), findsNothing);
      expect(find.byKey(const ValueKey('qurra-guide-list')), findsOneWidget);
      await t.tap(find.byTooltip('عرض الشبكة ثلاثية الأبعاد'));
      await t.pumpAndSettle();
      expect((graph(t).readerCount, graph(t).narratorCount), (1, 2));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'compact portrait and landscape preserve orientation and reduced motion permits manual rotation',
    (t) async {
      await show(
        t,
        size: const Size(320, 640),
        dark: true,
        reduced: true,
        scale: 1.4,
      );
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.play_circle_outline),
            )
            .onPressed,
        isNull,
      );
      final start = camera(t).yaw;
      await t.tap(find.byTooltip('تدوير يمينًا'));
      await t.pumpAndSettle();
      expect(camera(t).yaw, isNot(start));
      final rotated = camera(t).yaw;
      t.view.physicalSize = const Size(640, 360);
      await t.pumpAndSettle();
      expect(camera(t).yaw, rotated);
      await t.tap(find.byTooltip('ملء الشاشة بالشبكة'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('biography-search')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'rotatable relationship graph landscape preview',
    tags: 'golden',
    (t) async {
      await show(t, size: const Size(1100, 700), dark: true, preview: true);
      await t.tap(find.byTooltip('ملء الشاشة بالشبكة'));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(QurraGuideScreen),
        matchesGoldenFile('goldens/qurra_graph_landscape.png'),
      );
    },
  );

  testWidgets('organized city branches portrait preview', tags: 'golden', (
    t,
  ) async {
    await show(t, size: const Size(390, 844), preview: true);
    await expectLater(
      find.byType(QurraGuideScreen),
      matchesGoldenFile('goldens/qurra_graph_portrait.png'),
    );
  });
}
