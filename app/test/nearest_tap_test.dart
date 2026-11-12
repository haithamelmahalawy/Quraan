import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/ui/mushaf_lines.dart';

/// On a weak phone some taps were lost: they fell in the gap of a justified
/// line or on an ayah's ornament, outside every word. A line gives such a
/// tap to its nearest word; a tap on a word stays the word's own.
void main() {
  late Mushafs mushafs;
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
    mushafs = await Mushafs.load();
  });

  testWidgets('a tap between words goes to the nearest word', (t) async {
    final quran = mushafs.of(MushafEdition.madani);
    final ayah = quran.ayah(99, 1);
    // Four short boxes spread over the whole width: wide gaps between them.
    final line = TextLine([for (var w = 0; w < 4; w++) (ayah, w)]);
    final own = <int>[], nearest = <int>[];
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            child: MushafLines(
              lines: [line],
              centered: false,
              quran: quran,
              marker: (_) => null,
              wordMarker: (_, _) => null,
              wordBuilder: (a, w, size, kashida) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => own.add(w),
                child: SizedBox(
                  key: ValueKey('word-$w'),
                  width: 30,
                  height: 20,
                ),
              ),
              onTapNearest: (a, w) => nearest.add(w),
            ),
          ),
        ),
      ),
    );
    // On a word: its own tap alone.
    await t.tap(find.byKey(const ValueKey('word-1')));
    await t.pump();
    expect(own, [1]);
    expect(nearest, isEmpty);
    // Just to the left of word 1 (a right-to-left line: its gap there):
    // still word 1, the nearest; not lost.
    final one = t.getRect(find.byKey(const ValueKey('word-1')));
    await t.tapAt(Offset(one.left - 8, one.center.dy));
    await t.pump();
    expect(own, [1]);
    expect(nearest, [1]);
    // Just to the right of word 2: word 2.
    final two = t.getRect(find.byKey(const ValueKey('word-2')));
    await t.tapAt(Offset(two.right + 8, two.center.dy));
    await t.pump();
    expect(nearest, [1, 2]);
  });
}
