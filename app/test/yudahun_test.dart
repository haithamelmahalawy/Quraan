import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

// «يُضَٰهُونَ» (التوبة ٣٠): every reader who drops its hamza has it in the usul,
// «حذف الهمزة», as Abu Ja'far, and in the hamesh too (the user, 2026-11-14).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'yudahun in the usul and the hamesh for all who drop the hamza',
    () async {
      final variants = await VariantRepository.discover();
      const ids = [
        'qalun',
        'warsh',
        'bazzi',
        'qunbul',
        'duri_abuamr',
        'susi',
        'hisham',
        'ibn_dhakwan',
        'khalaf_hamzah',
        'khallad',
        'abul_harith',
        'duri_kisai',
        'ibn_wardan',
        'ibn_jammaz',
        'ruways',
        'rawh',
        'ishaq',
        'idris',
      ];
      await variants.ensureLoaded(ids);
      for (final id in ids) {
        final rows = variants.at([id], 9, 30, 13).where((v) => v.word == 13);
        final usul = rows
            .where((v) => !v.inHamesh && v.kind == VariantKind.hamza)
            .toList();
        expect(usul, hasLength(1), reason: id);
        final u = usul.single;
        expect(u.kind, VariantKind.hamza, reason: id);
        expect(u.rule, 'hamza_hadhf', reason: id);
        expect(u.description, 'بضم الهاء وحذف الهمزة', reason: id);
        expect(
          rows.where((v) => v.inHamesh && v.kind == VariantKind.farsh),
          hasLength(1),
          reason: id,
        );
      }
    },
  );
}
