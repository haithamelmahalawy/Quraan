import '../models/quran.dart';
import 'arabic.dart';
import 'manzumat.dart';

/// What the page's key names a general rule, explained: the rule itself, as
/// any reader of it has it. What a riwaya does in it is told by its own rows.
String usulDefinition(String label) =>
    _definitions[label] ??
    (label.contains('الهمزت')
        ? _definitions['الهمزتان']!
        : _definitions['أصول أخرى']!);

const _definitions = {
  'مد البدل':
      'أن يتقدم الهمز على حرف المد في كلمة واحدة، وليس بعد حرف المد همز ولا '
      'سكون، نحو: ءَامَنُواْ، أُوتُواْ، إِيمَٰنًا. وسمي بدلًا لأن حرف المد فيه مبدل '
      'من همزة في أكثر صوره.',
  'مد اللين المهموز':
      'أن تقع الواو أو الياء الساكنتان المفتوح ما قبلهما قبل همزة في كلمة '
      'واحدة، نحو: شَيْءٍ، سَوْءَ، كَهَيْـَٔةِ.',
  'مد اللين المهموز في سوءات':
      'مد اللين في واو «سَوْءَٰتِ» وما تصرف منها، وفيها مع البدل الذي بعدها '
      'أوجه خاصة.',
  'مستثنيات مد اللين المهموز':
      'كلمات من اللين المهموز خرجت عن حكم بابها، فلا يجري عليها ما يجري على '
      'نظائرها.',
  'المدود':
      'زيادة في مد حرف المد عن مقدار المد الطبيعي، لسبب من همز أو سكون، أو '
      'قصره على مقداره الأصلي.',
  'المد المنفصل': 'أن يقع حرف المد آخر كلمة والهمز أول الكلمة التي بعدها، نحو: بِمَآ أُنزِلَ.',
  'المد المتصل':
      'أن يقع حرف المد والهمز بعده في كلمة واحدة، نحو: جَآءَ، سُوٓءَ.',
  'قصر المنفصل':
      'قراءة المد المنفصل بمقدار حركتين، من غير زيادة على المد الطبيعي.',
  'النقل':
      'نقل حركة الهمزة إلى الحرف الساكن قبلها مع حذف الهمزة، والساكن آخر كلمة '
      'والهمزة أول التي بعدها، ومنه لام التعريف، نحو: قَدَ اَفْلَحَ، اَ۬لَارْضِ.',
  'التقليل':
      'النطق بالفتحة بين الفتح والإمالة، وبالألف بين الألف والياء، ويسمى بين '
      'اللفظين وبين بين والإمالة الصغرى.',
  'الإمالة':
      'أن تنحو بالفتحة نحو الكسرة وبالألف نحو الياء من غير قلب خالص، وتسمى '
      'الإمالة الكبرى والإضجاع.',
  'الفتح': 'النطق بالفتحة والألف بعدها من غير إمالة ولا تقليل.',
  'إبدال الهمز':
      'جعل الهمزة حرفًا خالصًا: ألفًا أو واوًا أو ياءً، بحسب حركتها وحركة ما '
      'قبلها، نحو: يُومِنُونَ، يَاكُلُونَ، بِيسَ.',
  'الهمزات':
      'تخفيف الهمزة المفردة، بإبدالها أو تسهيلها أو حذفها، خلاف تحقيقها.',
  'تحقيق الهمز': 'النطق بالهمزة كاملة من مخرجها، من غير تخفيف.',
  'تسهيل الهمز':
      'النطق بالهمزة بينها وبين الحرف المجانس لحركتها: الألف مع الفتحة، والواو '
      'مع الضمة، والياء مع الكسرة، ويسمى بين بين.',
  'الهمزتان':
      'اجتماع همزتين متلاصقتين: الأولى للاستفهام أو غيره والثانية من بنية '
      'الكلمة، أو كل واحدة منهما من كلمة. وللقراء فيهما التحقيق، والتسهيل، '
      'والإبدال، والإدخال وهو ألف تفصل بينهما.',
  'الهمزتان من كلمتين':
      'أن تكون الأولى آخر كلمة والثانية أول التي بعدها، نحو: جَآءَ أَحَدَكُمُ، '
      'هَٰٓؤُلَآءِ إِن. وهما متفقتان في الحركة أو مختلفتان.',
  'همزة هأنتم':
      'الهمزة بعد «ها» التنبيه في «هَٰٓأَنتُمْ»، وفيها مذاهب خاصة بها.',
  'همزة الاستفهام مع همزة الوصل':
      'أن تدخل همزة الاستفهام على همزة وصل بعدها لام التعريف، نحو: ءَآلذَّكَرَيْنِ، '
      'ءَآللَّهُ، ءَآلْـَٰٔنَ، فلا تحذف همزة الوصل لئلا يلتبس الخبر بالاستفهام.',
  'وقف هشام على الهمز':
      'تخفيف الهمزة المتطرفة عند الوقف عليها، بالإبدال أو التسهيل بالروم، على '
      'ما في باب وقف حمزة وهشام.',
  'ترقيق الراء': 'النطق بالراء نحيفة، لا يمتلئ الفم بصداها.',
  'تغليظ اللام': 'تسمين اللام حتى يمتلئ الفم بصداها.',
  'صلة ميم الجمع':
      'وصل ميم الجمع المضمومة بواو لفظية في الوصل عند من يقرأ بها.',
  'ميم الجمع':
      'الميم الدالة على الجمع في «هُم» و«كُم»، وحركتها عند الساكن بعدها.',
  'صلة هاء الضمير':
      'وصل هاء الضمير المذكر الغائب بواو لفظية إن كانت مضمومة، وبياء لفظية إن '
      'كانت مكسورة.',
  'هاء الكناية':
      'هاء الضمير الدالة على المفرد المذكر الغائب، وحكمها في الحركة والصلة.',
  'ياءات الزوائد':
      'الياءات المتطرفة الزائدة في التلاوة على رسم المصحف، فلا تكتب فيه، نحو: '
      'ٱلدَّاعِ، يَهْدِينِ.',
  'ياءات الإضافة':
      'ياء المتكلم الزائدة على بنية الكلمة، المرسومة في المصحف، ويختلف القراء في '
      'فتحها وإسكانها، نحو: إِنِّيٓ، وَجْهِيَ.',
  'الإدغام':
      'إدخال حرف في حرف بحيث يصيران حرفًا واحدًا مشددًا، فيما تقارب أو تجانس '
      'منهما.',
  'الإدغام الكبير': 'إدغام الحرف المتحرك فيما بعده، مثلًا كان أو متقاربًا.',
  'الإدغام بلا غنة': 'إدغام النون الساكنة والتنوين في حرف من غير إظهار الغنة.',
  'السكت': 'قطع الصوت زمنًا يسيرًا من غير تنفس، بنية مواصلة القراءة.',
  'السكت قبل الهمز':
      'السكت على الحرف الساكن قبل الهمز، بقطع الصوت زمنًا يسيرًا من غير تنفس.',
  'ترك السكت': 'وصل الكلمة بما بعدها من غير سكت في مواضع يسكت فيها غيره.',
  'الإشمام':
      'خلط حركة بأخرى: ضم الفاء مع الكسر في نحو: قِيلَ، وَسِيقَ، أو نحو ذلك، '
      'على ما في بابه.',
  'إشمام الصاد': 'خلط صوت الصاد بصوت الزاي، نحو: ٱلصِّرَٰطَ.',
  'هاء السكت': 'هاء ساكنة تلحق آخر الكلمة في الوقف لبيان حركة ما قبلها.',
  'الوقف على مرسوم الخط':
      'الوقف على الكلمة بحسب رسمها في المصحف، إثباتًا أو حذفًا أو إبدالًا.',
  'التقاء الساكنين': 'تحريك أول الساكنين عند التقائهما، وحركته عند القراء.',
  'أصول أخرى':
      'قواعد عامة عند هذا الراوي لم يعين لها باب مستقل في مفتاح الصفحة؛ انظر '
      'الوصف عند كل نوع.',
};

/// The kind of [label] a reading is, by the Hafs word [hafs] it is read on:
/// the divisions of the chapter. Other rules are divided by their description.
/// [changedHamza]: its hamza is itself read otherwise (a naql in the word).
String usulKindOf(
  String label,
  Variant v,
  String hafs, {
  bool changedHamza = false,
  bool lastOfAyah = false,
}) {
  final letters = lettersOf(hafs);
  final kind = switch (label) {
    'مد البدل' => _badalKind(letters, changedHamza),
    'النقل' => _naqlKind(v, hafs),
    'التقليل' || 'الإمالة' => _imalaKind(v, hafs, lastOfAyah),
    'ترقيق الراء' => _tarqiqKind(letters),
    'تغليظ اللام' => _taghlizKind(letters),
    'مد اللين المهموز' => _linKind(letters),
    _ => null,
  };
  return kind ?? (v.description.isEmpty ? 'بلا وصف مسجل' : v.description);
}

bool _isHamza(String letter) =>
    'ءأإؤئآ'.contains(letter[0]) || RegExp('[ٕٔ]').hasMatch(letter);

/// «وَمَا بَعْدَ هَمْزٍ ثَابِتٍ أَوْ مُغَيَّرٍ».
String? _badalKind(List<String> letters, bool changedHamza) {
  for (var i = 0; i < letters.length; i++) {
    final h = letters[i];
    if (!_isHamza(h)) continue;
    final next = i + 1 < letters.length ? letters[i + 1] : '';
    final String? madd = h.startsWith('آ') || h.contains('ٰ') || h.contains('ٓ')
        ? 'الألف'
        : h.contains('َ') && next.startsWith('ا')
        ? 'الألف'
        : h.contains('ُ') && next.startsWith('و')
        ? 'الواو'
        : h.contains('ِ') && (next.startsWith('ي') || next.startsWith('ى'))
        ? 'الياء'
        : h.contains('ۧ')
        ? 'الياء'
        : null;
    if (madd != null) {
      return 'حرف المد $madd بعد همز ${changedHamza ? 'مغيَّر بالنقل' : 'ثابت'}';
    }
  }
  // ٱلنَّبِيِّـۧنَ, read with the hamza and its ya (ٱلنَّبِيٓـِٕينَ).
  if (!letters.any(_isHamza) &&
      letters.any((l) => l.startsWith('ب') && l.contains('ِ'))) {
    return 'حرف المد الياء بعد همز ثابت';
  }
  // Its alif unwritten (ٱلۡأَخِرَةِ, لَأَيَةٗ): on the hamza with the fatha. Or
  // read otherwise (إِلۡ يَاسِينَ, read ءَالِ يَاسِينَ).
  return letters.any(_isHamza)
      ? 'حرف المد الألف بعد همز ${changedHamza ? 'مغيَّر بالنقل' : 'ثابت'}'
      : 'صور أخرى';
}

String? _naqlKind(Variant v, String hafs) {
  if (v.rule == 'naql_source') return null;
  if (hafs.startsWith('ٱل') ||
      RegExp('^[وفبك]َ?ٱل|^لِلۡ|^لِل').hasMatch(hafs)) {
    return 'إلى لام التعريف';
  }
  final before = v.usulText.contains(' ') ? v.usulText.split(' ').first : '';
  if (before.isEmpty) return 'إلى الساكن قبلها';
  return RegExp('[ًٌٍٖٗٞ]').hasMatch(before)
      ? 'إلى التنوين قبلها'
      : 'إلى الحرف الساكن آخر الكلمة قبلها';
}

String _imalaKind(Variant v, String hafs, bool lastOfAyah) {
  const marks = '[ً-ٰٟۖ-ۭ]*';
  if (v.stopOnly) return 'عند الوقف فقط';
  if (RegExp('ر$marks[ىاي]$marks\$').hasMatch(hafs)) return 'ذوات الراء';
  if (RegExp(
    '[اٰ]$marks'
    'ر$marks[ِ]',
  ).hasMatch(hafs)) {
    return 'الألف قبل راء مكسورة';
  }
  if (lastOfAyah) return 'رؤوس الآي';
  if (RegExp('ى$marks\$').hasMatch(hafs)) return 'ذوات الياء';
  return 'ألفاظ أخرى';
}

String? _tarqiqKind(List<String> letters) {
  for (var i = 1; i < letters.length; i++) {
    if (!letters[i].startsWith('ر')) continue;
    final before = letters[i - 1];
    if (before.startsWith('ي') && !RegExp('[َُِ]').hasMatch(before)) {
      return 'بعد ياء ساكنة أو مدية';
    }
    if (before.contains('ِ')) return 'بعد كسرة لازمة';
    if (RegExp('[ْۡ]').hasMatch(before) &&
        i >= 2 &&
        letters[i - 2].contains('ِ')) {
      return 'بعد كسرة بينهما ساكن';
    }
  }
  return null;
}

String? _taghlizKind(List<String> letters) {
  for (var i = 1; i < letters.length; i++) {
    if (!letters[i].startsWith('ل')) continue;
    final before = letters[i - 1];
    final name = switch (before[0]) {
      'ص' => 'الصاد',
      'ط' => 'الطاء',
      'ظ' => 'الظاء',
      _ => null,
    };
    if (name != null) {
      return 'بعد $name ${RegExp('[ْۡ]').hasMatch(before) ? 'الساكنة' : 'المفتوحة'}';
    }
  }
  return null;
}

String? _linKind(List<String> letters) {
  for (var i = 0; i + 1 < letters.length; i++) {
    if (!_isHamza(letters[i + 1])) continue;
    if (letters[i].startsWith('ي')) return 'اللين بالياء';
    if (letters[i].startsWith('و')) return 'اللين بالواو';
  }
  return null;
}

/// The chapter(s) of the poems a label is taught in, without their marks.
RegExp? usulChapterPattern(String label) => switch (label) {
  'مد البدل' ||
  'مد اللين المهموز' ||
  'مد اللين المهموز في سوءات' ||
  'مستثنيات مد اللين المهموز' ||
  'المدود' ||
  'المد المنفصل' ||
  'المد المتصل' ||
  'قصر المنفصل' => RegExp('المد والقصر'),
  'النقل' ||
  'السكت' ||
  'السكت قبل الهمز' ||
  'ترك السكت' => RegExp('نقل|النقل والسكت'),
  'التقليل' || 'الإمالة' || 'الفتح' => RegExp('الفتح والإمالة'),
  'إبدال الهمز' ||
  'الهمزات' ||
  'تحقيق الهمز' ||
  'تسهيل الهمز' => RegExp('الهمز المفرد|الهمزتين|الهمزتان'),
  'الهمزتان من كلمتين' => RegExp('الهمزت(ين|ان) من كلمتين'),
  'ترقيق الراء' => RegExp('الراء'),
  'تغليظ اللام' => RegExp('اللامات'),
  'صلة ميم الجمع' || 'ميم الجمع' || 'إشمام الصاد' => RegExp('أم القرآن'),
  'صلة هاء الضمير' || 'هاء الكناية' => RegExp('هاء الكناية'),
  'ياءات الزوائد' => RegExp('الزوائد'),
  'ياءات الإضافة' => RegExp('الإضافة'),
  'الإدغام' => RegExp('الإدغام|الإظهار|ذكر|قربت'),
  'الإدغام الكبير' => RegExp('الإدغام الكبير'),
  'الإدغام بلا غنة' => RegExp('النون الساكنة'),
  'وقف هشام على الهمز' => RegExp('وقف حمزة|النقل والسكت'),
  'هاء السكت' || 'الوقف على مرسوم الخط' => RegExp('المرسوم'),
  final l when l.contains('الهمزت') => RegExp('الهمزت(ين|ان) من كلمة'),
  _ => null,
};

/// [bayt]'s chapter is where [label] is taught.
bool isUsulChapter(String label, Bayt bayt) =>
    usulChapterPattern(label)?.hasMatch(_bareChapter(bayt.chapter)) ?? true;

String _bareChapter(String chapter) =>
    chapter.replaceAll(RegExp('[ً-ْٰ]'), '').replaceAll(RegExp(r'\s+'), ' ');

/// The first chapter of [poem] teaching [label], its verses to read whole
/// when none is named for the riwaya; empty when no chapter is known.
List<Bayt> usulChapterVerses(Manzumat manzumat, Poem poem, String label) {
  if (usulChapterPattern(label) == null) return const [];
  final chapter = manzumat
      .chapters(poem)
      .where((c) => usulChapterPattern(label)!.hasMatch(_bareChapter(c)))
      .firstOrNull;
  if (chapter == null) return const [];
  return [
    for (final b in manzumat.verses(poem))
      if (b.chapter == chapter) b,
  ];
}
