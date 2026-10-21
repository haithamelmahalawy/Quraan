import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

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

  test('Shu\'bah with Hafs: farsh in the hamesh, as the book states it', () async {
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(['shubah']);
    Variant at(int s, int a, int w) => variants.at(['shubah'], s, a, w).single;
    // 2:72 «فادارأتم»: as Hafs.
    expect(variants.at(['shubah'], 2, 72, 3), isEmpty);
    // 2:51 «اتخذتم»: idgham, not a shadda.
    expect(at(2, 51, 6).description, 'بإدغام الذال في التاء');
    // Ya' al-idafa: farsh, in the hamesh (بيتي، وجهي، معي، أجري).
    for (final (s, a, w) in [(2, 125, 17), (3, 20, 4), (9, 83, 11), (10, 72, 7)]) {
      expect(at(s, a, w).description, 'بإسكان الياء');
      expect(at(s, a, w).inHamesh, isTrue);
    }
    // 2:143 «رؤف»: nothing of Hamzah's stop or Warsh's badal.
    expect(at(2, 143, 43).shownDescription, 'بحذف الواو');
    // 2:271 «فنعما» and 7:165 «بئيس»: both ways.
    expect(at(2, 271, 3).shownDescription, contains('باختلاس كسرة العين'));
    expect(at(7, 165, 14).shownDescription, contains('الأول كحفص'));
  });
}
