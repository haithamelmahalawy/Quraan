import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'arabic.dart';

/// One verse of a poem: its number, its chapter and its two halves.
typedef Bayt = ({int n, String chapter, String sadr, String ajz});

/// The poems the riwayat are read by.
enum Poem {
  shatibiyya('الشاطبية', 'حرز الأماني ووجه التهاني، للإمام الشاطبي'),
  durrah('الدرة', 'الدرة المضية في القراءات الثلاث، لابن الجزري');

  const Poem(this.nameAr, this.title);
  final String nameAr;
  final String title;

  /// The Durrah for Abu Ja'far, Ya'qub and Khalaf al-'Ashir; the Shatibiyya
  /// for the seven.
  static Poem of(String riwaya) =>
      const {'abu_jafar', 'yaqub', 'khalaf'}.contains(qiraaOf(riwaya).id)
      ? Poem.durrah
      : Poem.shatibiyya;
}

/// Where a reading is stated in its poem: the chapter, its verses, and the
/// verses that mention the word (found by its letters; the evidence of the
/// reading is among them, or elsewhere in the chapter).
typedef Reference = ({
  Poem poem,
  String chapter,
  List<Bayt> verses,
  Set<int> mention,
});

/// The Shatibiyya and the Durrah (assets/data/manzumat.json, built by
/// tool/build_manzumat.dart from Quranpedia's books), and the place of a
/// reading in them.
class Manzumat {
  Manzumat._(this._verses);

  final Map<Poem, List<Bayt>> _verses;

  static const source = 'الموسوعة القرآنية quranpedia.net';

  static Future<Manzumat>? _loading;

  static Future<Manzumat> load([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<Manzumat> _load(AssetBundle bundle) async {
    final json = jsonDecode(await bundle.loadString('assets/data/manzumat.json'))
        as Map<String, dynamic>;
    List<Bayt> verses(String key) => [
      for (final v in json[key] as List)
        (
          n: v[0] as int,
          chapter: v[1] as String,
          sadr: v[2] as String,
          ajz: v[3] as String,
        ),
    ];
    return Manzumat._({
      Poem.shatibiyya: verses('shatibiyya'),
      Poem.durrah: verses('durrah'),
    });
  }

  List<Bayt> verses(Poem poem) => _verses[poem]!;

  /// The chapters of [poem], in order.
  List<String> chapters(Poem poem) => [
    ...{for (final v in verses(poem)) v.chapter},
  ];

  /// Where [reading] (of [hafs], the Hafs word(s), in surah [surah]) is
  /// stated, with the surah names of the mushaf ([surahNames], 1-based by
  /// number - 1) to find the chapter of the farsh.
  Reference referenceOf(
    Variant reading,
    String hafs,
    int surah,
    List<String> surahNames,
  ) {
    final poem = Poem.of(reading.riwayaId);
    final chapter =
        _usulChapter(poem, reading) ??
        _surahChapter(poem, surah, surahNames) ??
        chapters(poem).first;
    final inChapter = [
      for (final v in verses(poem))
        if (v.chapter == chapter) v,
    ];
    // The verses that name the word (by its letters, either text).
    final keys = {
      for (final w in [...hafs.split(' '), ...reading.text.split(' ')])
        if (skeleton(w).length >= 3) skeleton(w),
    };
    bool names(Bayt v) => '${v.sadr} ${v.ajz}'
        .split(' ')
        .map(skeleton)
        .any((w) => keys.any((k) => w.contains(k) || (w.length >= 3 && k.contains(w))));
    return (
      poem: poem,
      chapter: chapter,
      verses: inChapter,
      mention: {for (final v in inChapter) if (names(v)) v.n},
    );
  }

  /// The chapter of the usul a reading belongs to, by its rule or by the
  /// words of its description.
  String? _usulChapter(Poem poem, Variant v) {
    final d = v.description;
    final topics = <String>[
      if (v.rule == 'badal') 'المد',
      if (v.rule == 'tarqiq') 'الراء',
      if (v.rule == 'taghliz') 'اللام',
      if (v.rule == 'sakt' || d.contains('سكت')) 'نقل',
      if (v.isImala) 'الإمالة',
      if (d.contains('ميم الجمع')) 'أم القرآن', // the mim al-jam' is there
      if (d.contains('هاء') && d.contains('صلة')) 'الكناية',
      if (d.contains('إدغام') || d.contains('ادغام')) 'الإدغام',
      if (d.contains('تسهيل') || d.contains('الهمزتين') || d.contains('الهمزة الثانية'))
        'الهمزتين',
      if (d.contains('نقل')) 'نقل',
      if (d.contains('إبدال') || d.contains('بالهمز')) 'الهمز المفرد',
      if (d.contains('المد') || d.contains('مد ') || d.contains('القصر')) 'المد',
      if (d.contains('الياء') && (d.contains('فتح') || d.contains('إسكان')))
        'الإضافة',
      if (d.contains('إثبات الياء') || d.contains('بإثبات ياء')) 'الزوائد',
    ];
    if (v.kind == VariantKind.farsh && v.rule.isEmpty && !v.isImala) {
      return null; // a farsh: the chapter of its surah
    }
    final all = chapters(poem);
    for (final t in topics) {
      final hit = all.where((c) => skeleton(c).contains(skeleton(t))).firstOrNull;
      if (hit != null) return hit;
    }
    return null;
  }

  /// The chapter of the farsh of [surah]: the one naming it, or covering it
  /// («ومن سورة الأحقاف إلى سورة الرحمن»).
  String? _surahChapter(Poem poem, int surah, List<String> surahNames) {
    // Surah numbers named in a chapter title, in order.
    List<int> named(String title) {
      final t = skeleton(title);
      final found = <(int, int)>[];
      for (var s = 1; s <= surahNames.length; s++) {
        final k = skeleton(surahNames[s - 1]);
        if (k.length < 2) continue;
        final at = t.indexOf(k);
        if (at >= 0) found.add((at, s));
      }
      if (t.contains('ملقرن')) found.add((0, 1)); // أم القرآن
      if (t.contains('خرلقرن')) found.add((t.length, 115)); // آخر القرآن
      found.sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final f in found) f.$2];
    }

    for (final c in chapters(poem)) {
      final s = named(c);
      if (s.isEmpty) continue;
      // «ومن سورة … إلى سورة …»: from the first up to the last, excluded.
      final range = c
          .replaceAll(RegExp('[ً-ْٰ]'), '')
          .contains('إلى');
      if (range && s.length >= 2 && surah >= s.first && surah < s.last) return c;
      if (!range && s.contains(surah)) return c;
    }
    return null;
  }
}
