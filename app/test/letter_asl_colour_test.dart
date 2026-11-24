import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  late MutashabihatRepository mutashabihat;

  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    quran = await QuranRepository.load();
    mutashabihat = await MutashabihatRepository.load();
    await Manzumat.load();
    await Kharouf.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(['khalaf_hamzah']);
  });

  // Hamza's «ءَاتَىٰنِيۡ» (مريم ٣٠): the ya of the idafa quiet colours the word,
  // the leaned ta green over it (the user, 2026-11-24).
  testWidgets('a letter\'s asl keeps its colour in a word of another asl', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final settings = ReaderSettings.memory(selected: {'khalaf_hamzah'});
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MushafPage(
              page: 307,
              quran: quran,
              variants: variants,
              mutashabihat: mutashabihat,
              settings: settings,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final word = t.widget<InkText>(find.byKey(const ValueKey('word:19:30:4')));
    final parts = word.parts!;
    final green = parts.where((p) => p.$2 == MushafColors.green).toList();
    expect(green, hasLength(1));
    expect(green.single.$1, startsWith('ت'));
    expect(
      parts.where((p) => p.$1.trim().isNotEmpty && p.$2 == MushafColors.multi),
      isNotEmpty,
    );
    expect(t.takeException(), isNull);
  });
}
