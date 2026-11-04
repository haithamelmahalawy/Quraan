import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/ui/partition_marker.dart';
 
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final edition in MushafEdition.values) {
    test(
      'all 240 quarters and 30 juz are retained in ${edition.name}',
      () async {
        final q = await QuranRepository.load(null, edition);
        final ayahs = [
          for (final s in q.surahs)
            for (var a = 1; a <= s.ayahCount; a++) q.ayah(s.number, a),
        ];
        expect(ayahs.where((a) => a.juzStart), hasLength(30));
        expect(
          ayahs.where((a) => a.rubStart != null).map((a) => a.rubStart),
          List.generate(240, (i) => i + 1),
        );
        expect(q.ayah(2, 142).rubStart, 9);
        expect(PartitionMarker.label(q.ayah(2, 142)), 'بداية الجزء 2');
        expect(PartitionMarker.label(q.ayah(2, 26)), 'ربع الحزب 1');
      },
    );
  }
}
