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
    this.certified = false,
    this.bookHow = '',
    this.bookFarsh = false,
    this.bookWujuh = '',
    this.stopOnly = false,
    this.usulText = '',
    this.usulWays = const [],
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
  /// 'kharouf' when the reading comes from the certified source alone.
  final String rule;

  /// Stated by the certified source, «التسهيل لقراءات التنزيل»: this riwaya
  /// reads the word differently from Hafs.
  final bool certified;

  /// How the certified source words the reading (بتسهيل الهمزة الثانية),
  /// told in place of [description] once [certified]; may be empty.
  final String bookHow;

  /// Stated in the farsh of the certified source (ya' al-idafa, عليهُم, ...),
  /// not only among its imala or idgham.
  final bool bookFarsh;

  /// The riwaya's two ways, as the certified source states them
  /// (بوجهين: الأول كحفص، والثاني: «بَيْئَسٍ»); empty when it has one.
  final String bookWujuh;

  /// This rule applies on stopping, rather than in continuous recitation.
  final bool stopOnly;

  /// Both Hafs words of a rule at a word boundary (also across ayahs).
  final String usulText;

  /// The accepted ways of this general rule, shown once in its margin key.
  final List<String> usulWays;

  String? get hamzaReplacement => switch (rule) {
    'ibdal_waw' => 'و',
    'ibdal_ya' => 'ي',
    _ => null,
  };

  /// Told in the hamesh: the riwaya's farsh, and what the certified source
  /// states in its farsh. Usul are told by their colour, in the page's key.
  bool get inHamesh =>
      !isUsul &&
      !(rule.isNotEmpty && rule != 'kharouf') &&
      (bookFarsh || (!isUsul && (certified || kind == VariantKind.farsh)));

  /// The short explanation to show: the riwaya file's (بفتح النون وتشديد
  /// الجيم), else the certified source's wording.
  String get shownDescription => [
    description.isNotEmpty ? description : bookHow,
    bookWujuh,
  ].where((s) => s.isNotEmpty).join('، ');

  Variant withCertified([
    String how = '',
    bool farsh = false,
    String wujuh = '',
  ]) => Variant(
    riwayaId: riwayaId,
    surah: surah,
    ayah: ayah,
    word: word,
    count: count,
    text: text,
    kind: kind,
    description: description,
    rule: rule,
    certified: true,
    bookHow: how,
    bookFarsh: farsh,
    // Retain an explicitly reviewed ordering/wording of the book's faces.
    bookWujuh: bookWujuh.isNotEmpty ? bookWujuh : wujuh,
    stopOnly: stopOnly,
    usulText: usulText,
    usulWays: usulWays,
  );

  /// A reading with imala (or taqlil, the lesser imala).
  bool get isImala =>
      (text.contains('۪') &&
          !const {
            'tasheel_word',
            'tasheel_pair',
            'hamza_wasl',
            'ha_antum',
          }.contains(rule)) ||
      RegExp(r'إمالة|الإمالة|تقليل|التقليل|بين اللفظين')
          .hasMatch(description) ||
      (description.contains('بين بين') &&
          !RegExp('همز|تسهيل').hasMatch(description));

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
  /// taghliz, sakt, and the rest of the usul kind (silah, idgham, madd).
  /// The page explains these once by their colour instead
  /// of a note at each word.
  bool get isUsul =>
      (rule.isNotEmpty && rule != 'kharouf') ||
      (kind == VariantKind.usul && rule != 'kharouf') ||
      isQasr ||
      (isImala && (description.isEmpty || _imalaOnly.hasMatch(description))) ||
      _onlyGeneralRules(description);

  /// Qasr of the separated madd (Qalun, Ibn Kathir, al-Susi): بِمَا أُنزِلَ.
  bool get isQasr => description == 'بالقصر';

  static final _imalaOnly = RegExp(
    r'^(ب?ال|ب)?(إمالة|تقليل)( الألف| الراء والألف)?'
    r'( و?مدها \d حركات| ومد المتصل \d حركات| والقصر)?$',
  );

  // A source may combine silah, hamza handling and madd in a row tagged
  // farsh. A remaining lexical/vowel change keeps it a farsh reading.
  static bool _onlyGeneralRules(String description) {
    if (description.isEmpty) return false;
    final plain = description.replaceAll(RegExp('[ً-ٰٟ]'), '');
    final rest = plain
        .replaceAll(_generalRules, '')
        .replaceAll(RegExp(r'[بو،\s]'), '');
    return rest.isEmpty;
  }

  static final _generalRules = RegExp(
    r'صلة (ميم الجمع|الميم|هاء الضمير|الهاء)|ترك صلة الهاء|'
    r'تخفيف الهمزة|تسهيل الهمزة( الثانية| الأولى)?( بين بين)?|'
    r'إبدال الهمزة( الثانية| الأولى)? (ألفا|واوا|ياء)( خالصة| خالصا| مكسورة| مفتوحة)?( وصلا)?|حذف الهمزة|'
    r'نقل حركة الهمزة (إلى اللام|إليها)|'
    r'ثلاثة البدل|مد البدل|الإمالة|التقليل|الإدغام|المد|القصر',
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
