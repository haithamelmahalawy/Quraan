/// Words of an ayah: [from] up to [to] (null: to its end). Taken from the
/// mushaf's own text when shown, never typed here, so that its rasm and signs
/// are the mushaf's.
class WaqfQuote {
  const WaqfQuote(this.surah, this.ayah, this.from, [this.to]);

  final int surah, ayah, from;
  final int? to;
}

/// One way of stopping, or one sign: what it is, what it allows, and examples.
class WaqfEntry {
  const WaqfEntry({
    required this.title,
    required this.meaning,
    required this.ruling,
    this.sign,
    this.examples = const [],
  });

  final String title, meaning, ruling;

  /// The sign in the Madinah mushaf, if it is one.
  final String? sign;
  final List<WaqfExample> examples;
}

/// Where the reader stops, what he goes on with, and why it is so.
class WaqfExample {
  const WaqfExample(this.stop, this.note, [this.next]);

  final WaqfQuote stop;
  final WaqfQuote? next;
  final String note;
}

const waqfDefinitions = [
  (
    'الوقف',
    'قطع الصوت على الكلمة زمنًا يتنفس فيه القارئ عادة، بنية استئناف القراءة.',
  ),
  ('الابتداء', 'الشروع في القراءة بعد الوقف أو القطع.'),
  ('السكت', 'قطع الصوت زمنًا يسيرًا دون تنفس، بنية استئناف القراءة.'),
  ('القطع', 'الانتهاء من القراءة والانصراف عنها.'),
];

/// The four degrees of a chosen stop, by how the words before it hang on what
/// follows. The first three are allowed; the last is not.
const waqfDegrees = [
  WaqfEntry(
    title: 'الوقف التام',
    meaning: 'الوقف على كلام تم معناه، ولا تعلق له بما بعده لا لفظًا ولا معنى.',
    ruling: 'يحسن الوقف عليه والابتداء بما بعده.',
    examples: [
      WaqfExample(
        WaqfQuote(2, 5, -3),
        'تم الكلام عن المتقين، وما بعده حديث جديد عن الكافرين.',
        WaqfQuote(2, 6, 0, 3),
      ),
    ],
  ),
  WaqfEntry(
    title: 'الوقف الكافي',
    meaning: 'الوقف على كلام تم معناه، وتعلق بما بعده في المعنى دون اللفظ.',
    ruling: 'يحسن الوقف عليه والابتداء بما بعده.',
    examples: [
      WaqfExample(
        WaqfQuote(2, 3, -3),
        'الجملة تامة في لفظها، وما بعدها يكمل صفات المتقين أنفسهم.',
        WaqfQuote(2, 4, 0, 3),
      ),
    ],
  ),
  WaqfEntry(
    title: 'الوقف الحسن',
    meaning: 'الوقف على كلام مفيد في نفسه، وتعلق بما بعده لفظًا ومعنى.',
    ruling:
        'يحسن الوقف عليه، ولا يحسن الابتداء بما بعده، بل يعود فيصله بما قبله، '
        'إلا أن يكون رأس آية فالوقف عليه سنة عند أكثر العلماء.',
    examples: [
      WaqfExample(
        WaqfQuote(1, 2, 0, 2),
        'الكلام مفيد، لكن ما بعده صفة للفظ الجلالة، فلا يبتدأ به بل يعاد '
        'الوصل.',
        WaqfQuote(1, 2, 2),
      ),
      WaqfExample(
        WaqfQuote(1, 2, 2),
        'رأس آية، فيوقف عليه ويبتدأ بما بعده مع تعلقه به.',
        WaqfQuote(1, 3, 0),
      ),
    ],
  ),
  WaqfEntry(
    title: 'الوقف القبيح',
    meaning:
        'الوقف على ما لا يتم به معنى، لشدة تعلقه بما بعده، أو على ما يوهم معنى '
        'غير مراد.',
    ruling:
        'لا يجوز تعمده، فإن اضطر إليه لضيق نفس عاد فوصله بما بعده. وأقبحه ما '
        'أوهم ما لا يليق.',
    examples: [
      WaqfExample(
        WaqfQuote(2, 26, 0, 4),
        'يوهم نفي ما لا يليق نفيه، وإنما يتم المعنى بما بعده.',
      ),
      WaqfExample(
        WaqfQuote(107, 4, 0),
        'يوهم الوعيد للمصلين عامة، وإنما هو لمن وصفوا في الآية بعدها.',
      ),
      WaqfExample(
        WaqfQuote(5, 73, 0, 6),
        'يوهم خلاف المراد، فيوصل بما بعده ليتم المعنى.',
      ),
    ],
  ),
];

/// Stops that are not chosen for their meaning.
const waqfOthers = [
  WaqfEntry(
    title: 'الوقف الاضطراري',
    meaning: 'ما يعرض للقارئ بلا اختيار منه، كضيق النفس أو العطاس أو النسيان.',
    ruling: 'يجوز على أي كلمة، ثم يعود فيصلها بما بعدها.',
  ),
  WaqfEntry(
    title: 'الوقف الاختباري',
    meaning:
        'ما يطلب من القارئ لاختبار معرفته بكيفية الوقف على الكلمة، أو لتعليمه.',
    ruling: 'يجوز للتعليم، ثم يعود فيصلها بما بعدها.',
  ),
  WaqfEntry(
    title: 'الوقف الانتظاري',
    meaning: 'أن يقف على الكلمة ليعطف عليها وجهًا آخر من أوجه القراءات.',
    ruling: 'يكون عند جمع القراءات.',
  ),
  WaqfEntry(
    title: 'الوقف الاختياري',
    meaning:
        'ما يقصده القارئ باختياره دون عارض، وهو الذي تنقسم أنواعه إلى '
        'التام والكافي والحسن والقبيح.',
    ruling: 'حكمه بحسب نوعه كما سبق.',
  ),
];

/// The signs of the Madinah mushaf.
const waqfSigns = [
  WaqfEntry(
    title: 'الوقف اللازم',
    sign: 'م',
    meaning: 'وقف لو وُصل لأوهم معنى غير مراد.',
    ruling: 'يلزم الوقف ولا يحسن الوصل.',
    examples: [
      WaqfExample(
        WaqfQuote(6, 36, 0, 4),
        'لو وصل لأوهم أن الموتى يستجيبون مع الذين يسمعون.',
        WaqfQuote(6, 36, 4, 5),
      ),
    ],
  ),
  WaqfEntry(
    title: 'الوقف الممنوع',
    sign: 'لا',
    meaning: 'لا يوقف هنا لتعلق ما بعده بما قبله.',
    ruling:
        'لا يوقف، فإن وقف عاد فوصل. وهذه العلامة في طبعات أخرى من المصحف، '
        'وليست في نص هذا المصحف، فلا مثال لها هنا.',
  ),
  WaqfEntry(
    title: 'الوقف الجائز',
    sign: 'ج',
    meaning: 'يستوي فيه الوقف والوصل.',
    ruling: 'يجوز الوجهان بلا ترجيح.',
    examples: [WaqfExample(WaqfQuote(18, 13, 0, 5), 'يستوي فيه الوجهان.')],
  ),
  WaqfEntry(
    title: 'الوصل أولى',
    sign: 'صلى',
    meaning: 'يجوز الوقف والوصل، والوصل أولى.',
    ruling: 'يجوز الوجهان، ويقدَّم الوصل.',
    examples: [WaqfExample(WaqfQuote(6, 17, 0, 9), 'الوصل هنا أولى.')],
  ),
  WaqfEntry(
    title: 'الوقف أولى',
    sign: 'قلى',
    meaning: 'يجوز الوقف والوصل، والوقف أولى.',
    ruling: 'يجوز الوجهان، ويقدَّم الوقف.',
    examples: [WaqfExample(WaqfQuote(18, 22, 15, 22), 'الوقف هنا أولى.')],
  ),
  WaqfEntry(
    title: 'تعانق الوقف',
    sign: '∴ ∴',
    meaning: 'نقطتان متجاورتان، إذا وقف على إحداهما لم يقف على الأخرى.',
    ruling: 'يوقف على أحد الموضعين لا كليهما.',
    examples: [
      WaqfExample(
        WaqfQuote(2, 2, 0, 5),
        'إن وقف على «رَيۡبَ» وصل «فِيهِ» بما بعدها، وإن وصلهما وقف على «فِيهِ».',
      ),
    ],
  ),
];
