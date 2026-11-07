import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a word\'s witnesses found once are given again as they were', () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['qalun']);
    final poems = await Manzumat.load();
    final names = [for (final s in quran.surahs) s.nameAr];
    final ayah = quran.page(1).firstWhere((a) => a.number == 4);
    final reading = variants
        .allOf('qalun')
        .firstWhere((v) => v.surah == 1 && v.ayah == 4 && v.word == 0);
    final first = poems.referenceOf(reading, ayah.words.first, 1, names);
    final again = poems.referenceOf(reading, ayah.words.first, 1, names);
    expect(identical(first, again), isTrue);
    expect(first.verses, isNotEmpty);
  });
}
