// The usul of al-Ashab — Hamza (Khalaf, Khallad), al-Kisa'i (Abu al-Harith,
// al-Duri) and Khalaf al-'Ashir (Ishaq, Idris) — from al-Taysir, the
// Shatibiyya and the Durrah, built on the chapters and wording of the readers
// already verified. The Quranpedia rows, worded against Warsh rather than
// Hafs, are kept aside in tool/ashab_raw and no longer drawn where a chapter
// built here tells the word. Rerunning gives the same file.
//   dart run tool/build_ashab_usul.dart
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/waqf_hamza.dart';

import 'apply_dagger_alif.dart';
import 'build_data.dart' as bd show describe, currentRiwaya;

part 'ashab_farsh.dart';
part 'ashab_idgham.dart';
part 'ashab_imala.dart';
part 'ashab_waqf.dart';
part 'ashab_waqf_middle.dart';

const ashabSource = 'ashab_pdf';
const ashabRiwayat = [
  'khalaf_hamzah',
  'khallad',
  'abul_harith',
  'duri_kisai',
  'ishaq',
  'idris',
];
const _hamza = {'khalaf_hamzah', 'khallad'};
const _kisai = {'abul_harith', 'duri_kisai'};
const _khalafAshir = {'ishaq', 'idris'};

typedef _Word = ({int s, int a, int w, String t});

String _bare(String s) =>
    s.replaceAll('ٱ', 'ا').replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '');

String _key(Object s, Object a, Object w) => '$s:$a:$w';

/// The verified readers' rows the Ashab read alike, by chapter.
class AshabSources {
  AshabSources(
    this.ruways,
    this.hisham,
    this.qalun,
    this.shubah,
    this.verified,
  );

  /// Ya'qub's «ضم هاء الضمير» rows; Hamza's are «عليهم، إليهم، لديهم» of them.
  /// Ruways's «إشمام الصاد صوت الزاي» in the twelve places, read by al-Ashab.
  final List<List> ruways;

  /// Hisham's «إشمام حركة بحركة» in قيل وأخواتها, read by al-Kisa'i; his
  /// idgham rows, worded and written as al-Ashab's.
  final List<List> hisham;

  /// Qalun's «وَيُعَذِّب مَّن».
  final List<List> qalun;

  /// Shu'bah's «فِيهِ مُهَانًا» without the silah.
  final List<List> shubah;

  /// Each verified reader's rows by the word they begin at: the farsh read
  /// alike is taken from them.
  final Map<String, Map<String, List<List>>> verified;

  static AshabSources load(String Function(String id) read) {
    List<List> rows(String id) =>
        ((jsonDecode(read(id)) as Map)['variants'] as List).cast<List>();
    return AshabSources(
      rows('ruways'),
      rows('hisham'),
      rows('qalun'),
      rows('shubah'),
      {
        for (final r in _verifiedOrder)
          r: () {
            final at = <String, List<List>>{};
            for (final v in rows(r)) {
              (at[_key(v[0], v[1], v[2])] ??= []).add(v);
            }
            return at;
          }(),
      },
    );
  }
}

/// The Quranpedia rows of [id] as they first were.
List<List> ashabRaw(String id) =>
    (jsonDecode(File('tool/ashab_raw/$id.json').readAsStringSync()) as List)
        .cast<List>();

Map<String, int> buildAshabUsul(
  Map quran,
  Map data,
  String id,
  AshabSources sources, {
  required List<List> raw,
  Map? book,
}) {
  if (!ashabRiwayat.contains(id)) {
    throw ArgumentError.value(id, 'id', 'Not one of al-Ashab');
  }
  final words = <_Word>[
    for (final a in quran['ayahs'] as List)
      for (final (w, t) in (a[4] as String).split(' ').indexed)
        (s: a[0] as int, a: a[1] as int, w: w, t: t),
  ];
  final index = {for (final w in words) _key(w.s, w.a, w.w): w};
  final rows = <List>[];
  final told = <String>{};
  final counts = <String, int>{};
  // The reader's text of a word so far: the rules told on it, one on another.
  final textAt = <String, String>{};
  final rowsAt = <String, List<List>>{};
  void setText(String key, String text) {
    textAt[key] = text;
    for (final v in rowsAt[key] ?? const <List>[]) {
      if ('${v[4]}'.isNotEmpty) v[4] = text;
    }
  }

  void add(
    _Word w,
    String rule,
    String how, {
    required String text,
    List<String> ways = const [],
  }) {
    final key = _key(w.s, w.a, w.w);
    final count = w.t.split(' ').length;
    final row = <Object>[
      w.s,
      w.a,
      w.w,
      count,
      text,
      'u',
      how,
      rule,
      {
        'source': ashabSource,
        if (ways.isNotEmpty) ...{'ways': ways, 'ownWays': true},
      },
    ];
    rows.add(row);
    (rowsAt[key] ??= []).add(row);
    for (var i = 0; i < count; i++) {
      told.add(_key(w.s, w.a, w.w + i));
    }
    if (text.isNotEmpty && count == 1) setText(key, text);
    counts.update(rule, (n) => n + 1, ifAbsent: () => 1);
  }

  void copy(List v) {
    final meta = v.length > 8 && v[8] is Map
        ? Map<String, Object?>.from(v[8] as Map)
        : <String, Object?>{};
    final row = [
      ...v.take(8),
      for (var i = v.length; i < 8; i++) '',
      meta
        ..remove('sourcePage')
        ..['source'] = ashabSource,
    ];
    rows.add(row);
    for (var i = 0; i < (v[3] as int); i++) {
      told.add(_key(v[0], v[1], (v[2] as int) + i));
    }
    if (v[3] == 1) {
      final key = _key(v[0], v[1], v[2]);
      (rowsAt[key] ??= []).add(row);
      if ('${v[4]}'.isNotEmpty) textAt[key] = '${v[4]}';
    }
    counts.update('${row[7]}', (n) => n + 1, ifAbsent: () => 1);
  }

  // ---- هاء الكناية: «عليهم، إليهم، لديهم» بضم الهاء وصلًا ووقفًا لحمزة،
  // كما يقرؤها يعقوب؛ لا «عاليهم» (بالألف).
  if (_hamza.contains(id)) {
    final hum = RegExp(r'^[وف]?(عليهم|إليهم|لديهم)$');
    final sites = {
      for (final w in words)
        if (!w.t.contains('ٰ') && hum.hasMatch(_bare(w.t))) _key(w.s, w.a, w.w),
    };
    for (final v in sources.ruways) {
      if (v.length > 7 &&
          v[7] == 'ha_damir' &&
          sites.contains(_key(v[0], v[1], v[2]))) {
        copy(v);
      }
    }
  }

  // ---- هاء الكناية: ضم الهاء قبل الساكن وصلًا بعد كسرة أو ياء، إتباعًا
  // للميم (بِهُمُ ٱلۡأَسۡبَابُ، عَلَيۡهُمُ ٱلۡقِتَالُ)، للأصحاب كلهم؛ وقفًا
  // كحفص. ما قرأه حمزة بالضم أصلًا («عليهم، إليهم، لديهم») تقدّم.
  for (var i = 0; i + 1 < words.length; i++) {
    final w = words[i], next = words[i + 1];
    final key = _key(w.s, w.a, w.w);
    if (told.contains(key) || next.s != w.s || next.a != w.a) continue;
    if (!next.t.startsWith('ٱ')) continue;
    final m = RegExp('هِمُ([ۖ-ۛ]*)\$').firstMatch(w.t);
    if (m == null) continue;
    add(
      w,
      'ha_damir',
      'بضم الهاء إتباعًا للميم قبل الساكن',
      text: '${w.t.substring(0, m.start)}هُمُ${m[1]}',
    );
  }

  // ---- الإشمام، إشمام حرف بحرف: الصاد الساكنة قبل الدال في اثني عشر موضعًا
  // للأصحاب كرويس؛ و«الصراط، صراط» لخلف حيث وقعا ولخلاد في أول الفاتحة؛
  // و«المصيطرون، بمصيطر» لخلف، ولخلاد بخلف عنه والإشمام المقدّم.
  for (final v in sources.ruways) {
    if (v.length > 7 && v[7] == 'ishmam_sad') copy(v);
  }
  if (_hamza.contains(id)) {
    const how = 'بإشمام الصاد صوت الزاي';
    final khalaf = id == 'khalaf_hamzah';
    for (final w in words) {
      final bare = _bare(w.t);
      final sirat = RegExp(r'^(ال)?صرط[اكي]?$').hasMatch(bare);
      final musaytir = RegExp(r'^(المصيطرون|بمصيطر)$').hasMatch(bare);
      if (!sirat && !musaytir) continue;
      if (sirat && !khalaf && _key(w.s, w.a, w.w) != '1:6:1') continue;
      final khulf = musaytir && !khalaf;
      add(
        w,
        'ishmam_sad',
        khulf ? '$how بخلف عنه، والإشمام هو المقدّم' : how,
        text: '',
        ways: khulf
            ? const ['الإشمام، وهو المقدّم', 'الصاد الخالصة']
            : const [],
      );
    }
  }

  // ---- الإشمام، إشمام حركة بحركة: «قيل، غيض، جيء، حيل، سيق، سيء، سيئت»
  // للكسائي كهشام، ومنها «قيل» الثانية في المجادلة.
  if (_kisai.contains(id)) {
    for (final v in sources.hisham) {
      if (v.length > 7 && v[7] == 'ishmam') copy(v);
    }
    if (!told.contains('58:11:14')) {
      add(index['58:11:14']!, 'ishmam', 'بإشمام كسرة القاف ضمًّا', text: '');
    }
  }

  // ---- الهمزتان من كلمة والاستفهام: «ءَأَٰمَنتُمۡ» (الأعراف، طه، الشعراء)،
  // «أَءِنَّ لَنَا» (الأعراف)، «أَءِنَّكُمۡ» (العنكبوت ٢٨)، «ءَأَعۡجَمِيّٞ»
  // (فصلت) بتحقيق الهمزتين للأصحاب كشعبة؛ و«ءَأَن كَانَ» (القلم) لحمزة.
  for (final v in sources.shubah) {
    final at = _key(v[0], v[1], v[2]);
    if (const {
          '7:123:2',
          '20:71:1',
          '26:49:1',
          '7:113:4',
          '29:28:4',
          '41:44:8',
        }.contains(at) ||
        at == '68:14:0' && _hamza.contains(id)) {
      copy(v);
    }
  }
  // الاستفهام المكرر للكسائي: الاستفهام في الأول كحفص، والإخبار في الثاني
  // بهمزة واحدة مكسورة كقالون؛ و«إِنَّنَا» في النمل كهشام؛ والعنكبوت
  // بالاستفهام فيهما.
  if (_kisai.contains(id)) {
    for (final k in const [
      '13:5:7',
      '17:49:5',
      '17:98:10',
      '23:82:6',
      '32:10:5',
      '37:16:5',
      '37:53:5',
      '56:47:7',
      '79:11:0',
    ]) {
      final w = index[k]!;
      add(
        w,
        'tasheel_word',
        'بالإخبار بهمزة واحدة مكسورة',
        text: w.t.replaceFirst(RegExp('^أَ[ءئ]ِ'), 'إِ'),
      );
    }
    for (final v in sources.hisham) {
      if (v[0] == 27 && v[1] == 67 && v[2] == 7) copy(v);
    }
  }

  // ---- النقل في «فسل، وسل» للكسائي وخلف العاشر، كابن كثير: وصف البزي،
  // والنص من حفص بلا صلته (فَسَلۡهُمۡ).
  if (_kisai.contains(id) || _khalafAshir.contains(id)) {
    for (final w in words) {
      final bare = _bare(w.t);
      if (!RegExp('^[وف]سل').hasMatch(bare) || !w.t.contains('ٔ')) continue;
      final his =
          (sources.verified['bazzi']![_key(w.s, w.a, w.w)] ?? const <List>[])
              .where((v) => '${v[6]}'.startsWith('بنقل حركة الهمزة'))
              .firstOrNull;
      if (his == null) continue;
      final row = [
        w.s,
        w.a,
        w.w,
        1,
        w.t.replaceFirst(RegExp('سۡـ[َٔ]{2}'), 'سَ'),
        his[5],
        his[6],
        his.length > 7 ? his[7] : '',
        {'source': ashabSource, 'farshFrom': 'bazzi'},
      ];
      rows.add(row);
      told.add(_key(w.s, w.a, w.w));
      counts.update('naql sal', (n) => n + 1, ifAbsent: () => 1);
    }
  }

  // ---- ياءات الإضافة والزوائد التي لا يذكرها الكتاب في فرشه، من الدليل:
  // الإسكان بنص رويس حيث قرأه، وإلا بنص حفص والياء ساكنة؛ والزوائد بصفوف
  // من قرأها كذلك. وهي تحل محل قراءة الكتاب في كلمتها.
  final reserved = <String>{};
  {
    final hamza = _hamza.contains(id), ashir = _khalafAshir.contains(id);
    final iskan = [
      '5:116:10',
      '14:22:22',
      '38:69:2',
      if (hamza) ...['34:13:17', '39:38:16', '67:28:3'],
      if (hamza || ashir) ...['36:22:0', '27:20:3'],
    ];
    for (final k in iskan) {
      final ruways = (sources.verified['ruways']![k] ?? const <List>[])
          .where((v) => v.length > 7 && v[7] == 'ya_idafa')
          .firstOrNull;
      reserved.add(k);
      if (ruways != null) {
        copy(ruways);
        continue;
      }
      final w = index[k]!;
      add(
        w,
        'ya_idafa',
        'بإسكان ياء الإضافة',
        text: w.t.replaceFirstMapped(RegExp(r'يَ([ۖ-ۛ]*)$'), (m) => 'ي${m[1]}'),
      );
    }
    // The zawa'id: (riwaya the row is taken from, place, readers).
    for (final (from, k, who) in [
      ('ibn_wardan', '14:40:8', _hamza),
      ('qalun', '11:105:1', _kisai),
      ('ibn_wardan', '18:64:4', _kisai),
      ('bazzi', '27:36:7', ashabRiwayat.toSet()),
      ('ruways', '27:36:4', _hamza),
    ]) {
      if (!who.contains(id)) continue;
      final row = (sources.verified[from]![k] ?? const <List>[])
          .where((v) => v.length > 7 && v[7] == 'ya_zaida')
          .firstOrNull;
      if (row == null) continue;
      reserved.add(k);
      copy(row);
    }
  }

  // ---- كلمات من هاء الكناية، فرشًا كما يكتبها شعبة: «يؤده، نؤته، نوله،
  // نصله» بإسكان الهاء لحمزة (صفوف شعبة)؛ «أنسانيه، عليهِ الله» بكسر الهاء
  // للأصحاب؛ «ويتقه»؛ «أرجه، فألقه، يرضه» للكسائي وخلف العاشر. من نص حفص
  // بتغيير حركة الهاء وحدها.
  {
    final hamza = _hamza.contains(id);
    final others = _kisai.contains(id) || _khalafAshir.contains(id);
    void ha(String k, String how, String Function(String) change) {
      reserved.add(k);
      final shubah = (sources.verified['shubah']![k] ?? const <List>[])
          .where((v) => '${v[6]}' == how)
          .firstOrNull;
      if (shubah != null) {
        copy(shubah);
        return;
      }
      final w = index[k]!;
      final row = [
        w.s,
        w.a,
        w.w,
        1,
        change(w.t),
        'f',
        how,
        '',
        {'source': ashabSource},
      ];
      rows.add(row);
      told.add(k);
      counts.update('ha words', (n) => n + 1, ifAbsent: () => 1);
    }

    // The ha with the vowel [v] and the silah's letter [silah], or quiet.
    String Function(String) haWith(String v, [String silah = '']) =>
        (t) => t.replaceFirstMapped(
          RegExp(r'ه[ُِۡ]?[ۥۦ]?(ٓ?)([ۖ-ۛ]*)$'),
          (m) => 'ه$v$silah${m[1]}${m[2]}',
        );
    if (hamza) {
      for (final k in const [
        '3:75:7',
        '3:75:15',
        '3:145:14',
        '3:145:20',
        '42:20:14',
        '4:115:13',
        '4:115:16',
      ]) {
        ha(k, 'بإسكان الهاء', haWith('ۡ'));
      }
    }
    ha('18:63:10', 'بكسر الهاء', haWith('ِ'));
    ha('48:10:20', 'بكسر الهاء', haWith('ِ'));
    // وَيَتَّقۡهِ: the qaf with the kasra; the ha joined (Khalaf, al-Kisa'i,
    // Khalaf al-'Ashir) or quiet (Khallad, by al-Taysir).
    ha(
      '24:52:6',
      id == 'khallad' ? 'بكسر القاف وإسكان الهاء' : 'بكسر القاف والهاء وصلتها',
      (t) => haWith(id == 'khallad' ? 'ۡ' : 'ِ', id == 'khallad' ? '' : 'ۦ')(
        t.replaceFirst('قۡ', 'قِ'),
      ),
    );
    if (others) {
      for (final k in const ['7:111:1', '26:36:1', '27:28:3']) {
        ha(k, 'بكسر الهاء وصلتها', haWith('ِ', 'ۦ'));
      }
      ha('39:7:12', 'بضم الهاء وصلتها', haWith('ُ', 'ۥ'));
    }
  }

  // ---- الإدغام، على نص هشام ووصفه: «بإدغام الدال في الجيم».
  _idgham(id, words, sources, add, copy);

  // ---- الوقف على الهمز لحمزة: المتطرف كهشام، ولخلاد الرسمي معه.
  counts['waqf final'] = _waqfFinal(id, index, sources.hisham, copy, rows.add);
  counts['waqf middle'] = _waqfMiddle(id, words, rows.add);
  counts['waqf separated'] = _waqfSeparated(id, words, rows.add);

  // ---- السكت قبل الهمز، وصلًا، من التيسير وزيادة الشاطبية: لخلف على «أل»
  // و«شيء» بلا خلاف، وعلى الساكن المفصول بخلف عنه؛ ولخلاد مثله على «أل»
  // و«شيء» بلا خلاف (المستخدم، 2026-11-12). ترك السكت هو المقدّم حيث كان
  // الخلاف، طريق التيسير. لا سكت
  // على حرف المد، ولا على الموصول في كلمة، ولا على آخر الآية.
  if (_hamza.contains(id)) {
    final khalaf = id == 'khalaf_hamzah';
    const khulf = ['السكت', 'ترك السكت، وهو المقدّم'];
    const after = '، وترك السكت هو المقدّم';
    // The sakin's letter and its marks, then the hamza.
    final al = RegExp(
      '^((?:[وفبلكأ][َِ]?){0,3}(?:ٱلۡ|(?<=[َِ])لۡ))(?=ـ?[ءأإآٔ])',
    );
    final shay = RegExp('^([وفبلك]?[َِ]?شَيۡ)(?=ـ?[ءٔ])');
    // The last letter sakin: a sukun, or a tanween (before its alif).
    final sakinEnd = RegExp(r'(ۡ|[ًࣰٌࣱٍࣲ])([اى]?[ۖ-ۛ]*)$|(ۡ)(ا۟[ۖ-ۛ]*)$');
    String marked(String key, String hafs, int at) {
      final t = textAt[key] ?? hafs;
      return '${t.substring(0, at)}ۜ${t.substring(at)}';
    }

    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final key = _key(w.s, w.a, w.w);
      final own = textAt[key] ?? w.t;
      final a = al.firstMatch(own), b = shay.firstMatch(own);
      // Khalaf's «شيء» with its tanween before a hamza (شَيۡءٍ إِنَّمَا): the
      // sakt on its ya, and on its tanween by khulf (the user, 2026-11-12).
      final next = i + 1 < words.length ? words[i + 1] : null;
      final apart =
          khalaf &&
              b != null &&
              next != null &&
              next.s == w.s &&
              next.a == w.a &&
              RegExp('^[ءأإآ]').hasMatch(next.t)
          ? sakinEnd.firstMatch(own)
          : null;
      if (apart != null) {
        final t = marked(key, w.t, b!.end);
        final at = apart.start + (apart[1] ?? apart[3])!.length + 1;
        add(
          w,
          'sakt',
          'بالسكت على الياء الساكنة في «شيء» قبل الهمز، وعلى تنوينها قبل '
              'الهمز بعدها بخلف عنه، وترك السكت عليه هو المقدّم',
          text: '${t.substring(0, at)}ۜ${t.substring(at)}',
          ways: const [
            'السكت على الياء والتنوين',
            'السكت على الياء وحدها، وهو المقدّم',
          ],
        );
        continue;
      }
      if (a != null || b != null) {
        final what = a != null ? 'لام التعريف' : 'الياء الساكنة في «شيء»';
        add(
          w,
          'sakt',
          'بالسكت على $what قبل الهمز',
          text: marked(key, w.t, (a ?? b)!.end),
        );
        continue;
      }
      if (!khalaf || i + 1 == words.length) continue;
      final following = words[i + 1];
      if (following.s != w.s || following.a != w.a) continue;
      if (!RegExp('^[ءأإآ]').hasMatch(following.t)) continue;
      final end = sakinEnd.firstMatch(own);
      if (end == null) continue;
      add(
        w,
        'sakt',
        'بالسكت على الساكن المفصول قبل الهمز بخلف عنه$after',
        text: marked(key, w.t, end.start + (end[1] ?? end[3])!.length),
        ways: khulf,
      );
    }
  }

  // ---- الفرش، من «التسهيل لقراءات التنزيل»؛ ومعه لا يبقى من صفوف
  // Quranpedia شيء.
  if (book != null) {
    final f = _farsh(id, book, index, textAt, sources.verified, rows.add);
    counts['farsh copied'] = f.copied;
    counts['farsh worded'] = f.worded;
    counts['farsh quoted'] = f.quoted;
    counts['book usul'] = f.usul;
    raw = const [];
    // ---- الإمالة والتقليل، من قسم الممال في الكتاب.
    counts['imala'] = _imala(
      id,
      book,
      index,
      sources.verified['ibn_dhakwan']!,
      rows.add,
    );
  }

  // ---- الوقف بالهاء على تاء التأنيث المبسوطة للكسائي (رَحۡمَتَ، نِعۡمَتَ):
  // صفوف البزي ورويس حيث يقرأ الكلمة مفردة، إلا «يا أبت»؛ و«مرضات، اللات،
  // ذات بهجة، ولات، هيهات» له وحده. ثم تمال هاؤها كالمربوطة (المستخدم،
  // 2026-11-12).
  if (_kisai.contains(id)) {
    final told = {
      for (final v in rows)
        if (v[7] == 'rasm_stop') _key(v[0], v[1], v[2]),
    };
    final stops = <String, String>{};
    for (final src in const ['bazzi', 'ruways']) {
      for (final list in sources.verified[src]!.values) {
        for (final v in list) {
          if (v.length < 9 || v[7] != 'rasm_stop') continue;
          if (!'${v[6]}'.contains('تاء التأنيث')) continue;
          final key = _key(v[0], v[1], v[2]);
          final word = index[key];
          if (word == null || _bare(word.t).contains('يأبت')) continue;
          // His farsh read in the plural (كَلِمَٰتُ): no feminine ha.
          final own = textAt[key];
          if (own != null && _bare(own).contains('ات')) continue;
          if (told.add(key)) {
            copy([
              ...v.take(8),
              {...(v[8] as Map), 'farshFrom': src},
            ]);
          }
          stops[key] = '${(v[8] as Map)['stopText'] ?? word.t}';
        }
      }
    }
    for (final word in index.values) {
      final key = _key(word.s, word.a, word.w);
      final bare = _bare(word.t);
      final next = index[_key(word.s, word.a, word.w + 1)];
      final his =
          RegExp(r'^(و?مرضات|ا?للت|ولات|هيهات)$').hasMatch(bare) ||
          bare == 'ذات' && next != null && _bare(next.t).startsWith('بهج');
      if (!his || !told.add(key)) continue;
      rows.add([
        word.s,
        word.a,
        word.w,
        1,
        '',
        'u',
        'بالوقف بالهاء',
        'rasm_stop',
        {
          'source': ashabSource,
          'stopOnly': true,
          'stopText': word.t.replaceFirst(RegExp(r'ت[ً-ٟۖ-ۛ]*$'), 'هۡ'),
        },
      ]);
      stops[key] = word.t;
    }
    // Its ha as a feminine ha: imala by the letter before it.
    final imala = {
      for (final v in rows)
        if (v[7] == 'imala_ha') _key(v[0], v[1], v[2]),
    };
    for (final MapEntry(:key, :value) in stops.entries) {
      if (imala.contains(key)) continue;
      // The word as he stops on it (ثَمَرَهۡ), its ha a feminine one.
      final how = _kisaiHa(
        value
            .replaceFirst(RegExp(r'ت(?=[ً-ٟۖ-ۛ]*$)'), 'ة')
            .replaceFirst(RegExp(r'هۡ$'), 'ة'),
      );
      if (how == null) continue;
      final w = index[key]!;
      final khulf = how == _KisaiHa.khulf;
      // The book's imala of an alif his singular has not (ثَمَرَهۡ).
      rows.removeWhere(
        (v) =>
            _key(v[0], v[1], v[2]) == key &&
            v[7] == '' &&
            '${v[6]}'.startsWith('بإمالة الألف'),
      );
      rows.add([
        w.s,
        w.a,
        w.w,
        1,
        '',
        'u',
        khulf
            ? 'بإمالة هاء التأنيث وما قبلها وقفًا بخلف عنه'
            : 'بإمالة هاء التأنيث وما قبلها وقفًا قولًا واحدًا',
        'imala_ha',
        {
          'source': ashabSource,
          'stopOnly': true,
          if (khulf) 'ways': const ['الإمالة', 'الفتح'],
          if (khulf) 'ownWays': true,
        },
      ]);
    }
  }

  // ---- هاء الكناية: «فِيهِ مُهَانًا» بلا صلة، كشعبة وكل من خالف حفصًا.
  for (final v in sources.shubah) {
    if (v[0] == 25 && v[1] == 69 && v[2] == 6) copy(v);
  }

  // The ya's rows above over the book's farsh of their word.
  rows.removeWhere(
    (v) =>
        reserved.contains(_key(v[0], v[1], v[2])) &&
        v[5] != 'u' &&
        v[8] is Map &&
        ((v[8] as Map)['book'] == 'kharouf' ||
            (v[8] as Map).containsKey('farshFrom')),
  );

  // The idgham without ghunna over the two words as the reader reads each
  // (the sakt of «وَٱلۡۜأَرۡضِ» kept).
  // And as his farsh reads the word (حَقّٖ وَّيَقُولُ, Hamza's «ويقول»).
  final farshOf = {
    for (final v in rows)
      if (v[5] != 'u' && v[3] == 1 && '${v[4]}'.isNotEmpty)
        _key(v[0], v[1], v[2]): '${v[4]}',
  };
  String read(String k) => farshOf[k] ?? textAt[k] ?? index[k]!.t;
  for (final v in rows) {
    if (v[7] != 'idgham_bila_ghunna') continue;
    final a = _key(v[0], v[1], v[2]), b = _key(v[0], v[1], (v[2] as int) + 1);
    v[4] = _merged(read(a), read(b));
  }

  // One farsh row a word: the first told (a chapter here) over the book's.
  final farshAt = <String>{};
  rows.removeWhere(
    (v) => v[5] != 'u' && !farshAt.add('${_key(v[0], v[1], v[2])}:${v[3]}'),
  );

  // No stop on a hamza the reader's farsh leaves out (يُضَٰهُونَ).
  final farshText = {
    for (final v in rows)
      if (v[5] == 'f' && v[3] == 1) _key(v[0], v[1], v[2]): '${v[4]}',
  };
  bool hasHamza(String t) => RegExp('[ءأإؤئإٓٔ]').hasMatch(t);
  rows.removeWhere((v) {
    // Nor on one Hisham reads and Hamza does not, with Hafs (زَكَرِيَّا،
    // تُرۡجِي).
    if (v[7] != 'hisham_waqf') return false;
    final key = _key(v[0], v[1], v[2]);
    final t = farshText[key] ?? index[key]!.t;
    return !hasHamza(t);
  });
  // The kind of a final hamza Hafs does not read, by the reader's word.
  for (final v in rows) {
    if (v[7] != 'hisham_waqf') continue;
    final key = _key(v[0], v[1], v[2]);
    (v[8] as Map)['kind'] ??= waqfHamzaKindOfFinal(
      farshText[key] ?? index[key]!.t,
    );
  }
  // A word with a middle hamza and a final one (بِأَسۡمَآءِ): one row, the
  // middle hamzas first, each told by itself.
  {
    final middle = <String, List>{};
    for (final v in rows) {
      final meta = v.length > 8 && v[8] is Map ? v[8] as Map : const {};
      if (v[7] == 'hisham_waqf' && meta.containsKey('_parts')) {
        middle[_key(v[0], v[1], v[2])] = v;
      }
    }
    final merged = <List>{};
    for (final v in rows) {
      final first = middle[_key(v[0], v[1], v[2])];
      final meta = v.length > 8 && v[8] is Map ? v[8] as Map : const {};
      if (v[7] != 'hisham_waqf' ||
          first == null ||
          identical(first, v) ||
          meta['kind'] == 'الوقف على الساكن المفصول') {
        continue;
      }
      final parts = [
        ...((first[8] as Map)['_parts'] as List).map(
          (p) => (p as List).cast<String>(),
        ),
        (meta['ways'] as List).cast<String>(),
      ];
      final ways = [_byHamza(parts)];
      (first[8] as Map)['ways'] = ways;
      first[6] = 'وقفًا: ${ways.single}';
      merged.add(v);
    }
    rows.removeWhere(merged.contains);
    for (final v in rows) {
      if (v.length > 8 && v[8] is Map) (v[8] as Map).remove('_parts');
    }
  }

  // The Quranpedia rows still drawn: those on no word a chapter here tells,
  // and, till the farsh is built, those whose letters differ from Hafs's.
  String letters(String s) =>
      _bare(s)
          .replaceAll(RegExp('[^ء-ي ]'), '')
          .replaceAll(RegExp('[أإآءؤئى]'), 'ا')
          .replaceAll(' ', '');
  bool farsh(List v) {
    final hafs = [
      for (var i = 0; i < (v[3] as int); i++)
        index[_key(v[0], v[1], (v[2] as int) + i)]?.t ?? '',
    ].join(' ');
    final text = '${v[4]}'.replaceAll(RegExp(r'\(.*?\)|\[.*?\]|:.*'), '');
    return text.trim().isNotEmpty && letters(text) != letters(hafs);
  }

  bool covered(List v) =>
      !farsh(v) &&
      List.generate(
        v[3] as int,
        (i) => _key(v[0], v[1], (v[2] as int) + i),
      ).any(told.contains);
  data['variants'] =
      [
        for (final v in raw)
          if (!covered(v)) v,
        ...rows,
      ]..sort((x, y) {
        for (var i = 0; i < 3; i++) {
          final c = (x[i] as int).compareTo(y[i] as int);
          if (c != 0) return c;
        }
        return 0;
      });
  // An alif added to Hafs's rasm is the dagger one.
  applyDaggerAlif(quran, data['variants'] as List);
  return counts;
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  String read(String id) =>
      File('assets/data/qiraat/$id.json').readAsStringSync();
  final sources = AshabSources.load(read);
  final book =
      jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
  for (final id in ashabRiwayat) {
    final f = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(f.readAsStringSync()) as Map;
    final counts = buildAshabUsul(
      quran,
      data,
      id,
      sources,
      raw: ashabRaw(id),
      book: book,
    );
    stdout.writeln('$id: $counts');
    f.writeAsStringSync(jsonEncode(data));
  }
}
