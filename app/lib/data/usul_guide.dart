import '../models/quran.dart';
import 'arabic.dart';
import 'lin_hamz.dart';
import 'manzumat.dart';

/// The chapter a label of the page's key is explained in, without the kind it
/// names apart: «مد اللين المهموز (مع مد البدل)».
String usulGuideLabel(String label) => label.startsWith('مد اللين المهموز')
    ? 'مد اللين المهموز'
    : label.startsWith('الهمزتان من كلمة (')
    ? 'الهمزتان من كلمة'
    : label.startsWith('الهمزتان من كلمتين (')
    ? 'الهمزتان من كلمتين'
    : label.startsWith('الهمز المفرد (')
    ? 'الهمز المفرد'
    : label.startsWith('الإشمام (')
    ? 'الإشمام'
    : label;

/// The riwayat already verified, whose usul share one set of chapters: the
/// chapter, its kind, then the faces. Other readers join when verified.
const usulUnifiedRiwayat = {
  'warsh',
  'hisham',
  'ibn_dhakwan',
  'ruways',
  'rawh',
  'hafs',
  'shubah',
  'qalun',
  'bazzi',
  'qunbul',
  'ibn_wardan',
  'ibn_jammaz',
};

/// The words told in «مد الفرق», a kind of «الهمزتان من كلمة»: the
/// interrogative before a wasl hamza (ءَآللَّهُ، ءَآلۡـَٰٔنَ)، and ءَامَنتُمۡ،
/// ءَأَٰلِهَتُنَا.
bool isMaddFarq(Variant v) =>
    usulUnifiedRiwayat.contains(v.riwayaId) &&
    (v.rule == 'hamza_wasl' ||
        v.rule == 'tasheel_word' &&
            (_isAmantum(v) || v.surah == 43 && v.ayah == 58));

bool _isAmantum(Variant v) =>
    v.surah == 7 && v.ayah == 123 ||
    v.surah == 20 && v.ayah == 71 ||
    v.surah == 26 && v.ayah == 49;

/// «الاستفهام المكرر»: the two questions of one sentence (أَءِذَا ... أَءِنَّا),
/// told together under their kind, each reader's way at each.
const repeatedIstifham = {
  '13:5:4',
  '13:5:7',
  '17:49:1',
  '17:49:5',
  '17:98:6',
  '17:98:10',
  '23:82:1',
  '23:82:6',
  '27:67:3',
  '27:67:7',
  '29:28:4',
  '29:29:0',
  '32:10:1',
  '32:10:5',
  '37:16:0',
  '37:16:5',
  '37:53:0',
  '37:53:5',
  '56:47:2',
  '56:47:7',
  '79:10:1',
  '79:11:0',
};

bool isRepeatedIstifham(Variant v) =>
    repeatedIstifham.contains('${v.surah}:${v.ayah}:${v.word}');

const _dammaSecond = {'3:15:1', '38:8:0', '54:25:0'};
const _openSecond = {
  '2:6:5',
  '2:140:13',
  '3:20:13',
  '3:81:20',
  '5:116:6',
  '12:39:2',
  '17:61:9',
  '21:62:1',
  '25:17:8',
  '27:40:24',
  '36:10:2',
  '36:23:0',
  '41:44:8',
  '56:59:0',
  '56:64:0',
  '56:69:0',
  '56:72:0',
  '58:13:0',
  '79:27:0',
  '11:72:2',
  '67:16:0',
  '68:14:0',
};

/// The kind of «الهمزتان من كلمة» a reading is, the same for every reader: by
/// the vowel of the second hamza, in Hafs's word or the riwaya's own.
String twoHamzasKind(Variant v) {
  if (isMaddFarq(v)) return 'مد الفرق';
  if (isRepeatedIstifham(v)) return 'الاستفهام المكرر';
  if (v.description.contains('للساكنين')) return 'أرأيت';
  // أَشَهِدُواْ: Hafs's word has no second hamza; the riwaya's is with a damma.
  if (v.surah == 43 && v.ayah == 19) return 'المفتوحة والمضمومة';
  final pair = RegExp('[ءأإئؤ][ً-ٰٟ]*[^ءأإئؤ]{0,2}?[ءأإئؤ]([ً-ٰٟ]*)');
  final match = pair.firstMatch(v.usulText) ?? pair.firstMatch(v.text);
  // Ruways's rows tell neither the word nor its reading.
  if (match == null && v.riwayaId == 'ruways') {
    final at = '${v.surah}:${v.ayah}:${v.word}';
    return _dammaSecond.contains(at)
        ? 'المفتوحة والمضمومة'
        : _openSecond.contains(at)
        ? 'المفتوحتان'
        : 'المفتوحة والمكسورة';
  }
  final second = match?.group(1) ?? '';
  return second.contains('ِ')
      ? 'المفتوحة والمكسورة'
      : second.contains('ُ')
      ? 'المفتوحة والمضمومة'
      : 'المفتوحتان';
}

/// The kind of «الهمزتان من كلمتين» a reading is, by the vowels of the two
/// hamzas: مفتوحتان، مضمومة فمكسورة...
String twoWordsKind(Variant v) {
  final words = v.usulText.trim().split(RegExp(r'\s+'));
  // Rawh's two, told without their words: ٱلۡبِغَآءِ إِنۡ، ٱلسَّمَآءِ إِلَى.
  if (words.length < 2) return 'مكسورتان';
  final hamza = RegExp('[ءأإئؤ][ً-ٰٟ]*');
  String vowel(String? h) => h == null
      ? ''
      : h.startsWith('إ') || RegExp('[ٍِٖ]').hasMatch(h)
      ? 'كسر'
      : RegExp('[ٌُٞ]').hasMatch(h)
      ? 'ضم'
      : 'فتح';
  final first = vowel(hamza.allMatches(words.first).lastOrNull?.group(0));
  final second = vowel(hamza.firstMatch(words[1])?.group(0));
  if (first == second) {
    return switch (first) {
      'كسر' => 'مكسورتان',
      'ضم' => 'مضمومتان',
      _ => 'مفتوحتان',
    };
  }
  const names = {'فتح': 'مفتوحة', 'ضم': 'مضمومة', 'كسر': 'مكسورة'};
  const seconds = {'فتح': 'مفتوحة', 'ضم': 'مضمومة', 'كسر': 'مكسورة'};
  return '${names[first]} ف${seconds[second]}';
}

/// The order the kinds of «الهمزتان من كلمتين» are told in.
const _twoWordsOrder = [
  'مفتوحتان',
  'مكسورتان',
  'مضمومتان',
  'مضمومة فمكسورة',
  'مفتوحة فمكسورة',
  'مكسورة فمفتوحة',
  'مضمومة فمفتوحة',
  'مفتوحة فمضمومة',
];

/// The order the kinds of «الهمزتان من كلمة» are told in.
const _twoHamzasOrder = [
  'المفتوحتان',
  'المفتوحة والمكسورة',
  'المفتوحة والمضمومة',
  'أرأيت',
  'الاستفهام المكرر',
  'مد الفرق',
];

/// Why a kind has its faces, when the rule tells: [kindName] is its full
/// wording, as [usulKindOf] gives it.
String? usulKindReason(String label, Variant v, String kindName) {
  if (!usulUnifiedRiwayat.contains(v.riwayaId)) return null;
  if (label == 'الهمز المفرد') {
    if (kindName.startsWith('همز «ائتنا»')) {
      return 'تبدأ بهمزة وصل مكسورة فتبدل الساكنة ابتداءً من جنسها، وفي الوصل من '
          'جنس حركة ما قبلها.';
    }
    return switch (kindName) {
      'الإبدال واوًا' => 'تبدل من جنس حركة ما قبلها، وهي الضمة.',
      'الإبدال ألفًا' => 'تبدل من جنس حركة ما قبلها، وهي الفتحة.',
      'الإبدال ياءً' => 'تبدل من جنس حركة ما قبلها، وهي الكسرة.',
      _ => null,
    };
  }
  if (label == 'الهمزتان من كلمة') {
    if (v.rule == 'hamza_wasl') {
      return 'لا تحذف همزة الوصل هنا لئلا يلتبس الخبر بالاستفهام، فتسهل أو تبدل.';
    }
    if (v.riwayaId != 'warsh') return null;
    return switch (twoHamzasKind(v)) {
      'المفتوحتان' =>
        v.description.contains('القصر')
            ? 'بعد الهمزة حرف متحرك، فلا سبب للمد الزائد.'
            : 'بعد الهمزة حرف ساكن، فتمد ٦ حركات لأجله.',
      'المفتوحة والمكسورة' ||
      'المفتوحة والمضمومة' => 'الإبدال خاص بالمفتوحة، فليس لها إلا التسهيل.',
      'أرأيت' =>
        'إذا أبدلت الهمزة ألفًا وقعت قبل الياء الساكنة، فتمد للساكنين.',
      _ => null,
    };
  }
  if (label != 'الهمزتان من كلمتين') return null;
  final kind = twoWordsKind(v);
  final d = v.description;
  if (kind.endsWith('تان')) {
    if (v.riwayaId != 'warsh') return null;
    return d.contains('مد البدل')
        ? 'بعد الهمزة ألف بدل: مع التسهيل تبقى أوجه البدل الثلاثة، ومع الإبدال تجتمع ألفان فتمد أو تقصر.'
        : d.contains('بالسكون الأصلي')
        ? 'النون أصلها السكون وحركتها عارضة: ٦ حركات اعتبارًا بالأصل، وحركتان اعتدادًا بالحركة العارضة.'
        : d.contains('القصر')
        ? 'بعد الهمزة حرف متحرك، فلا سبب للمد الزائد.'
        : d.contains('المد المشبع')
        ? 'بعد الهمزة حرف ساكن، فتمد ٦ حركات لأجله.'
        : null;
  }
  return switch (kind) {
    'مضمومة فمكسورة' =>
      'قولان منقولان، وعن التسهيل كالياء قال الشاطبي: «أقيس».',
    'مفتوحة فمكسورة' => 'تسهل بين الهمزة والياء، ولا موجب للإبدال.',
    'مفتوحة فمضمومة' => 'تسهل بين الهمزة والواو، ولا موجب للإبدال.',
    'مكسورة فمفتوحة' =>
      'تسهيل المفتوحة يقربها من الألف، والألف لا تأتي بعد كسرة، فتبدل ياءً.',
    'مضمومة فمفتوحة' =>
      'تسهيل المفتوحة يقربها من الألف، والألف لا تأتي بعد ضمة، فتبدل واوًا.',
    _ => null,
  };
}

/// The numbered kind a full kind's wording belongs to: its faces, and what
/// divides them, are told under it.
String usulKindGroup(String kind) {
  if (kind.startsWith('بوجهين') || kind.startsWith('مد البدل')) return kind;
  if (kind.startsWith('مد الفرق')) return 'مد الفرق';
  final colon = kind.indexOf(': ');
  final name = colon < 0 ? kind : kind.substring(0, colon);
  return name.endsWith(' قبل ساكن') || name.endsWith(' قبل متحرك')
      ? name.substring(0, name.lastIndexOf(' قبل '))
      : name;
}

/// The place of a numbered kind among [label]'s, before those told by count.
int usulKindRank(String label, String group) {
  final order = label == 'الهمزتان من كلمة'
      ? _twoHamzasOrder
      : label == 'الهمزتان من كلمتين'
      ? _twoWordsOrder
      : const <String>[];
  final at = order.indexOf(group.split('، ').last);
  return at < 0 ? order.length : at;
}

/// Warsh's naql at the head of a word told only as an eased hamza: أَوَاَمِنَ،
/// اَوَلَوْ، اَلْه۪يٰكُمُ، اَلَمْ. مِنسَاتَهُۥ is an ibdal, its row worded alike.
bool isWarshHamzaNaql(Variant v) =>
    v.riwayaId == 'warsh' &&
    v.rule.isEmpty &&
    RegExp(r'^بتخفيف الهمزة( والتقليل)?$').hasMatch(v.description) &&
    !skeleton(v.text).startsWith('منس');

/// رَبَّهُۥٓ (البينة 8): its silah a munfasil when joined to the next sura.
bool isWarshRabbahuMadd(Variant v) =>
    v.riwayaId == 'warsh' &&
    v.description == 'بالمد' &&
    skeleton(v.text).startsWith('رب');

/// أَنَا۠: its last alif read with the madd before a hamza.
bool isWarshAnaMadd(Variant v) =>
    v.riwayaId == 'warsh' && v.description == 'بالمد' && !isWarshRabbahuMadd(v);

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
      'واحدة، نحو: شَيْءٍ، سَوْءَ، كَهَيْـَٔةِ. وخرج عن حكم بابه واو «سَوْءَٰتِ» وما '
      'تصرف منها، ولها مع البدل بعدها أوجه خاصة، والمستثنى: مَوْئِلًا وَٱلْمَوْءُۥدَةُ.',
  'مد أنا':
      'إثبات ألف «أَنَا» في الوصل إذا وقع بعدها همز مفتوح أو مضموم، فتمد مدًا '
      'منفصلًا، نحو: أَنَا۠ أُحْيِۦ، وَأَنَا۠ أَوَّلُ.',
  'المدود':
      'زيادة في مد حرف المد عن مقدار المد الطبيعي، لسبب من همز أو سكون، أو '
      'قصره على مقداره الأصلي.',
  'فواتح السور':
      'أحكام الحروف المقطعة في أوائل السور: مد العين، والسكت على كل حرف، وإظهار '
      'النون وإدغامها، على ما عند كل قارئ.',
  'تاءات البزي':
      'التاءات المشددة في أوائل الأفعال عند البزي، يمد حرف المد قبلها مدًا مشبعًا، '
      'نحو: وَلَا تَّيَمَّمُواْ.',
  'الإخفاء':
      'إخفاء أبي جعفر النون الساكنة والتنوين عند الخاء والغين، إلا ما استثني.',
  'تكبير الختم': 'التكبير من آخر سورة الضحى إلى آخر سورة الناس، رواه البزي.',
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
  'الهمزتان من كلمة':
      'أن تلتقي همزتان في كلمة واحدة، الأولى للاستفهام غالبًا والثانية من بنية '
      'الكلمة، نحو: ءَأَنذَرْتَهُمْ، أَءِذَا، أَءُنزِلَ. ويلحق بها هنا «أَرَءَيْتَ» وما '
      'تصرف منها، لاتفاق وجهيها. وللقراء فيها التحقيق والتسهيل والإبدال والإدخال. ومنها مد الفرق، وهو المد الذي يفرق بين الاستفهام '
      'والخبر: همزة الاستفهام تدخل على همزة الوصل '
      'في «ءَآلذَّكَرَيْنِ» و«ءَآللَّهُ» و«ءَآلْـَٰٔنَ»، فلا تحذف همزة الوصل لئلا يلتبس '
      'الخبر بالاستفهام. ويلحق بها هنا «ءَامَنتُمْ» و«ءَأَٰلِهَتُنَا».',
  'الهمز المفرد':
      'الهمزة التي لم تلاصقها همزة أخرى، متحركة كانت أو ساكنة. ومن تخفيفها إبدالها '
      'حرفًا خالصًا: ألفًا أو واوًا أو ياءً، بحسب حركتها وحركة ما قبلها، نحو: '
      'يُومِنُونَ، يَاكُلُونَ، بِيسَ. ومن المتحرك الهمزة بعد «ها» التنبيه في '
      '«هَٰٓأَنتُمْ»، وفيها مذاهب خاصة بها.',
  'همزة الاستفهام مع همزة الوصل':
      'أن تدخل همزة الاستفهام على همزة وصل بعدها لام التعريف، نحو: ءَآلذَّكَرَيْنِ، '
      'ءَآللَّهُ، ءَآلْـَٰٔنَ، فلا تحذف همزة الوصل لئلا يلتبس الخبر بالاستفهام.',
  'الوقف على الهمز':
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
      'خلط حركة بحركة: ضم الفاء مع الكسر في نحو: قِيلَ، وَسِيقَ. أو خلط حرف بحرف: '
      'صوت الصاد بصوت الزاي في نحو: ٱلصِّرَٰطَ. ومنه إشمام النون في «تَأْمَ۬نَّا» عند حفص.',
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
    'ترقيق الراء' => _tarqiqKind(v, letters),
    'تغليظ اللام' => _taghlizKind(letters),
    'مد اللين المهموز' => _linKind(v, letters),
    'الهمزتان من كلمة' => _twoHamzasGuideKind(v),
    'الهمزتان من كلمتين' when usulUnifiedRiwayat.contains(v.riwayaId) =>
      _twoWordsGuideKind(v),
    'الهمز المفرد' => _singleHamzaKind(v, hafs),
    'الإشمام' =>
      '${v.rule == 'ishmam_sad' ? 'إشمام حرف بحرف' : 'إشمام حركة بحركة'}: '
          '${v.description}',
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

String _tarqiqKind(Variant v, List<String> letters) {
  // بِشَرَرٖ (المرسلات 32): the first ra, open, before the broken second.
  if (v.surah == 77 && v.ayah == 32) return 'المستثنى';
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
  // Warsh's own word has the kasra (نُنشِرُهَا، تُهْجِرُونَ); Hafs's does not.
  return 'بعد كسرة لازمة';
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

String? _linKind(Variant v, List<String> letters) {
  if (v.rule == LinHamz.sawat.rule) {
    return 'مع مد البدل: ${LinHamz.sawat.ways.join('، أو ')}';
  }
  if (v.rule == LinHamz.exception.rule) {
    return 'المستثنى: ${LinHamz.exception.ways.join()}';
  }
  for (var i = 0; i + 1 < letters.length; i++) {
    if (!_isHamza(letters[i + 1])) continue;
    if (letters[i].startsWith('ي')) return 'اللين بالياء';
    if (letters[i].startsWith('و')) return 'اللين بالواو';
  }
  return null;
}

String _singleHamzaKind(Variant v, String hafs) {
  if (v.rule == 'ha_antum') return 'الهمز المتحرك';
  if (v.rule == 'hamza_mutatarrif') return 'الهمز المتطرف';
  // Nafi''s «ٱلنَّبِيٓءُ» and its bab, Warsh's too.
  if (v.rule == 'hamza_zaida') return 'زيادة الهمزة';
  // «وَٱلصَّٰبِـِٔينَ» without it, for Nafi' and Abu Ja'far.
  if (v.rule == 'hamza_hadhf') return 'حذف الهمزة';
  final how = v.description;
  if (v.riwayaId != 'warsh' && how.startsWith('بتخفيف الهمزة - ')) {
    return 'تخفيف الهمزة';
  }
  if (v.riwayaId != 'warsh' && !how.contains('إبدال')) {
    if (RegExp('زيادة الهمزة|^بالهمز').hasMatch(how)) return 'زيادة الهمزة';
    if (how.contains('تشديد')) return 'إدغام الهمزة';
    if (RegExp('حذف الهمزة|^بالباء|^بالهاء').hasMatch(how)) {
      return 'حذف الهمزة';
    }
    if (how.contains('تخفيف')) return 'تخفيف الهمزة';
    if (how.contains('تسهيل')) return 'تسهيل الهمزة';
  }
  // ٱئۡتِنَا، ٱؤۡتُمِنَ: read one way joined and another begun with.
  if (RegExp('^[وف]?َ?ٱ[ئؤ]').hasMatch(hafs)) {
    return 'همز «ائتنا» ابتداءً: ${v.description}';
  }
  final d = v.description;
  return d.contains('واو')
      ? 'الإبدال واوًا'
      : d.contains('ياء')
      ? 'الإبدال ياءً'
      // مِنسَاتَهُۥ is told only as an eased hamza.
      : 'الإبدال ألفًا';
}

String _twoWordsGuideKind(Variant v) {
  final kind = twoWordsKind(v);
  final how = v.usulWays.isEmpty ? v.description : v.usulWays.join('، أو ');
  return '${kind.endsWith('تان') ? 'المتفقتان' : 'المختلفتان'}، $kind: $how';
}

String _twoHamzasGuideKind(Variant v) {
  if (isMaddFarq(v)) return _farqKind(v);
  final how = v.usulWays.isEmpty ? v.description : v.usulWays.join('، أو ');
  final kind = twoHamzasKind(v);
  // Warsh's open hamzas differ by what the changed hamza meets.
  final before = v.riwayaId != 'warsh' || kind != 'المفتوحتان'
      ? ''
      : v.description.contains('القصر')
      ? ' قبل متحرك'
      : ' قبل ساكن';
  return '$kind$before: $how';
}

String _farqKind(Variant v) {
  final bare = skeleton(v.usulText);
  final name = _isAmantum(v)
      ? 'ءامنتم'
      : v.surah == 43
      ? 'ءألهتنا'
      : bare.contains('ذكر')
      ? 'ءالذكرين'
      : bare.contains('لله')
      ? 'ءالله'
      : 'ءالآن';
  final how = v.usulWays.isEmpty ? v.description : v.usulWays.join('، أو ');
  return 'مد الفرق ($name): $how';
}

/// How Hafs reads [chapter] (its key's [label] in full) at the word [hafs],
/// where [v] is another's reading of it there: «بتحقيق الهمزة»، «بالفتح»...
/// Null where the chapter tells no one way of his.
String? hafsWayIn(String chapter, String label, Variant v, String hafs) {
  const marks = '[ً-ٰٟۖ-ۭ]*';
  final amantum =
      v.surah == 7 && v.ayah == 123 ||
      v.surah == 20 && v.ayah == 71 ||
      v.surah == 26 && v.ayah == 49;
  return switch (chapter) {
    'مد البدل' => 'بالقصر حركتين',
    'مد اللين المهموز' => 'دون مد اللين',
    'المدود' => 'بمد المتصل والمنفصل 4 أو 5 حركات',
    'المد المنفصل' || 'قصر المنفصل' => 'بمد المنفصل 4 أو 5 حركات',
    'المد المتصل' => 'بمد المتصل 4 أو 5 حركات',
    'مد أنا' => 'بحذف ألف «أنا» وصلاً',
    'النقل' => 'بتحقيق الهمزة دون نقل',
    'السكت' || 'السكت قبل الهمز' => 'دون سكت',
    'التقليل' || 'الإمالة' => 'بالفتح',
    'ترقيق الراء' => 'بتفخيم الراء',
    'تغليظ اللام' => 'بترقيق اللام',
    'الهمزتان من كلمة' || 'همزة الاستفهام مع همزة الوصل' =>
      v.rule == 'hamza_wasl'
          ? 'بوجهين: إبدال همزة الوصل ألفًا مع المد المشبع 6 حركات، وهو المقدم؛ '
                'أو تسهيلها'
          : amantum
          ? 'بهمزة واحدة على الخبر'
          : 'بتحقيق الهمزتين',
    'الهمزتان من كلمتين' => 'بتحقيق الهمزتين',
    'الهمز المفرد' =>
      label.contains('زيادة الهمزة') || v.rule == 'hamza_zaida'
          ? 'دون همز'
          : label.contains('حذف الهمزة') || v.rule == 'hamza_hadhf'
          ? 'بإثبات الهمزة'
          : 'بتحقيق الهمزة',
    'إبدال الهمز' ||
    'الهمزات' ||
    'تسهيل الهمز' ||
    'تحقيق الهمز' => 'بتحقيق الهمزة',
    'صلة ميم الجمع' => 'بإسكان ميم الجمع دون صلة',
    'صلة هاء الضمير' || 'هاء الكناية' =>
      RegExp('ه$marks[ۥۦ]').hasMatch(hafs)
          ? 'بصلة الهاء'
          : RegExp('ه[ْۡ]').hasMatch(hafs)
          ? 'بإسكان الهاء'
          : 'دون صلة الهاء',
    'ياءات الزوائد' => 'بحذف الياء وصلاً ووقفًا',
    'ياءات الإضافة' =>
      RegExp('يَ[ۖ-ۭ]*\$').hasMatch(hafs) ? 'بفتح الياء' : 'بإسكان الياء',
    'الإدغام' || 'الإدغام الكبير' =>
      RegExp('إظهار|اظهار').hasMatch(v.description) ? 'بالإدغام' : 'بالإظهار',
    'الإدغام بلا غنة' => 'بالإدغام بغنة',
    'الإشمام' => 'دون إشمام',
    'تاءات البزي' => 'بتخفيف التاء',
    'الإخفاء' => 'بالإظهار',
    'تكبير الختم' => 'دون تكبير',
    _ => null,
  };
}

/// The chapter(s) of the poems a label is taught in, without their marks.
RegExp? usulChapterPattern(String label) => switch (label) {
  'مد البدل' ||
  'مد اللين المهموز' ||
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
  // هَٰٓأَنتُمۡ is taught in the farsh of its sura.
  'الهمز المفرد' => RegExp('الهمز المفرد|آل عمران'),
  'ترقيق الراء' => RegExp('الراء'),
  'تغليظ اللام' => RegExp('اللامات'),
  'صلة ميم الجمع' || 'ميم الجمع' => RegExp('أم القرآن'),
  'صلة هاء الضمير' || 'هاء الكناية' => RegExp('هاء الكناية'),
  'ياءات الزوائد' => RegExp('الزوائد'),
  'ياءات الإضافة' => RegExp('الإضافة'),
  'الإدغام' => RegExp('الإدغام|الإظهار|ذكر|قربت'),
  'الإدغام الكبير' => RegExp('الإدغام الكبير'),
  'الإدغام بلا غنة' => RegExp('النون الساكنة'),
  'الوقف على الهمز' => RegExp('وقف حمزة|النقل والسكت'),
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
