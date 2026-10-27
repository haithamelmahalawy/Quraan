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

  /// Reading-independent quarter boundary (1..240), and juz boundary.
  int? rubStart;
  bool juzStart = false;

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
    this.stopText = '',
    this.marginText = '',
    this.ownWays = false,
    this.omission = false,
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

  /// Only an explicit raw farsh omission may erase a word. A blank book note
  /// or a rule without written text is an annotation, never a Quran deletion.
  bool get canReplaceText =>
      !stopOnly &&
      (text.isNotEmpty ||
          omission ||
          (kind == VariantKind.farsh && rule.isEmpty && description.isEmpty));
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

  /// Reviewed stopping form, shown in the margin without changing wasl text.
  final String stopText;

  /// How the margin writes the reading when the page keeps the rasm form
  /// (أَاءِنَّا beside the page's أَٰءِنَّا); empty otherwise.
  final String marginText;

  /// The note tells the riwaya's ways itself: the certified source's ways
  /// (when they belong to another word of the place) are not added.
  final bool ownWays;

  /// An explicitly reviewed lexical omission, rather than an empty annotation.
  final bool omission;

  /// Both Hafs words of a rule at a word boundary (also across ayahs).
  final String usulText;

  /// The accepted ways of this general rule, shown once in its margin key.
  final List<String> usulWays;

  String? get hamzaReplacement => switch (rule) {
    'ibdal_waw' => 'و',
    'ibdal_ya' => 'ي',
    'tasheel_pair'
        when riwayaId == 'warsh' &&
            usulText.contains(' ') &&
            RegExp(r'ءِ[ۖ-ۭ]*$').hasMatch(usulText.split(' ').first) &&
            usulText.split(' ').last.startsWith('إِ') =>
      'ي',
    _ => null,
  };

  /// Told in the hamesh: the riwaya's farsh, and what the certified source
  /// states in its farsh. Usul are told by their colour, in the page's key.
  bool get inHamesh =>
      rule == 'comparison' ||
      rule == 'reviewed_farsh' ||
      !isUsul &&
          !(rule.isNotEmpty && rule != 'kharouf') &&
          (bookFarsh || (!isUsul && (certified || kind == VariantKind.farsh)));

  /// The short explanation to show: the riwaya file's (بفتح النون وتشديد
  /// الجيم), else the certified source's wording.
  String get shownDescription {
    // The opposite reading shown beside Yaqub is malik without the alif.
    // Do not repeat an unrelated preceding-mim explanation at this word.
    if (surah == 1 && ayah == 4 && word == 0 && text == 'مَلِكِ') {
      return 'بحذف الألف';
    }
    final own = description.isNotEmpty ? description : bookHow;
    // Ways the riwaya's own note already tells are not told again.
    return [
      own,
      if (!own.contains('بوجهين')) bookWujuh,
    ].where((s) => s.isNotEmpty).join('، ');
  }

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
    // A certified tanween change stays farsh even when its source also
    // mentions a madd face and originally tagged the row as usul.
    kind: farsh && rule.isEmpty && description.contains('تنوين')
        ? VariantKind.farsh
        : kind,
    description: description,
    rule: rule,
    certified: true,
    bookHow: how,
    bookFarsh: farsh,
    // Retain an explicitly reviewed ordering/wording of the book's faces.
    bookWujuh: bookWujuh.isNotEmpty || ownWays ? bookWujuh : wujuh,
    stopOnly: stopOnly,
    stopText: stopText,
    marginText: marginText,
    ownWays: ownWays,
    omission: omission,
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

  /// Lesser imala that applies only when stopping on this word.
  bool get isStoppingTaqlil =>
      stopOnly && isImala && description.contains('تقليل');

  /// Shown in green, like imala: madd al-badal.
  bool get isBadal => rule == 'badal';

  bool get isLinHamz =>
      const {'lin_hamz', 'lin_hamz_exception', 'lin_hamz_sawat'}.contains(rule);

  /// Shown in orange: tarqiq of the ra, taghliz of the lam.
  bool get isTarqiqOrTaghliz => rule == 'tarqiq' || rule == 'taghliz';

  /// A source reminder of a rule's exception, not a difference from Hafs.
  bool get isMarginNote =>
      riwayaId == 'warsh' &&
      text.isEmpty &&
      RegExp('لا ترقق راؤه.*أعجمي').hasMatch('$description $bookHow');

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
      rule != 'comparison' &&
      rule != 'reviewed_farsh' &&
      ((rule.isNotEmpty && rule != 'kharouf') ||
          (kind == VariantKind.usul && rule != 'kharouf') ||
          isQasr ||
          (isImala &&
              (description.isEmpty || _imalaOnly.hasMatch(description))) ||
          _onlyGeneralRules(description));

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
