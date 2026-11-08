import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/jam.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/services/ayah_player.dart';
import 'package:qiraat_mushaf/ui/jam_screen.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/page_slider.dart';
import 'package:qiraat_mushaf/ui/quran_word_text.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(variants.available);
    // Loaded here, not in a test's own time, so each screen finds them.
    await Manzumat.load();
    await Kharouf.load();
  });

  test('the twenty, Qalun first, each once in each ayah, in their order', () {
    expect(jamOrder.length, 20);
    expect(jamOrder.first, 'qalun');
    expect(jamOrder.last, 'idris');
    expect(jamName('duri_kisai'), 'الدوري عن الكسائي');
    for (final page in [1, 2, 158, 165]) {
      for (final ayah in quran.page(page)) {
        final readings = jamReadings(ayah, variants);
        final all = [for (final r in readings) ...r.riwayat];
        expect(
          all.toSet().length,
          all.length,
          reason: '${ayah.surah}:${ayah.number}',
        );
        expect(all.toSet(), jamOrder.toSet());
        // Each told with the first who reads it, and in the order of the ten.
        final leads = [for (final r in readings) jamOrder.indexOf(r.lead)];
        expect(leads, [...leads]..sort());
        for (final r in readings) {
          expect(
            r.riwayat,
            [...r.riwayat]..sort(
              (a, b) => jamOrder.indexOf(a).compareTo(jamOrder.indexOf(b)),
            ),
          );
          expect(r.words.length, ayah.words.length);
        }
      }
    }
  });

  test('مالك يوم الدين: the readers of «مَٰلِكِ» told apart from «مَلِكِ»', () {
    final ayah = quran.page(1).firstWhere((a) => a.surah == 1 && a.number == 4);
    final readings = jamReadings(ayah, variants);
    final hafs = readings.firstWhere((r) => r.riwayat.contains(hafsId));
    final qalun = readings.firstWhere((r) => r.riwayat.contains('qalun'));
    expect(qalun, isNot(same(hafs)));
    expect(qalun.lead, 'qalun');
    for (final r in readings) {
      // ignore: avoid_print
      print('1:4 ${r.lead}: ${r.words.join(' ')} | ${r.agreeing.join(',')}');
    }
  });

  testWidgets('the screen goes reading by reading, then ayah by ayah', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 1),
      ),
    );
    // The riwayat, the poems and the book loaded.
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('jam-lead')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    expect(find.byKey(const ValueKey('jam-lead')), findsOneWidget);
    expect(find.text('قالون عن نافع'), findsOneWidget);
    expect(
      t
          .widget<IconButton>(find.byKey(const ValueKey('jam-previous')))
          .onPressed,
      isNull,
    );
    bool ticked(String id) =>
        t.widget<Checkbox>(find.byKey(ValueKey('jam-check-$id'))).value!;
    // The arrows point out: the previous to the right, the next to the left.
    expect(
      (t.widget<IconButton>(find.byKey(const ValueKey('jam-previous'))).icon
              as Icon)
          .icon,
      Icons.arrow_back_rounded,
    );
    // The first reading's riwayat ticked, the others not yet.
    final first = quran.page(1).first;
    final readings = jamReadings(first, variants);
    for (final id in readings.first.riwayat) {
      expect(ticked(id), isTrue, reason: id);
    }
    expect(ticked(readings.last.riwayat.first), readings.length == 1);
    for (var i = 1; i < readings.length; i++) {
      await t.tap(find.byKey(const ValueKey('jam-next')));
      await t.pump();
    }
    // All read: the twenty ticked.
    for (final id in jamOrder) {
      expect(ticked(id), isTrue, reason: id);
    }
    // The last reading of the first ayah, then the second ayah from Qalun,
    // the board anew.
    await t.tap(find.byKey(const ValueKey('jam-next')));
    await t.pump();
    expect(find.text('قالون عن نافع'), findsOneWidget);
    expect(
      t.widget<ChoiceChip>(find.byKey(const ValueKey('jam-ayah-1'))).selected,
      isTrue,
    );
    final second = jamReadings(quran.page(1)[1], variants);
    if (second.length > 1) {
      final other = second.last.riwayat.first;
      expect(ticked(other), isFalse);
      // A riwaya tapped on the board: its reading shown.
      await t.tap(find.byKey(ValueKey('jam-board-$other')));
      await t.pump();
      expect(find.text(jamName(second.last.lead)), findsOneWidget);
      expect(ticked(other), isTrue);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the hamesh in usul and farsh; under an asl, the riwayat\'s '
      'manhaj, shut until opened', (t) async {
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 1),
      ),
    );
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('jam-lead')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    // صراط الذين أنعمت عليهم: Qalun's silah of the mim, an asl.
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('jam-ayah-6')),
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('jam-strip-1')),
        matching: find.byType(Scrollable),
      ),
    );
    t.widget<ChoiceChip>(find.byKey(const ValueKey('jam-ayah-6'))).onSelected!(
      true,
    );
    await t.pump();
    expect(find.text('قالون عن نافع'), findsOneWidget);
    expect(find.byKey(const ValueKey('jam-usul')), findsOneWidget);
    final asl = find.byKey(const ValueKey('jam-asl-صلة ميم الجمع'));
    expect(asl, findsOneWidget);
    final table = find.byKey(const ValueKey('jam-manhaj-table-صلة ميم الجمع'));
    expect(table, findsNothing);
    final open = find.text('منهج الرواة في هذا الأصل');
    await t.ensureVisible(open.first);
    await t.tap(open.first);
    await t.pumpAndSettle();
    expect(table, findsOneWidget);
    // Every riwaya of the jam' in it once, those who read alike in one row,
    // named together: Hafs with all who read without the silah.
    const prefix = 'jam-manhaj-word-صلة ميم الجمع-';
    final groups = [
      for (final e
          in find
              .descendant(of: table, matching: find.byType(Column))
              .evaluate())
        if (e.widget.key case ValueKey<String>(value: final k)
            when k.startsWith(prefix))
          k.substring(prefix.length).split(','),
    ];
    expect([for (final g in groups) ...g]..sort(), [...jamOrder]..sort());
    expect(groups.length, lessThan(jamOrder.length));
    List<String> groupOf(String id) => groups.firstWhere((g) => g.contains(id));
    expect(groupOf(hafsId), contains('warsh'));
    expect(groupOf('qalun'), isNot(contains(hafsId)));
    // Hafs and Shu'bah alike: named by their qari, عاصم.
    expect(groupOf(hafsId), contains('shubah'));
    final names = t.widget<Text>(
      find.byKey(
        ValueKey('jam-manhaj-names-صلة ميم الجمع-${groupOf(hafsId).join(',')}'),
      ),
    );
    final told = names.textSpan!.toPlainText();
    expect(told, contains('عاصم'));
    expect(told, isNot(contains('حفص عن')));
    String word(String id) => [
      for (final w in t.widgetList<QuranWordText>(
        find.descendant(
          of: find.byKey(ValueKey('$prefix${groupOf(id).join(',')}')),
          matching: find.byType(QuranWordText),
        ),
      ))
        w.text,
    ].join(' ');
    String face(String id) => t
        .widget<Text>(
          find.byKey(
            ValueKey('jam-manhaj-face-صلة ميم الجمع-${groupOf(id).join(',')}'),
          ),
        )
        .data!;
    expect(word('qalun'), contains('مُۥ'));
    expect(word(hafsId), isNot(contains('مُۥ')));
    // Hafs's own way named, not «كحفص».
    expect(face(hafsId), 'بإسكان ميم الجمع دون صلة');
    expect(
      find.descendant(of: table, matching: find.text('كحفص')),
      findsNothing,
    );
    await t.tap(open.first);
    await t.pumpAndSettle();
    expect(table, findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the small page: an ayah touched read from, any page gone to, '
      'the ayahs numbered as the riwaya read counts them', (t) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 1),
      ),
    );
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('jam-lead')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    bool chosen(int i) =>
        t.widget<ChoiceChip>(find.byKey(ValueKey('jam-ayah-$i'))).selected;
    // Qalun first: al-Fatiha counted as the Madinans count it, the basmala
    // not an ayah, «ٱلۡحَمۡدُ» the first.
    expect(find.text('قالون عن نافع'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('jam-ayah-1')),
        matching: find.text('${quran.surah(1).nameAr} 1'),
      ),
      findsOneWidget,
    );
    // An ayah touched on the small page: the jam' from it.
    final page = t.widget<MushafPage>(
      find.descendant(
        of: find.byKey(const ValueKey('jam-page')),
        matching: find.byType(MushafPage),
      ),
    );
    page.onWordTap(quran.page(1)[3], 0);
    await t.pump();
    final fourth = quran.page(1)[3];
    expect(
      find.byKey(ValueKey('ayah-shade:${fourth.surah}:${fourth.number}:0')),
      findsOneWidget,
    );
    expect(
      find.text(
        'القراءة 1 من ${jamReadings(quran.page(1)[3], variants).length}',
      ),
      findsOneWidget,
    );
    // The slider below: another page, from its first ayah.
    t.widget<PageSlider>(find.byKey(const ValueKey('jam-page-slider'))).onGo(5);
    await t.pump();
    expect(find.textContaining('• ص 5'), findsOneWidget);
    expect(chosen(0), isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('on its side: the page large beside the reading', (t) async {
    t.view.physicalSize = const Size(900, 420);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 3),
      ),
    );
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('jam-lead')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    expect(find.byKey(const ValueKey('jam-landscape-page')), findsOneWidget);
    // As wide as two fifths of the screen, not a thumbnail.
    expect(
      t.getSize(find.byKey(const ValueKey('jam-page'))).width,
      greaterThan(300),
    );
    // Beside it, not below it.
    expect(
      t.getRect(find.byKey(const ValueKey('jam-page'))).top,
      lessThan(t.getRect(find.byKey(const ValueKey('jam-lead'))).top),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('at the end of the page, on to the next from its first ayah', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 1),
      ),
    );
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('jam-lead')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    final steps = [
      for (final a in quran.page(1)) jamReadings(a, variants).length,
    ].fold(0, (a, b) => a + b);
    for (var i = 0; i < steps; i++) {
      await t.tap(find.byKey(const ValueKey('jam-next')));
      await t.pump();
    }
    expect(find.textContaining('• ص 2'), findsOneWidget);
    expect(
      t.widget<ChoiceChip>(find.byKey(const ValueKey('jam-ayah-0'))).selected,
      isTrue,
    );
    expect(find.text('قالون عن نافع'), findsOneWidget);
    // And back: the last reading of the page before.
    await t.tap(find.byKey(const ValueKey('jam-previous')));
    await t.pump();
    expect(find.textContaining('• ص 1'), findsOneWidget);
    final n = jamReadings(quran.page(1).last, variants).length;
    expect(find.text('القراءة $n من $n'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the small page shades the ayah; the cited words numbered', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 3),
      ),
    );
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('jam-lead')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    // Qalun in al-Baqarah 6: «عَلَيۡهِمُۥ» and «تُنذِرۡهُمُۥ» with their bayts.
    expect(find.byKey(const ValueKey('jam-page')), findsOneWidget);
    final first = quran.page(3).first;
    expect(
      find.byKey(ValueKey('ayah-shade:${first.surah}:${first.number}:0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('jam-number-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('jam-number-2')), findsOneWidget);
    // In brackets over the word.
    expect(
      t.widget<Text>(find.byKey(const ValueKey('jam-number-1'))).data,
      '(١)',
    );
    expect(
      find.textContaining('(١، ٢) الشاطبية', findRichText: true),
      findsWidgets,
    );
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the ayah alone is heard, not the ones after it', (t) async {
    final player = AyahPlayer.instance;
    final before = player.continuous;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(MushafPalette.light),
        home: JamScreen(quran: quran, variants: variants, page: 1),
      ),
    );
    expect(player.continuous, isFalse);
    await t.pumpWidget(const SizedBox());
    expect(player.continuous, before);
  });
}
