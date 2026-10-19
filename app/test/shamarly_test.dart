import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Mushafs mushafs;
  setUpAll(() async => mushafs = await Mushafs.load());

  /// Where each text line of [page] starts: "surah:ayah:word".
  List<String> starts(QuranRepository q, int page) => [
        for (final l in q.lines(page)!)
          if (l is TextLine && l.words.isNotEmpty)
            '${l.words.first.$1.surah}:${l.words.first.$1.number}:${l.words.first.$2}',
      ];

  test('the Shamarly pages: 2 to 522, 15 lines, every word once', () {
    final q = mushafs.shamarly;
    expect((q.firstPage, q.lastPage), (2, 522));
    var words = 0;
    for (var p = q.firstPage; p <= q.lastPage; p++) {
      final lines = q.lines(p)!;
      if (p > 3) expect(lines.fold(0, (n, l) => n + l.span), 15, reason: '$p');
      for (final l in lines) {
        if (l is TextLine) words += l.words.length;
      }
    }
    expect(words, 77430);
    // Al-Fatiha on the right of the open mushaf, page 2.
    expect(q.isRightPage(2), isTrue);
  });

  test('pages and ayahs start and end as printed', () {
    final q = mushafs.shamarly;
    // Page 4 of the print, ayah by ayah (its lines 1–10).
    expect(starts(q, 4).take(10), [
      '2:5:0', '2:6:0', '2:6:9', '2:7:7', '2:8:2', //
      '2:9:0', '2:9:8', '2:10:6', '2:11:3', '2:12:2',
    ]);
    // Page 42: the end of Al-Baqarah, a two-line header, the basmala, then
    // Al Imran from its first line.
    final lines = q.lines(42)!;
    final header = lines.indexWhere((l) => l is SurahNameLine);
    expect((lines[header] as SurahNameLine).surah, 3);
    expect(lines[header].span, 2);
    expect(lines[header + 1], isA<BasmalaLine>());
    expect(starts(q, 42).skip(6).take(6),
        ['3:1:0', '3:3:3', '3:4:2', '3:4:13', '3:5:8', '3:6:7']);
    expect(q.surah(3).startPage, 42);
    // A page that starts inside an ayah (2:16, word 5).
    expect(starts(q, 5).first, '2:16:5');
    expect(q.pageOf(2, 16), 4);
  });

  test('the place read carries over between the mushafs', () {
    // Al Imran opens page 50 of the Madinah mushaf, page 42 of the Shamarly.
    expect(mushafs.convert(50, MushafEdition.madani, MushafEdition.shamarly), 42);
    // Back: page 42 opens with 2:286 (from its 2nd line), on Madinah page 49.
    expect(mushafs.convert(42, MushafEdition.shamarly, MushafEdition.madani), 49);
    expect(mushafs.convert(1, MushafEdition.madani, MushafEdition.shamarly), 2);
  });
}
