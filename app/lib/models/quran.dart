class Surah {
  const Surah({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.ayahCount,
    required this.startPage,
  });

  final int number;
  final String nameAr;
  final String nameEn;
  final int ayahCount;
  final int startPage;
}

class Ayah {
  Ayah({
    required this.surah,
    required this.number,
    required this.page,
    required this.juz,
    required this.words,
  });

  final int surah;
  final int number;
  final int page;
  final int juz;

  /// Hafs words (KFGQPC Uthmanic encoding), without the ayah number.
  final List<String> words;

  /// The same words as glyphs of the QCF V2 page font (empty for a word
  /// drawn together with the previous one), and the ayah-end ornament.
  List<String>? glyphs;
  String? endGlyph;
}

/// Word-level difference between a riwaya and Hafs.
class Variant {
  const Variant({
    required this.riwayaId,
    required this.surah,
    required this.ayah,
    required this.word,
    required this.count,
    required this.text,
    required this.kind,
    this.description = '',
    this.rule = '',
  });

  final String riwayaId;
  final int surah;
  final int ayah;

  /// Index of the first Hafs word in the ayah.
  final int word;

  /// Number of Hafs words the reading replaces (usually 1).
  final int count;

  /// The words as read in this riwaya (empty when the words are dropped).
  final String text;
  final VariantKind kind;

  /// How the reading differs, in Arabic: "بالتاء", "بضم الهاء", ...
  final String description;

  /// The recitation rule it applies, for readings made by applying a rule
  /// to the Hafs text (tool/build_usul.dart): 'badal' (madd al-badal),
  /// 'tarqiq' (of the ra), 'taghliz' (of the lam), 'sakt'; empty otherwise.
  final String rule;

  /// A reading with imala (or taqlil, the lesser imala).
  bool get isImala =>
      text.contains('۪') ||
      RegExp(r'إمالة|الإمالة|تقليل|التقليل|بين بين|بين اللفظين')
          .hasMatch(description);

  /// Shown in green, like imala: madd al-badal.
  bool get isBadal => rule == 'badal';

  /// Shown in orange: tarqiq of the ra, taghliz of the lam.
  bool get isTarqiqOrTaghliz => rule == 'tarqiq' || rule == 'taghliz';

  /// Written and read as Hafs on the page: Khalaf's idgham without ghunna
  /// in the waw and the ya is all that differs. Told only in the readings
  /// of the word.
  bool get readsAsHafs => rule == 'ghunna';

  /// Sakt (Khalaf) before a hamza, on ال and on شيء.
  bool get isSakt => rule == 'sakt';

  /// A reading by one of the riwaya's general rules (usul) alone: imala or
  /// taqlil (with the madd that goes with it), madd al-badal, tarqiq,
  /// taghliz, sakt. The page explains these once by their colour instead
  /// of a note at each word.
  bool get isUsul =>
      rule.isNotEmpty ||
      (isImala && (description.isEmpty || _imalaOnly.hasMatch(description)));

  static final _imalaOnly = RegExp(
    r'^(ب?ال|ب)?(إمالة|تقليل)( الألف| الراء والألف)?'
    r'( و?مدها \d حركات| ومد المتصل \d حركات| والقصر)?$',
  );
}

enum VariantKind {
  /// Letters or vowels differ (farsh, ya'at al-idafa, ...).
  farsh('f', 'الفرش والحركات', 'Letters & vowels'),

  /// Hamza handled differently (ibdal, tasheel, naql, isqat).
  hamza('h', 'الهمزات', 'Hamza'),

  /// Only recitation marks differ: madd, silah, imala, idgham.
  usul('u', 'المدود والإمالة والصلة والإدغام', 'Madd, imala, silah, idgham');

  const VariantKind(this.code, this.labelAr, this.labelEn);

  final String code;
  final String labelAr;
  final String labelEn;

  static VariantKind fromCode(String code) =>
      values.firstWhere((k) => k.code == code);
}
