import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  // «وَلِـِّۧيَ» (الأعراف ١٩٦), the Hafs text unchanged.
  const word = 'وَلِـِّۧيَ';

  test('the shadda over the small ya is drawn apart, above it', () {
    expect(HafsFontMarks.needsAdjustment(word), isTrue);
    expect(shaddaOverSmallYaLift, lessThan(0));
    // Not where a shadda has no small ya with it.
    expect(HafsFontMarks.needsAdjustment('ٱللَّهِ'), isFalse);
  });

  test(
    'the dagger alif of «طَٰٓئِفٞ» stands beside the ta, its madd on it',
    () {
      const taif = 'طَٰٓئِفٞ';
      expect(HafsFontMarks.needsAdjustment(taif), isTrue);
      expect(taDaggerDrop, greaterThan(taDaggerMaddDrop));
    },
  );

  testWidgets('the word keeps its letters, the shadda painted apart', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HafsFontMarks(
            parts: const [(word, null)],
            style: const TextStyle(fontFamily: 'Hafs', fontSize: 40),
            builder: (parts) => Text.rich(
              TextSpan(
                children: [for (final (s, _) in parts) TextSpan(text: s)],
              ),
            ),
          ),
        ),
      ),
    );
    // The shadda out of the text, painted over its tooth.
    final shown = t.widget<Text>(find.byType(Text)).textSpan!.toPlainText();
    expect(shown, isNot(contains('ّ')));
    expect(shown, contains('ۧ'));
    expect(find.bySemanticsLabel(word), findsOneWidget);
  });
}
