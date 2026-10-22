import '../models/qiraat_catalog.dart';

/// Cities of teaching/association, rather than assumed birthplaces.
enum RecitationCity {
  madinah('المدينة المنورة', 'Madinah Medina'),
  makkah('مكة المكرمة', 'Makkah Mecca'),
  kufa('الكوفة', 'Kufa Kuffa Quffa'),
  basra('البصرة', 'Basra Basrah'),
  damascus('دمشق • الشام', 'Damascus Sham'),
  baghdad('بغداد', 'Baghdad'),
  egypt('مصر', 'Egypt'),
  raqqa('الرقة', 'Raqqa');

  const RecitationCity(this.nameAr, this.searchAliases);
  final String nameAr, searchAliases;
}

enum RecitationGroup {
  seven('القراء السبعة'),
  three('الثلاثة المتممون للعشرة');

  const RecitationGroup(this.nameAr);
  final String nameAr;
}

class NarratorBiography {
  const NarratorBiography(
    this.riwayaId,
    this.personId,
    this.fullName,
    this.city,
    this.brief,
  );
  final String riwayaId;

  /// Shared by the two transmissions of al-Duri, and by Khalaf's two roles.
  final String personId, fullName, brief;
  final RecitationCity city;
  Riwaya get riwaya => riwayaById(riwayaId);
  Qiraa get qiraa => qiraaOf(riwayaId);
  String get title =>
      '${riwaya.nameAr} عن ${switch (qiraa.id) {
        'abu_amr' => 'أبي عمرو',
        'abu_jafar' => 'أبي جعفر',
        _ => qiraa.shortAr,
      }}';
}

class ReaderBiography {
  const ReaderBiography(
    this.qiraaId,
    this.fullName,
    this.city,
    this.group,
    this.brief,
    this.narrators,
  );
  final String qiraaId, fullName, brief;
  final RecitationCity city;
  final RecitationGroup group;
  final List<NarratorBiography> narrators;
  Qiraa get qiraa => qiraat.firstWhere((q) => q.id == qiraaId);

  bool matches(String query) => biographyMatches(
    query,
    [
      qiraa.nameAr,
      qiraa.nameEn,
      fullName,
      brief,
      city.nameAr,
      city.searchAliases,
      group.nameAr,
      for (final n in narrators) narratorSearchText(n),
    ].join(' '),
  );
}

/// Short paraphrases, not copied modern biographies. Names, affiliations
/// and transmission links: Ibn al-Jazari's classical al-Nashr, vol. 1,
/// the ten readers' isnads; Abu Shama's Ibraz al-Ma'ani, introduction,
/// “بيان القراء السبعة ورواتهم وأخبارهم”. No disputed birth/death dates.
const biographySources = <({String title, String url})>[
  (
    title: 'النشر في القراءات العشر — ابن الجزري، الجزء الأول، أسانيد القراء العشرة ورواتهم',
    url: 'https://ar.wikisource.org/wiki/النشر_في_القراءات_العشر/الجزء_الأول',
  ),
  (
    title: 'إبراز المعاني من حرز الأماني — أبو شامة، بيان القراء السبعة ورواتهم وأخبارهم',
    url: 'https://quranpedia.app/books/b5486/s3.html',
  ),
];

const readerBiographies = <ReaderBiography>[
  ReaderBiography(
    'nafi',
    'نافع بن عبد الرحمن بن أبي نعيم الليثي',
    RecitationCity.madinah,
    RecitationGroup.seven,
    'إمام أهل المدينة في القراءة. تلقى عن جماعة من التابعين، ومن شيوخه أبو جعفر المدني.',
    [
      NarratorBiography(
        'qalun',
        'qalun',
        'عيسى بن مينا، أبو موسى قالون',
        RecitationCity.madinah,
        'مقرئ مدني، أخذ القراءة عن نافع. اشتهر بلقب قالون، وكان يعلّم القراءة والعربية.',
      ),
      NarratorBiography(
        'warsh',
        'warsh',
        'عثمان بن سعيد، أبو سعيد ورش',
        RecitationCity.egypt,
        'مقرئ مصري، رحل إلى المدينة وقرأ على نافع، ثم تصدّر للإقراء بمصر.',
      ),
    ],
  ),
  ReaderBiography(
    'ibn_kathir',
    'عبد الله بن كثير الداري المكي، أبو معبد',
    RecitationCity.makkah,
    RecitationGroup.seven,
    'من التابعين وأئمة الإقراء بمكة. نقل البزي وقنبل قراءته بالإسناد عن أصحابه.',
    [
      NarratorBiography(
        'bazzi',
        'bazzi',
        'أحمد بن محمد بن عبد الله بن أبي بزة، أبو الحسن',
        RecitationCity.makkah,
        'مقرئ ومؤذّن بالحرم المكي، اشتهر بالبزي. نقل قراءة ابن كثير بالإسناد، ولم يدركه مباشرة.',
      ),
      NarratorBiography(
        'qunbul',
        'qunbul',
        'محمد بن عبد الرحمن المخزومي المكي، أبو عمرو',
        RecitationCity.makkah,
        'مقرئ مكي اشتهر بلقب قنبل. أخذ قراءة ابن كثير بالإسناد وتصدّر للإقراء بها.',
      ),
    ],
  ),
  ReaderBiography(
    'abu_amr',
    'أبو عمرو بن العلاء المازني البصري',
    RecitationCity.basra,
    RecitationGroup.seven,
    'إمام البصرة في القراءة ومن أئمة العربية. نقل الدوري والسوسي قراءته عن تلميذه اليزيدي.',
    [
      NarratorBiography(
        'duri_abuamr',
        'duri',
        'حفص بن عمر الدوري الأزدي، أبو عمر',
        RecitationCity.baghdad,
        'مقرئ بغدادي، أخذ قراءة أبي عمرو عن اليزيدي. وهو نفسه الدوري الذي يروي عن الكسائي.',
      ),
      NarratorBiography(
        'susi',
        'susi',
        'صالح بن زياد السوسي، أبو شعيب',
        RecitationCity.raqqa,
        'مقرئ أقام بالرقة، أخذ قراءة أبي عمرو عن اليزيدي. نسبته السوسي إلى السوس بالأهواز.',
      ),
    ],
  ),
  ReaderBiography(
    'ibn_amir',
    'عبد الله بن عامر اليحصبي الشامي، أبو عمران',
    RecitationCity.damascus,
    RecitationGroup.seven,
    'من التابعين وإمام أهل الشام في القراءة، تولّى قضاء دمشق. وصلت قراءته إلى هشام وابن ذكوان بالإسناد.',
    [
      NarratorBiography(
        'hisham',
        'hisham',
        'هشام بن عمار الدمشقي، أبو الوليد',
        RecitationCity.damascus,
        'قارئ وخطيب بدمشق، نقل قراءة ابن عامر بواسطة شيوخه، ومنهم أيوب بن تميم.',
      ),
      NarratorBiography(
        'ibn_dhakwan',
        'ibn_dhakwan',
        'عبد الله بن أحمد بن بشير بن ذكوان، أبو عمرو',
        RecitationCity.damascus,
        'من أئمة الإقراء بدمشق، أخذ قراءة ابن عامر بالإسناد عن أيوب بن تميم.',
      ),
    ],
  ),
  ReaderBiography(
    'asim',
    'عاصم بن أبي النجود الأسدي الكوفي، أبو بكر',
    RecitationCity.kufa,
    RecitationGroup.seven,
    'من أئمة التابعين في الإقراء بالكوفة. أخذ عن أبي عبد الرحمن السلمي وزر بن حبيش، وروى عنه شعبة وحفص.',
    [
      NarratorBiography(
        'shubah',
        'shubah',
        'شعبة بن عياش بن سالم الكوفي، أبو بكر',
        RecitationCity.kufa,
        'مقرئ كوفي، اشتهر بكنيته أبي بكر. قرأ على عاصم وهو أحد راوييه المشهورين.',
      ),
      NarratorBiography(
        'hafs',
        'hafs',
        'حفص بن سليمان بن المغيرة الكوفي، أبو عمرو',
        RecitationCity.kufa,
        'مقرئ كوفي، تلقى القراءة عرضًا عن عاصم، وأقرأ بها في بغداد ومكة.',
      ),
    ],
  ),
  ReaderBiography(
    'hamzah',
    'حمزة بن حبيب الزيات الكوفي، أبو عمارة',
    RecitationCity.kufa,
    RecitationGroup.seven,
    'إمام من أئمة الإقراء بالكوفة. وصلت قراءته إلى خلف وخلاد عن تلميذه سليم بن عيسى.',
    [
      NarratorBiography(
        'khalaf_hamzah',
        'khalaf',
        'خلف بن هشام البزار البغدادي، أبو محمد',
        RecitationCity.baghdad,
        'أخذ قراءة حمزة عن سليم بن عيسى. وهو نفسه خلف العاشر، وله قراءة مستقلة تروى عن إسحاق وإدريس.',
      ),
      NarratorBiography(
        'khallad',
        'khallad',
        'خلاد بن خالد الشيباني الكوفي، أبو عيسى',
        RecitationCity.kufa,
        'مقرئ كوفي، قرأ على سليم بن عيسى ونقل عنه قراءة حمزة.',
      ),
    ],
  ),
  ReaderBiography(
    'kisai',
    'علي بن حمزة الكسائي، أبو الحسن',
    RecitationCity.kufa,
    RecitationGroup.seven,
    'إمام في القراءة ومن أعلام النحو الكوفي. أخذ عنه أبو الحارث والدوري، ونسبت إليه قراءة الكسائي.',
    [
      NarratorBiography(
        'abul_harith',
        'abul_harith',
        'الليث بن خالد البغدادي، أبو الحارث',
        RecitationCity.baghdad,
        'مقرئ بغدادي، أخذ القراءة عرضًا عن الكسائي واشتهر بروايتها عنه.',
      ),
      NarratorBiography(
        'duri_kisai',
        'duri',
        'حفص بن عمر الدوري الأزدي، أبو عمر',
        RecitationCity.baghdad,
        'أخذ القراءة عن الكسائي مباشرة. وهو نفسه راوي أبي عمرو عن اليزيدي، وتختلف الروايتان باختلاف الإمام.',
      ),
    ],
  ),
  ReaderBiography(
    'abu_jafar',
    'يزيد بن القعقاع المخزومي المدني، أبو جعفر',
    RecitationCity.madinah,
    RecitationGroup.three,
    'من قدماء قراء المدينة ومن شيوخ نافع. أخذ عنه ابن وردان وابن جماز، وقراءته من الثلاث المتممة للعشر.',
    [
      NarratorBiography(
        'ibn_wardan',
        'ibn_wardan',
        'عيسى بن وردان المدني، أبو الحارث',
        RecitationCity.madinah,
        'مقرئ مدني، أخذ القراءة عن أبي جعفر وشيبة بن نصاح، وقرأ أيضًا على نافع.',
      ),
      NarratorBiography(
        'ibn_jammaz',
        'ibn_jammaz',
        'سليمان بن مسلم بن جماز المدني، أبو الربيع',
        RecitationCity.madinah,
        'مقرئ مدني، أخذ القراءة عن أبي جعفر ونافع، واشتهر بروايته عن أبي جعفر.',
      ),
    ],
  ),
  ReaderBiography(
    'yaqub',
    'يعقوب بن إسحاق الحضرمي البصري، أبو محمد',
    RecitationCity.basra,
    RecitationGroup.three,
    'انتهت إليه إمامة الإقراء بالبصرة بعد أبي عمرو. نقل قراءته رويس وروح، وهي من القراءات الثلاث المتممة للعشر.',
    [
      NarratorBiography(
        'ruways',
        'ruways',
        'محمد بن المتوكل اللؤلؤي البصري، أبو عبد الله',
        RecitationCity.basra,
        'مقرئ بصري، رويس لقب له. أخذ القراءة عن يعقوب واشتهر بضبط روايته.',
      ),
      NarratorBiography(
        'rawh',
        'rawh',
        'روح بن عبد المؤمن الهذلي البصري، أبو الحسن',
        RecitationCity.basra,
        'مقرئ بصري، أخذ القراءة عن يعقوب، وهو أحد راوييه المعتمدين في القراءات العشر.',
      ),
    ],
  ),
  ReaderBiography(
    'khalaf',
    'خلف بن هشام البزار البغدادي، أبو محمد',
    RecitationCity.baghdad,
    RecitationGroup.three,
    'إمام قارئ ببغداد، صاحب القراءة العاشرة المستقلة. وهو أيضًا أحد راويي حمزة، ويروي اختياره إسحاق وإدريس.',
    [
      NarratorBiography(
        'ishaq',
        'ishaq',
        'إسحاق بن إبراهيم بن عثمان الوراق، أبو يعقوب',
        RecitationCity.baghdad,
        'أصله من مرو ثم استقر ببغداد. قرأ على خلف واختص بنقل اختياره في القراءة العاشرة.',
      ),
      NarratorBiography(
        'idris',
        'idris',
        'إدريس بن عبد الكريم الحداد البغدادي، أبو الحسن',
        RecitationCity.baghdad,
        'مقرئ بغدادي، روى عن خلف قراءته العاشرة وروايته عن حمزة، واشتهر بالإتقان.',
      ),
    ],
  ),
];

String narratorSearchText(NarratorBiography n) => [
  n.title,
  n.riwaya.nameEn,
  n.fullName,
  n.brief,
  n.city.nameAr,
  n.city.searchAliases,
].join(' ');

bool biographyMatches(String query, String text) {
  String normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[ً-ٰٟـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final haystack = normalize(text);
  return normalize(query).split(' ').every(haystack.contains);
}
