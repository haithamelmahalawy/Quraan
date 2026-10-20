import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the certified source: who reads what, with its verses', () async {
    final book = await Kharouf.load();
    // 1:4 «مالك»: عاصم، الكسائي، يعقوب، خلف; «مَلِك» the others.
    final malik = book.at(1, 4, 0).single;
    final hafs = malik.readings.firstWhere((r) => r.readsAsHafs);
    expect(hafs.riwayat, containsAll(['shubah', 'abul_harith', 'ruways', 'ishaq']));
    final other = malik.readings.firstWhere((r) => !r.readsAsHafs);
    expect(other.riwayat, containsAll(['qalun', 'warsh', 'bazzi', 'hisham']));
    expect(malik.verses, isNotEmpty);
  });

  test('riwayat readings certified, and the book\'s own added', () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['warsh', 'qalun']);
    // 2:9 «يُخادعون» (Nafi'): certified.
    final warsh = variants.at(['warsh'], 2, 9, 5).toList();
    expect(warsh, isNotEmpty);
    expect(warsh.every((v) => v.certified), isTrue);
    // 2:29 «وَهْوَ» (al-Kisa'i): stated by the book, missing from Quranpedia.
    await variants.ensureLoaded(['abul_harith']);
    final kisai = variants.at(['abul_harith'], 2, 29, 15).toList();
    expect(kisai.map((v) => v.rule), contains('kharouf'));
    expect(kisai.single.certified, isTrue);
  });
}
