import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the tanween as the Madinah mushaf writes it before the next word', () {
    // Izhar: stacked; ikhfa' and idgham: offset; iqlab: the mim.
    expect(tanweenBefore('كُفُؤٗا', 'أَحَدُۢ'), 'كُفُؤًا');
    expect(tanweenBefore('حَسَنًا يُضَٰعِفۡهُ', null), 'حَسَنٗا يُضَٰعِفۡهُ');
    expect(tanweenBefore('مُوصَدَةٌ', 'فِي'), 'مُوصَدَةٞ');
    expect(tanweenBefore('عَلِيمٌ', 'بِمَا'), 'عَلِيمُۢ');
    expect(tanweenBefore('شَيۡءٍ', 'بَصِيرٌ'), 'شَيۡءِۭ');
    expect(tanweenBefore('عَذَابٌ', 'عَظِيمٞ'), 'عَذَابٌ');
    expect(tanweenBefore('عَذَابٌ', null), 'عَذَابٌ');
    // Put on the letter before the alef; the iqlab mim already written.
    expect(tanweenBefore('قِيَماً', 'وَٱرۡزُقُوهُمۡ'), 'قِيَمٗا');
    expect(tanweenBefore('نُشْرَۢا', 'بَيۡنَ'), 'نُشْرَۢا');
  });

  test('Hafs\'s own text is left as it is', () async {
    final quran = await QuranRepository.load();
    final wrong = <String>[];
    for (final s in quran.surahs) {
      final words = [
        for (var a = 1; a <= s.ayahCount; a++) ...quran.ayah(s.number, a).words,
      ];
      // The end of a surah is joined to the basmala.
      words.add('بِسۡمِ');
      for (var i = 0; i + 1 < words.length; i++) {
        if (tanweenBefore(words[i], words[i + 1]) != words[i]) {
          wrong.add('${s.number}: ${words[i]} ${words[i + 1]}');
        }
      }
    }
    expect(wrong, isEmpty);
  });
}
