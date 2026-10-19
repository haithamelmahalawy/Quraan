import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Manzumat manzumat;
  late List<String> surahs;
  setUpAll(() async {
    manzumat = await Manzumat.load();
    surahs = [for (final s in (await QuranRepository.load()).surahs) s.nameAr];
  });

  Reference ref(String riwaya, int surah, String hafs,
          {String text = '', String description = '', String rule = '',
          VariantKind kind = VariantKind.farsh}) =>
      manzumat.referenceOf(
        Variant(
          riwayaId: riwaya,
          surah: surah,
          ayah: 1,
          word: 0,
          count: 1,
          text: text,
          kind: kind,
          description: description,
          rule: rule,
        ),
        hafs,
        surah,
        surahs,
      );

  test('the whole of both poems', () {
    expect(manzumat.verses(Poem.shatibiyya), hasLength(1173));
    expect(manzumat.verses(Poem.durrah).length, greaterThanOrEqualTo(240));
  });

  test('a farsh: the chapter of its surah, the verse naming the word', () {
    final r = ref('warsh', 2, 'يَخۡدَعُونَ', text: 'يُخَٰدِعُونَ');
    expect((r.poem, r.chapter), (Poem.shatibiyya, 'سُوْرَةُ الْبَقَرَةِ'));
    expect(r.mention, contains(445));
    expect(ref('hisham', 2, 'يَكۡذِبُونَ', text: 'يُكَذِّبُونَ').mention, contains(446));
    // مَلِكِ (1:4): the Shatibiyya for the seven, the Durrah for Abu Ja'far.
    expect(ref('hisham', 1, 'مَٰلِكِ', text: 'مَلِكِ').mention, contains(108));
    final durrah = ref('ibn_wardan', 1, 'مَٰلِكِ', text: 'مَلِكِ');
    expect(durrah.poem, Poem.durrah);
    expect(durrah.mention, contains(10));
  });

  test('the usul: the chapter of the rule', () {
    String chapter(String riwaya, {String description = '', String rule = ''}) =>
        ref(riwaya, 2, 'ءَامَنُواْ',
                description: description, rule: rule, kind: VariantKind.usul)
            .chapter;
    expect(skeleton(chapter('warsh', rule: 'badal')), contains('لمد'));
    expect(skeleton(chapter('warsh', rule: 'tarqiq')), contains('لرت'));
    expect(skeleton(chapter('warsh', rule: 'taghliz')), contains('للمت'));
    expect(skeleton(chapter('khalaf_hamzah', rule: 'sakt')), contains('نقل'));
    expect(skeleton(chapter('duri_kisai', description: 'بالإمالة')), contains('لمله'));
  });
}
