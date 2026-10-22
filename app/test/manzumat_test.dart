import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Manzumat manzumat;
  late List<String> surahs;
  late Kharouf book;
  setUpAll(() async {
    manzumat = await Manzumat.load();
    book = await Kharouf.load();
    surahs = [for (final s in (await QuranRepository.load()).surahs) s.nameAr];
  });

  Reference ref(
    String riwaya,
    int surah,
    String hafs, {
    String text = '',
    String description = '',
    String rule = '',
    VariantKind kind = VariantKind.farsh,
  }) => manzumat.referenceOf(
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
    expect(
      ref('hisham', 2, 'يَكۡذِبُونَ', text: 'يُكَذِّبُونَ').mention,
      contains(446),
    );
    // مَلِكِ (1:4): the Shatibiyya for the seven, the Durrah for Abu Ja'far.
    expect(ref('hisham', 1, 'مَٰلِكِ', text: 'مَلِكِ').mention, contains(108));
    final durrah = ref('ibn_wardan', 1, 'مَٰلِكِ', text: 'مَلِكِ');
    expect(durrah.poem, Poem.durrah);
    expect(durrah.mention, contains(10));
  });

  test('the usul: the chapter of the rule', () {
    String chapter(
      String riwaya, {
      String description = '',
      String rule = '',
    }) => ref(
      riwaya,
      2,
      'ءَامَنُواْ',
      description: description,
      rule: rule,
      kind: VariantKind.usul,
    ).chapter;
    expect(skeleton(chapter('warsh', rule: 'badal')), contains('لمد'));
    expect(skeleton(chapter('warsh', rule: 'tarqiq')), contains('لرت'));
    expect(skeleton(chapter('warsh', rule: 'taghliz')), contains('للمت'));
    expect(skeleton(chapter('khalaf_hamzah', rule: 'sakt')), contains('نقل'));
    expect(
      skeleton(chapter('duri_kisai', description: 'بالإمالة')),
      contains('لمله'),
    );
  });

  Variant reading({
    String rule = 'naql',
    int ayah = 4,
    int word = 9,
    VariantKind kind = VariantKind.usul,
  }) => Variant(
    riwayaId: 'warsh',
    surah: 2,
    ayah: ayah,
    word: word,
    count: 1,
    text: '',
    kind: kind,
    rule: rule,
  );

  test('book citations take priority and stay within the selected rule', () {
    final v = reading();
    final r = manzumat.referenceOf(
      v,
      'بالآخرة',
      2,
      surahs,
      entries: book.at(2, 4, 9),
    );
    expect(r.fromBook, isTrue);
    expect(r.mention, {226});
    expect(r.bookExplanation[226], contains('بنقل حركة الهمزة'));
    // The same note quotes madd al-badal and Hamzah's sakt as well.
    // They belong to the other rules, rather than this naql selection.
    final badal = manzumat.referenceOf(
      reading(rule: 'badal'),
      'بالآخرة',
      2,
      surahs,
      entries: book.at(2, 4, 9),
    );
    expect(badal.mention, {171, 172});
    expect(badal.fromBook, isTrue);
  });

  test('quotations spanning bayts retain both and exclude the other poem', () {
    expect(
      manzumat.quotedVerses(
        Poem.shatibiyya,
        'وما بعد همز ثابت أو مغير، فقصر وقد يروى لورش مطولا، '
        'ووسطه قوم كآمن هؤلاء، ءآلهة آتى للإيمان مثلا',
      ),
      {171, 172},
    );
    expect(manzumat.quotedVerses(Poem.shatibiyya, 'يخدعون اعلم حجى'), isEmpty);
    expect(manzumat.quotedVerses(Poem.durrah, 'يخدعون اعلم حجى'), contains(62));
    expect(manzumat.quotedVerses(Poem.shatibiyya, 'الله'), isEmpty);
  });

  test(
    'two-word hamza rules select that chapter rather than one-word hamzas',
    () {
      for (final rule in ['tasheel_pair', 'ibdal_waw', 'ibdal_ya']) {
        final r = ref(
          'warsh',
          2,
          'السفهاء ألا',
          rule: rule,
          kind: VariantKind.usul,
        );
        expect(skeleton(r.chapter), contains(skeleton('كلمتين')));
        expect(r.mention, isNotEmpty);
        expect(r.mention.every((n) => n >= 202 && n <= 213), isTrue);
      }
      expect(
        ref(
          'warsh',
          2,
          'ءأنذرتهم',
          rule: 'tasheel_word',
          kind: VariantKind.usul,
        ).mention,
        {183, 184},
      );
    },
  );

  test('unknown words and common prose are never a whole-chapter proof', () {
    expect(ref('warsh', 2, 'كلمةغيرموجودة').mention, isEmpty);
    expect(ref('warsh', 2, 'الله الذين').mention, isEmpty);
  });

  test(
    'every Shatibiyya bayt has sourced commentary, including shared passages',
    () {
      for (final b in manzumat.verses(Poem.shatibiyya)) {
        final e = manzumat.explanation(Poem.shatibiyya, b.n);
        expect(e, isNotNull, reason: 'Bayt ${b.n}');
        expect(e!.text.length, greaterThan(20));
        expect(e.source, contains('أبو شامة'));
        expect(e.url, startsWith('https://'));
        expect(e.group, contains(b.n));
      }
      expect(
        manzumat.explanation(Poem.shatibiyya, 183)!.text,
        isNot(manzumat.explanation(Poem.shatibiyya, 226)!.text),
      );
      expect(manzumat.explanation(Poem.durrah, 183), isNull);
    },
  );
}
