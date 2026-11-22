import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';

// «ٱرۡكَب مَّعَنَا» (هود ٤٢): the idgham in the usul for those who read as
// Hafs, Qalun's, al-Bazzi's and Khallad's two faces kept; the izhar of the
// rest in the usul too, «(بالإظهار)» beside it, no hamesh row (the user,
// 2026-11-21; till then in the hamesh).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('irkab ma\'ana: idgham in the usul, izhar in the hamesh', () async {
    final variants = await VariantRepository.discover();
    const idgham = [
      'qunbul',
      'duri_abuamr',
      'susi',
      'shubah',
      'abul_harith',
      'duri_kisai',
      'ruways',
      'rawh',
    ];
    const both = ['qalun', 'bazzi', 'khallad'];
    const izhar = [
      'warsh',
      'hisham',
      'ibn_dhakwan',
      'khalaf_hamzah',
      'ishaq',
      'idris',
      'ibn_wardan',
      'ibn_jammaz',
    ];
    await variants.ensureLoaded([...idgham, ...both, ...izhar]);
    for (final id in [...idgham, ...both, ...izhar]) {
      final v = variants.at([id], 11, 42, 13).where((v) => v.word == 13).single;
      if (izhar.contains(id)) {
        expect(v.inHamesh, isFalse, reason: id);
        expect(v.rule, 'idgham_saghir', reason: id);
        expect(v.description, 'بالإظهار', reason: id);
        expect(v.bandNote, 'بالإظهار', reason: id);
      } else {
        expect(v.inHamesh, isFalse, reason: id);
        expect(v.rule, 'idgham_saghir', reason: id);
        if (idgham.contains(id)) {
          expect(v.description, 'بإدغام الباء في الميم', reason: id);
        }
      }
    }
  });
}
