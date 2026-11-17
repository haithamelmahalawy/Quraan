import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // «فَٱسۡجُدُواْ لِلَّهِ وَٱعۡبُدُواْ۩» (النجم ٦٢) centred, opened by the end of
  // ayah 61; the line before ends on «سَٰمِدُونَ» (the user, 2026-11-17).
  test('al-Najm 62 centred and opened by the end of 61', () async {
    final quran = await QuranRepository.load();
    final lines = quran.lines(528)!.whereType<TextLine>().toList();
    final i = lines.indexWhere(
      (l) => l.words.isNotEmpty && l.words.first.$1.number == 62,
    );
    final line = lines[i];
    expect(line.centered, isTrue);
    expect(line.leadingEnd?.number, 61);
    expect(lines[i - 1].endMoved, isTrue);
    expect(lines[i - 1].words.last.$1.number, 61);
    expect(
      lines.where((l) => l.endMoved || l.leadingEnd != null).length,
      2,
    );
  });
}
