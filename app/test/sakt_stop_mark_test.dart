import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/ui/hafs_font_marks.dart';

/// The sin of the sakt after a word ending in a stop sign: drawn past the
/// sign, clear of it, whatever the sign (شَيۡۜءٍۜۖ، فَٰرِغًۜاۖ; the user,
/// 2026-11-24).
void main() {
  lamHamza();
  setUpAll(() async {
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

  Future<String> shown(WidgetTester t, String word) async {
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HafsFontMarks(
            parts: [(word, null)],
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
    return t.widget<Text>(find.byType(Text)).textSpan!.toPlainText();
  }

  testWidgets('room past every stop sign', (t) async {
    for (final word in [
      'شَيۡۜءٍۜۖ',
      'فَٰرِغًۜاۖ',
      'أَعۡجَبَكُمۡۜۗ',
      'قَوۡلُهُمۡۜۘ',
      'ءَانِفًۜاۚ',
      'عَلَيۡهُمۡۜۛ',
      'رَحِيمٌۜۙ',
    ]) {
      expect(await shown(t, word), endsWith('$saktPastStop '), reason: word);
    }
  });

  testWidgets('none without a stop sign', (t) async {
    final text = await shown(t, 'عَذَابٌۜ');
    expect(text, endsWith(' '));
    expect(text, isNot(endsWith('$saktPastStop ')));
  });
}

/// «لَأَتٖ» (العنكبوت ٥), drawn for Khalaf's idgham: its hamza between the lam
/// and the alif, not on the alif (the user, 2026-11-24).
void lamHamza() {
  test('the hamza of «لَأَتٖ» drawn apart over the lam-alif', () {
    expect(HafsFontMarks.needsAdjustment('لَأَتٖۚ'), isTrue);
  });
}
