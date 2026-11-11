part of 'build_ashab_usul.dart';

const _letterName = {
  'ب': 'الباء',
  'ت': 'التاء',
  'ث': 'الثاء',
  'ج': 'الجيم',
  'د': 'الدال',
  'ذ': 'الذال',
  'ز': 'الزاي',
  'س': 'السين',
  'ش': 'الشين',
  'ص': 'الصاد',
  'ض': 'الضاد',
  'ط': 'الطاء',
  'ظ': 'الظاء',
  'ف': 'الفاء',
  'ل': 'اللام',
  'م': 'الميم',
  'ن': 'النون',
  'و': 'الواو',
  'ي': 'الياء',
};

/// The two words read merged: the first's sukun gone, the second's first
/// letter doubled, as Hisham's rows write them (وَلَقَد جَّآءَكُم).
String _merged(String first, String second) =>
    '${first.replaceFirst(RegExp(r'ۡ$'), '')} '
    '${second.substring(0, 1)}ّ${second.substring(1)}';

typedef _Add =
    void Function(
      _Word w,
      String rule,
      String how, {
      required String text,
      List<String> ways,
    });

/// «الإدغام» of al-Ashab, by al-Taysir, the Shatibiyya and the Durrah, from
/// the guide and «البدور الزاهرة»: إذ، قد، تاء التأنيث، بل، هل، and the
/// letters told one by one; Khalaf's idgham of the nun and the tanween in the
/// waw and the ya without ghunna; Hamza's «بيت طائفة» and the openings of
/// الصافات والذاريات (and Khallad's المرسلات والعاديات) merged with the full
/// madd. Hisham's and Qalun's rows where they read alike.
void _idgham(
  String id,
  List<_Word> words,
  AshabSources sources,
  _Add add,
  void Function(List v) copy,
) {
  final hamza = _hamza.contains(id), kisai = _kisai.contains(id);
  final khallad = id == 'khallad', khalaf = id == 'khalaf_hamzah';
  final ashir = _khalafAshir.contains(id);
  String key(_Word w) => _key(w.s, w.a, w.w);
  // The letters each sakin is merged into.
  final idh = {
    'ت',
    'د',
    if (khallad || kisai) ...{'ز', 'س', 'ص'},
  };
  const qad = {'ج', 'ذ', 'ز', 'س', 'ش', 'ص', 'ض', 'ظ'};
  final ta = {
    'ج',
    'ز',
    'س',
    'ص',
    'ظ',
    if (!ashir) 'ث',
  };
  final bal = {
    if (hamza) ...{'ت', 'س'},
    if (khallad) 'ط',
    if (kisai) ...{'ت', 'ث', 'ز', 'س', 'ض', 'ط', 'ظ', 'ن'},
  };
  final hal = {
    if (!ashir) ...{'ت', 'ث'},
    if (kisai) 'ن',
  };

  for (var i = 0; i + 1 < words.length; i++) {
    final w = words[i], next = words[i + 1];
    if (next.s != w.s || next.a != w.a || !w.t.endsWith('ۡ')) continue;
    final bare = _bare(w.t);
    final first = next.t.substring(0, 1);
    final last = bare.substring(bare.length - 1);
    final into = switch (last) {
      'ذ' when RegExp(r'^[وف]?إذ$').hasMatch(bare) => idh,
      'د' when RegExp(r'^[وف]?ل?قد$').hasMatch(bare) => qad,
      'ت' => ta,
      'ل' when RegExp(r'^[وف]?بل$').hasMatch(bare) => bal,
      'ل' when RegExp(r'^[وف]?هل$').hasMatch(bare) => hal,
      // The jazm's ba in the fa: al-Kisa'i, Khallad.
      'ب' when kisai || khallad => const {'ف'},
      'ف' when kisai && bare == 'نخسف' => const {'ب'},
      'ل' when id == 'abul_harith' && bare == 'يفعل' => const {'ذ'},
      _ => const <String>{},
    };
    if (!into.contains(first)) continue;
    final how = 'بإدغام ${_letterName[last]} في ${_letterName[first]}';
    final row = (s: w.s, a: w.a, w: w.w, t: '${w.t} ${next.t}');
    final text = _merged(w.t, next.t);
    if (khallad && last == 'ل' && first == 'ط') {
      add(
        row,
        'idgham_saghir',
        '$how بخلف عنه، والإدغام هو المقدّم',
        text: text,
        ways: const ['الإدغام، وهو المقدّم', 'الإظهار'],
      );
    } else if (khallad && key(w) == '49:11:13') {
      add(
        row,
        'idgham_saghir',
        '$how بخلف عنه',
        text: text,
        ways: const ['الإدغام', 'الإظهار'],
      );
    } else {
      add(row, 'idgham_saghir', how, text: text);
    }
  }

  // Hisham's rows where al-Ashab merge alike.
  for (final v in sources.hisham) {
    if (v.length < 8 || v[7] != 'idgham_saghir') continue;
    final how = '${v[6]}';
    final take = switch (how) {
      // اتخذتم وبابه، لبثت، أورثتموها: the letter inside the word.
      'بإدغام الذال في التاء' => v[3] == 1,
      'بإدغام الثاء في التاء' => !ashir,
      'بإدغام الدال في الثاء' || 'بإدغام الدال في الذال وصلاً' => true,
      _ when how.contains('«يسٓ»') || how.contains('«نٓ»') => kisai || ashir,
      _ => false,
    };
    if (take) copy(v);
  }
  // عُذتُّ، فَنَبَذتُّهَا: the dhal in the ta of the word, as اتخذتم.
  for (final w in words) {
    if (!RegExp(r'^(عذت|فنبذتها)$').hasMatch(_bare(w.t))) continue;
    add(
      w,
      'idgham_saghir',
      'بإدغام الذال في التاء',
      text: w.t.replaceFirstMapped(
        RegExp('ذۡت([َُِ]?)'),
        (m) => 'ذتّ${m[1]}',
      ),
    );
  }
  // وَيُعَذِّب مَّن يَشَآءُ: Qalun's row.
  for (final v in sources.qalun) {
    if (v.length > 7 && v[7] == 'idgham_saghir' && v[0] == 2 && v[1] == 284) {
      copy(v);
    }
  }
  // ٱرۡكَبۡ مَعَنَا: Khalaf and Khalaf al-'Ashir by izhar; Khallad with two
  // faces, the idgham first, by al-Taysir; al-Kisa'i merges as Hafs.
  if (khalaf || ashir || khallad) {
    final at = words.indexWhere((w) => key(w) == '11:42:13');
    final row = (
      s: 11,
      a: 42,
      w: 13,
      t: '${words[at].t} ${words[at + 1].t}',
    );
    const text = 'ٱرۡكَبۡ مَعَنَا';
    if (khallad) {
      add(
        row,
        'idgham_saghir',
        'بالإظهار بخلف عنه، والإدغام هو المقدّم',
        text: text,
        ways: const ['الإظهار', 'الإدغام، وهو المقدّم'],
      );
    } else {
      add(row, 'idgham_saghir', 'بالإظهار', text: text);
    }
  }
  // طسٓمٓ: Hamza shows the nun of «سين» before the mim.
  if (hamza) {
    for (final k in const ['26:1:0', '28:1:0']) {
      final w = words.firstWhere((w) => key(w) == k);
      add(w, 'idgham_saghir', 'بإظهار النون من «سين» عند الميم', text: '');
    }
  }

  // ---- الإدغام الكبير لحمزة: «بيت طائفة»، وأوائل الصافات والذاريات
  // بالمد المشبع؛ ولخلاد وحده «فالملقيات ذكرا»، «فالمغيرات صبحا».
  if (hamza) {
    final sites = [
      '4:81:6',
      '37:1:0',
      '37:2:0',
      '37:3:0',
      '51:1:0',
      if (khallad) ...['77:5:0', '100:3:0'],
    ];
    for (final k in sites) {
      final at = words.indexWhere((w) => key(w) == k);
      final w = words[at], next = words[at + 1];
      final bare = _bare(w.t);
      final last = bare.substring(bare.length - 1);
      final kabir = k == '4:81:6';
      // The ta's vowel gone; the alif before it drawn long.
      var first = w.t.replaceFirst(RegExp(r'ت[َِ]$'), 'ت');
      if (!kabir) first = first.replaceFirst(RegExp(r'ٰت$'), 'ٰٓت');
      add(
        (s: w.s, a: w.a, w: w.w, t: '${w.t} ${next.t}'),
        'idgham_kabir',
        'بإدغام ${_letterName[last]} في '
            '${_letterName[next.t.substring(0, 1)]}'
            '${kabir ? '' : ' مع المد المشبع'}',
        text: '$first ${next.t.substring(0, 1)}ّ${next.t.substring(1)}',
      );
    }
  }

  // ---- الإدغام بلا غنة: لخلف عن حمزة وحده، النون الساكنة والتنوين في
  // الواو والياء من كلمتين؛ يُرسم كحفص. لا «يس والقرآن» ولا «ن والقلم».
  if (khalaf) {
    final nun = RegExp(r'(نۡ?|[ًࣰٌࣱٍࣲٖٗٞ][اى]?)[ۖ-ۛ]*$');
    for (var i = 0; i + 1 < words.length; i++) {
      final w = words[i], next = words[i + 1];
      if (next.s != w.s || next.a != w.a) continue;
      final first = next.t.substring(0, 1);
      if (first != 'و' && first != 'ي') continue;
      if (const {'36:1:0', '68:1:0'}.contains(key(w))) continue;
      final m = nun.firstMatch(w.t);
      if (m == null) continue;
      final what = m[1]!.startsWith('ن') ? 'النون الساكنة' : 'التنوين';
      add(
        (s: w.s, a: w.a, w: w.w, t: '${w.t} ${next.t}'),
        'ghunna',
        'بإدغام $what في ${_letterName[first]} بلا غنة',
        text: '',
      );
    }
  }
}
