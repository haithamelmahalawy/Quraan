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
import 'apply_first_sakin.dart';
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
        // Of the usul, «النقل», as Ibn Kathir's, though the book tells it
        // in its farsh (the user, 2026-11-14).
        'u',
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
    // «وَسۡـَٔلُواْ» the book tells in its farsh too: told once, in «النقل»
    // of the usul, not again in the hamesh (the user, 2026-11-14).
    bool naql(List v) => '${v[6]}'.startsWith('بنقل حركة الهمزة إلى السين');
    final naqlAt = {
      for (final v in rows)
        if (v[5] == 'u' && naql(v)) _key(v[0], v[1], v[2]),
    };
    rows.removeWhere(
      (v) => v[5] != 'u' && naql(v) && naqlAt.contains(_key(v[0], v[1], v[2])),
    );
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
  // None where his farsh starts the word otherwise (نُعَاسٗا تَغۡشَىٰ: the ta,
  // the tanween hidden before it).
  rows.removeWhere(
    (v) =>
        v[7] == 'idgham_bila_ghunna' &&
        !RegExp('^[وي]').hasMatch(read(_key(v[0], v[1], (v[2] as int) + 1))),
  );
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
  // By place, the rows of one word in the order made: List.sort is not
  // stable, and a row added elsewhere reordered them (a word's two-word
  // idgham before its sakt hid the word after it).
  final made = [
    for (final v in raw)
      if (!covered(v)) v,
    ...rows,
  ];
  final order = {for (final (i, v) in made.indexed) v: i};
  data['variants'] = made
    ..sort((x, y) {
      for (var i = 0; i < 3; i++) {
        final c = (x[i] as int).compareTo(y[i] as int);
        if (c != 0) return c;
      }
      return order[x]!.compareTo(order[y]!);
    });
  // An alif added to Hafs's rasm is the dagger one.
  applyDaggerAlif(quran, data['variants'] as List);
  // The small alif over a final ya where Hafs writes it (تَسَوَّىٰ، سَكۡرَىٰ،
  // يَخۡفَىٰ), the book's quotation without it (the user, 2026-11-14).
  final finalYa = RegExp(r'ى([ً-ٰٟۖ-ۭ]*)$');
  for (final v in (data['variants'] as List).cast<List>()) {
    if (v[5] == 'u' || v[3] != 1) continue;
    final text = '${v[4]}';
    final hafs = index[_key(v[0], v[1], v[2])]?.t ?? '';
    final mine = finalYa.firstMatch(text), his = finalYa.firstMatch(hafs);
    if (mine == null || his == null) continue;
    if (!his[1]!.contains('ٰ') || mine[1]!.contains('ٰ')) continue;
    v[4] = '${text.substring(0, mine.start)}ىٰ${mine[1]}';
  }
  // «هُزُوٗا» with its zay quiet and its hamza (Hamza, Khalaf al-'Ashir):
  // written as al-Kisa'i's «هُزُؤٗاۖ», its hamza on Hafs's waw, its zay quiet
  // (the user, 2026-11-12).
  for (final v in (data['variants'] as List).cast<List>()) {
    if (v[5] == 'u' || v[3] != 1) continue;
    final hafs = index[_key(v[0], v[1], v[2])]?.t ?? '';
    if (!RegExp('زُو').hasMatch(hafs) || !'${v[6]}'.contains('إسكان الزاي')) {
      continue;
    }
    v[4] = hafs.replaceFirst('زُو', 'زۡؤ');
  }
  _userFarsh(id, data['variants'] as List);
  _saktOnFarsh(data['variants'] as List);
  // al-Kisa'i's «وَهۡوَ، فَهۡوَ، لَهۡيَ» its ha quiet in all the places, as
  // Qalun's: the book names but some (الأنعام ١٧، ١٨ without) (the user,
  // 2026-11-14).
  if (_kisai.contains(id)) {
    final variants = data['variants'] as List;
    final told = {
      for (final v in variants.cast<List>())
        if ('${v[6]}'.contains('إسكان الهاء')) _key(v[0], v[1], v[2]),
    };
    for (final list in sources.verified['qalun']!.values) {
      for (final v in list) {
        if (v[3] != 1 || !'${v[6]}'.contains('إسكان الهاء')) continue;
        final key = _key(v[0], v[1], v[2]);
        final word = index[key];
        if (word == null || !RegExp(r'^[وفل]ه[وي]$').hasMatch(_bare(word.t))) {
          continue;
        }
        if (!told.add(key)) continue;
        int order(List r) =>
            (r[0] as int) * 1000000 + (r[1] as int) * 1000 + (r[2] as int);
        final row = [
          v[0],
          v[1],
          v[2],
          1,
          word.t.replaceFirst(RegExp('ه[ُِ]'), 'هۡ'),
          'f',
          'بإسكان الهاء',
          '',
          {'source': ashabSource, 'farshFrom': 'qalun'},
        ];
        final at = variants.cast<List>().indexWhere(
          (r) => order(r) > order(row),
        );
        variants.insert(at < 0 ? variants.length : at, row);
      }
    }
  }
  // al-Kisa'i's «أَرَيۡتُمۡ، أَرَيۡتَكُمۡ، أَفَرَيۡتَ» its second hamza gone in every
  // «أَرَءَيۡتَ» after the question's hamza: «وَحَيْثُ أَرَأَيْتَ فِي الاِسْتِفْهَامِ لاَ
  // عَيْنٌ رَاجِعٌ» (the user, 2026-11-14); Hafs's word, «ءَ» dropped.
  if (_kisai.contains(id)) {
    final variants = data['variants'] as List;
    int order(List r) =>
        (r[0] as int) * 1000000 + (r[1] as int) * 1000 + (r[2] as int);
    for (final word in words) {
      if (!RegExp('^أَ(?:فَ)?رَءَيۡت').hasMatch(word.t)) continue;
      variants.removeWhere(
        (r) =>
            r[5] == 'f' && r[0] == word.s && r[1] == word.a && r[2] == word.w,
      );
      final row = [
        word.s,
        word.a,
        word.w,
        1,
        word.t.replaceFirst('رَءَ', 'رَ'),
        'f',
        'بحذف الهمزة الثانية',
        '',
        {'source': ashabSource},
      ];
      final at = variants.cast<List>().indexWhere((r) => order(r) > order(row));
      variants.insert(at < 0 ? variants.length : at, row);
    }
  }
  // A ya of idafa read quiet before a hamza (يَدِيٓ إِلَيۡكَ، المائدة ٢٨): the
  // separated madd over it, as al-Ashab read it long (the user,
  // 2026-11-14).
  for (final v in (data['variants'] as List).cast<List>()) {
    if (v[7] != 'ya_idafa' || v[3] != 1) continue;
    final text = '${v[4]}';
    if (!RegExp(r'ي$').hasMatch(text)) continue;
    final next = index[_key(v[0], v[1], (v[2] as int) + 1)]?.t ?? '';
    if (RegExp('^[أإءآ]').hasMatch(next)) v[4] = '$textٓ';
  }
  // A word told leaned both in all states and at the stop alone: before a
  // quiescent (إِلَى ٱلۡهُدَى ٱئۡتِنَا) its alif gone in joining, leaned at the stop
  // alone (the user, 2026-11-14); else (أَهۡدَىٰ مِنۡهُمۡ) leaned in both.
  {
    final variants = data['variants'] as List;
    bool stopOnly(List v) => v.length > 8 && (v[8] as Map)['stopOnly'] == true;
    bool leaned(List v) => v[5] == 'u' && '${v[6]}'.contains('إمالة');
    final stops = {
      for (final v in variants.cast<List>())
        if (leaned(v) && stopOnly(v)) _key(v[0], v[1], v[2]),
    };
    final plains = {
      for (final v in variants.cast<List>())
        if (leaned(v) && !stopOnly(v) && '${v[4]}'.isEmpty)
          _key(v[0], v[1], v[2]),
    };
    variants.removeWhere((r) {
      final v = r as List;
      final key = _key(v[0], v[1], v[2]);
      if (!leaned(v) || !stops.contains(key) || !plains.contains(key)) {
        return false;
      }
      final next = index[_key(v[0], v[1], (v[2] as int) + 1)]?.t ?? '';
      final quiet = next.startsWith('ٱ');
      return quiet
          ? !stopOnly(v) && '${v[4]}'.isEmpty
          : stopOnly(v) && '${v[6]}' == 'بإمالة الألف وقفًا';
    });
  }
  // «رَءَا» before a quiescent (رَءَا ٱلشَّمۡسَ، وَرَءَا ٱلۡمُجۡرِمُونَ، تَرَٰٓءَا ٱلۡجَمۡعَانِ):
  // Hamza and Khalaf al-'Ashir lean its ra in joining, its sign drawn; at the
  // stop the ra and the hamza, as al-Kisa'i, who leans it at the stop alone
  // (the user, 2026-11-14).
  if (_hamza.contains(id) || _khalafAshir.contains(id)) {
    final variants = data['variants'] as List;
    int order(List r) =>
        (r[0] as int) * 1000000 + (r[1] as int) * 1000 + (r[2] as int);
    for (final word in words) {
      if (!RegExp(r'^[وف]?ت?رءا$').hasMatch(_bare(word.t))) continue;
      final next = index[_key(word.s, word.a, word.w + 1)]?.t ?? '';
      if (!next.startsWith('ٱ')) continue;
      final row = [
        word.s,
        word.a,
        word.w,
        1,
        word.t.replaceFirst('رَ', 'رَ۪'),
        'u',
        'بإمالة الراء وصلًا',
        '',
        {'source': ashabSource},
      ];
      variants.removeWhere(
        (r) =>
            r[5] == 'u' &&
            order(r) == order(row) &&
            r[6] == 'بإمالة الراء وصلًا',
      );
      final at = variants.cast<List>().indexWhere((r) => order(r) > order(row));
      variants.insert(at < 0 ? variants.length : at, row);
    }
  }
  // The ha of silence in the usul, as Ya'qub's (يَتَسَنَّه۠، ٱقۡتَدِه۠: «وَاقْتَدِهْ
  // حَذْفُ هَائِهِ شِفَاءً»), not the hamesh; Hamza's «مَالِيَه۠، سُلۡطَٰنِيَه۠، هِيَه۠»
  // too: «وَيَخْفَى شِفَاءً مَالِيَهْ مَاهِيَهْ فَصِلْ / وَسُلْطَانِيَهْ مِنْ دُونِ هَاءٍ
  // فَتُوصلَا» (the user, 2026-11-14).
  {
    final variants = data['variants'] as List;
    const ways = ['حذف هاء السكت وصلاً', 'إثبات هاء السكت وقفًا'];
    int order(List r) =>
        (r[0] as int) * 1000000 + (r[1] as int) * 1000 + (r[2] as int);
    for (final v in variants.cast<List>()) {
      if (v[5] != 'f' || v[6] != 'بحذف الهاء وصلًا وإثباتها وقفًا') continue;
      v[5] = 'u';
      v[6] = 'بحذف هاء السكت وصلاً وإثباتها وقفًا';
      v[7] = 'ha_sakt';
      v[8] = {...(v[8] as Map), 'ways': ways};
    }
    if (_hamza.contains(id)) {
      for (final (s, a, w) in const [(69, 28, 3), (69, 29, 2), (101, 10, 3)]) {
        final row = [
          s,
          a,
          w,
          1,
          index[_key(s, a, w)]!.t.replaceAll('ۜ', '').replaceFirst('هۡ', 'ه۠'),
          'u',
          'بحذف هاء السكت وصلاً وإثباتها وقفًا',
          'ha_sakt',
          {'source': ashabSource, 'ways': ways},
        ];
        variants.removeWhere((r) => r[7] == 'ha_sakt' && order(r) == order(row));
        final at = variants.cast<List>().indexWhere(
          (r) => order(r) > order(row),
        );
        variants.insert(at < 0 ? variants.length : at, row);
      }
    }
  }
  // «التقاء الساكنين» for al-Kisa'i and Khalaf al-'Ashir in all its places,
  // not those the book names alone (the user, 2026-11-14).
  applyFirstSakin(id, quran, data['variants'] as List);
  return counts;
}

/// The farsh the user set (2026-11-12) where the book's rows fall short.
void _userFarsh(String id, List variants) {
  const kisai = {'abul_harith', 'duri_kisai'};
  const hamza = {'khalaf_hamzah', 'khallad'};
  const khalaf = {'ishaq', 'idris'};
  List? at(int s, int a, int w) => variants
      .cast<List>()
      .where((v) => v[0] == s && v[1] == a && v[2] == w && v[5] == 'f')
      .firstOrNull;
  void put(List row) {
    final old = at(row[0] as int, row[1] as int, row[2] as int);
    if (old != null) variants.remove(old);
    final i = variants.cast<List>().indexWhere(
      (v) =>
          (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int) >
          (row[0] as int) * 1000000 + (row[1] as int) * 1000 + (row[2] as int),
    );
    variants.insert(i < 0 ? variants.length : i, row);
  }

  // «تُمَٰٓسُّوهُنَّ»: the madd over the dagger alif, the madd lazim.
  for (final v in variants.cast<List>()) {
    final letters = '${v[4]}'.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '');
    if (v[5] == 'f' && letters == 'تمسوهن' && '${v[4]}'.contains('ٰ')) {
      v[4] = 'تُمَٰٓسُّوهُنَّ';
      v[6] = 'بضم التاء وتشديد السين مع المد المشبع';
    }
  }
  // «تَسَوَّىٰ» النساء ٤٢: its ta opened and its waw leaned (the user,
  // 2026-11-14); the book's quotation, its small alif left out, told a ya
  // quiet and an alif gone.
  if (at(4, 42, 7) case final v?) v[6] = 'بفتح التاء وبإمالة الواو';
  // «فَتَثَبَّتُواْ» for «فَتَبَيَّنُواْ» (النساء ٩٤ مرتين، الحجرات ٦), Hamza's,
  // al-Kisa'i's and Khalaf al-'Ashir's; the book tells it in al-Hujurat
  // alone, and without its wording (the user, 2026-11-14). Hafs's word, its
  // madd and stop sign kept, its letters changed.
  if (kisai.contains(id) || hamza.contains(id) || khalaf.contains(id)) {
    for (final (s, a, w, text) in const [
      (4, 94, 8, 'فَتَثَبَّتُواْ'),
      (4, 94, 32, 'فَتَثَبَّتُوٓاْۚ'),
      (49, 6, 7, 'فَتَثَبَّتُوٓاْ'),
    ]) {
      put([
        s,
        a,
        w,
        1,
        text,
        'f',
        'بفاء ثم تاء ثم ثاء ثم باء مفتوحة ثم تاء مضمومة ثم واو',
        '',
        {'source': ashabSource},
      ]);
    }
  }
  // «نُؤۡتِيهِمۡ» النساء ١٥٢ with the nun for Hamza too, as al-Kisa'i's: the
  // ya is Hafs's alone, «وَيَا سَوْفَ نُؤْتِيهِمْ عَزِيزٌ»; the book's farsh left
  // him out (2026-11-14).
  if (hamza.contains(id)) {
    put([
      4,
      152,
      11,
      1,
      'نُؤۡتِيهِمۡ',
      'f',
      'بالنون',
      '',
      {'source': ashabSource, 'farshFrom': 'shubah'},
    ]);
  }
  // «وَقَتۡلِهُمُ ٱلۡأَنۢبِيَآءَ» النساء ١٥٥: the book quotes the two words for
  // the ha's damma, told on «وَقَتۡلِهُمُ» in the usul; «ٱلۡأَنۢبِيَآءَ» read as
  // Hafs's, no farsh of its own («بالهمز والقصر» was the quotation's) (the
  // user, 2026-11-14).
  variants.removeWhere(
    (v) => v[0] == 4 && v[1] == 155 && v[2] == 7 && v[5] == 'f',
  );
  // Hamza's «إِلَيۡهُمۡ» النساء ٦ (twice): the book's «إليهُم معاً» quoted with
  // «عليهُم» as a farsh of its own, its text broken; the ha's damma is told
  // in the usul (the user, 2026-11-14).
  variants.removeWhere(
    (v) => v[0] == 4 && v[1] == 6 && v[5] == 'f' && '${v[4]}'.contains('،'),
  );
  // al-Kisa'i's «يُكۡذِبُونَكَۖ» الأنعام ٣٣ with its nun's fatha and the stop
  // sign, as Qalun's (the user, 2026-11-14).
  if (kisai.contains(id)) {
    if (at(6, 33, 8) case final v?) v[4] = 'يُكۡذِبُونَكَۖ';
  }
  // «إِلَٰهَيۡنِ» المائدة ١١٦ read as Hafs's: the book quotes it with «وَأُمِّيٓ»
  // for the ya of idafa; no farsh of its own, no colour (the user,
  // 2026-11-14).
  variants.removeWhere(
    (v) => v[0] == 5 && v[1] == 116 && v[2] == 11 && v[5] == 'f',
  );
  // al-Kisa'i's «هَل تَّسۡتَطِيعُ رَبَّكَ» المائدة ١١٢: «هل» with them, its lam
  // bare, merged into the ta, shaded and in the hamesh (the user,
  // 2026-11-14).
  if (kisai.contains(id)) {
    variants.removeWhere(
      (v) => v[0] == 5 && v[1] == 112 && v[2] == 7 && v[5] == 'f',
    );
    put([
      5,
      112,
      6,
      3,
      'هَل تَّسۡتَطِيعُ رَبَّكَ',
      'f',
      'بالتاء وإدغام لام «هل» فيها وفتح باء «ربك»',
      '',
      {'source': ashabSource},
    ]);
  }
  // al-Duri's «وَٱلۡكُفَّارِ» المائدة ٥٧: its ra with a kasra and its alif
  // leaned, the sign under the fa; told in the usul's imala too, the hamesh
  // kept (the user, 2026-11-14). Abu al-Harith's opened, as the book's.
  if (id == 'duri_kisai') {
    if (at(5, 57, 16) case final v?) {
      v[4] = 'وَٱلۡكُفّ۪ارِ';
      v[6] = 'بكسر الراء وإمالة الفاء';
    }
    final leaned = variants.cast<List>().any(
      (v) =>
          v[0] == 5 &&
          v[1] == 57 &&
          v[2] == 16 &&
          v[5] == 'u' &&
          '${v[6]}'.contains('مال'),
    );
    if (!leaned) {
      final i = variants.cast<List>().indexWhere(
        (v) => v[0] == 5 && v[1] == 57 && v[2] == 16,
      );
      variants.insert(i < 0 ? variants.length : i, [
        5,
        57,
        16,
        1,
        '',
        'u',
        'بإمالة الألف',
        '',
        {'source': ashabSource},
      ]);
    }
  }
  // «يُظۡلَمُونَ» النساء ٧٧: by the ya alone, as Ibn Kathir's and Abu
  // Ja'far's, not Rawh's «وترقيق اللام» (the user, 2026-11-14).
  if (at(4, 77, 46) case final v?) {
    v[6] = 'بالياء';
    (v[8] as Map)['farshFrom'] = 'bazzi';
  }
  // «لَمَسۡتُمُ» النساء ٤٣ for al-Kisa'i too, as Khalaf al-'Ashir's, in
  // letters and hamesh, as in المائدة ٦; the book names him not there (the
  // user, 2026-11-14).
  if (kisai.contains(id)) {
    put([
      4,
      43,
      32,
      1,
      'لَمَسۡتُمُ',
      'f',
      'بحذف الألف',
      '',
      {'source': ashabSource},
    ]);
  }
  // «وَيَبۡصُطُ» البقرة ٢٤٥ with the sad, the small sin above it gone, as the
  // verified readers who read it so (Qalun, Shu'ba).
  if (kisai.contains(id)) {
    put([
      2,
      245,
      13,
      1,
      'وَيَبۡصُطُ',
      'f',
      'بالصاد',
      '',
      {'source': ashabSource, 'farshFrom': 'shubah'},
    ]);
    // «بَصۡطَةٗ» الأعراف ٦٩ so too (the user, 2026-11-14).
    put([
      7,
      69,
      21,
      1,
      'بَصۡطَةٗۖ',
      'f',
      'بالصاد',
      '',
      {'source': ashabSource, 'farshFrom': 'shubah'},
    ]);
  }
  // «يَتَسَنَّه۠» البقرة ٢٥٩: the ha gone joined and kept at the stop, the
  // oval of «أنا» on it for its sukun, as Ya'qub's.
  if (kisai.contains(id) || hamza.contains(id) || khalaf.contains(id)) {
    put([
      2,
      259,
      41,
      1,
      'يَتَسَنَّه۠ۖ',
      'f',
      'بحذف الهاء وصلًا وإثباتها وقفًا',
      '',
      {'source': ashabSource, 'farshFrom': 'ruways'},
    ]);
  }
  // Khallad's «وَيَبۡصُۣطُ»: the sad and the sin, the sad first (the
  // Taysir's), the small sin under the sad as the Madinah script writes
  // a sad read both ways first (ٱلۡمُصَۣيۡطِرُونَ).
  if (id == 'khallad') {
    put([
      2,
      245,
      13,
      1,
      'وَيَبۡصُۣطُ',
      'f',
      'بالصاد والسين، والصاد هو المقدّم',
      '',
      {
        'source': ashabSource,
        'ways': ['الصاد، وهو المقدّم', 'السين'],
      },
    ]);
  }
  // «ٱقۡتَدِه۠» الأنعام ٩٠: as «يَتَسَنَّه۠», the ha gone joined and kept at
  // the stop, the hamza of the imperative a hamzat al-wasl.
  if (at(6, 90, 5) case final v?) {
    v[4] = 'ٱقۡتَدِه۠ۗ';
    v[6] = 'بحذف الهاء وصلًا وإثباتها وقفًا';
    (v[8] as Map)['farshFrom'] = 'ruways';
  }
  // «وَقُتِلُواْ وَقَٰتَلُواْ» آل عمران ١٩٥: the two words in the other order
  // («هُنَا قَاتَلُوا أَخِّرْ شِفَاءً»), each told at its own word: the
  // first's row the book's, the second, Hafs's «وَقُتِلُواْ», read
  // «وَقَٰتَلُواْ» with the dagger alif (the user, 2026-11-12).
  if (at(3, 195, 24) case final v?) {
    put([
      3,
      195,
      25,
      1,
      'وَقَٰتَلُواْ',
      'f',
      'بفتح القاف وإثبات الألف وفتح التاء',
      '',
      {...(v[8] as Map), 'source': ashabSource},
    ]);
  }
  // «فَنَادَىٰهُ» آل عمران ٣٩: Hafs's ta's tooth without its dots, the
  // dagger alif on it (as «هَدَىٰهُمُ»), not a full alif.
  if (at(3, 39, 0) case final v?) v[4] = 'فَنَادَىٰهُ';
  // «تَغۡشَىٰ» آل عمران ١٥٤: Hafs's word, its ya a ta; the dagger alif kept
  // over the ya, the ta the only difference.
  if (at(3, 154, 8) case final v?) {
    v[4] = 'تَغۡشَىٰ';
    v[6] = 'بالتاء';
  }
  // «وَٱلَّيۡسَعَ» (الأنعام ٨٦، ص ٤٨), Hamza's, al-Kisa'i's and Khalaf
  // al-'Ashir's: its lam doubled, its ya quiet (the user, 2026-11-14).
  for (final (s, a, w) in const [(6, 86, 1), (38, 48, 2)]) {
    if (at(s, a, w) case final v?) {
      v[4] = 'وَٱلَّيۡسَعَ';
      v[6] = 'بتشديد اللام وإسكان الياء';
    }
  }
  // «قَالَ ٱعۡلَمۡ»: the hamza of the imperative, a hamzat al-wasl.
  if (at(2, 259, 60) case final v?) {
    v[4] = 'ٱعۡلَمۡ';
    v[6] = 'بإبدال همزة القطع همزة وصل وإسكان الميم';
  }
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

/// A sakt drawn on Hafs's word where the riwaya reads other letters
/// (سَنُؤۡتِيهِمۡۜ for Hamza's «سَيُؤۡتِيهِمۡ»، هُزُوًۜا for «هُزۡؤًا»): drawn on
/// the farsh's word instead, its sign where it stood, so the word shows as
/// read (2026-11-14).
void _saktOnFarsh(List variants) {
  // Its letters, its shadda and small alif kept: «ٱلۡأَوۡلَيَٰنِ» is not
  // «ٱلۡأَوَّلِينَ» (the user, 2026-11-14).
  String letters(String s) =>
      s.replaceAll(RegExp('[ً-ِْ-ٟۖ-ۭـ]'), '').replaceAll('ٱ', 'ا');
  // A sakt on the article's lam, at the word's head.
  final article = RegExp(r'^((?:[وفبكل][َُِ]?)?[ٱا]لۡ)');
  final farsh = <String, String>{
    for (final v in variants.cast<List>())
      if (v[5] == 'f' && v[3] == 1)
        if ('${v[4]}' case final t
            when t.isNotEmpty && !t.contains(RegExp('[ ،]')))
          _key(v[0], v[1], v[2]): t,
  };
  for (final v in variants.cast<List>()) {
    final text = '${v[4]}';
    if (v[5] != 'u' || v[3] != 1 || !text.contains('ۜ')) continue;
    final own = farsh[_key(v[0], v[1], v[2])];
    if (own == null || letters(own) == letters(text)) continue;
    if (RegExp(r'^(?:[وفبكل][َُِ]?)?[ٱا]لۡۜ').hasMatch(text) &&
        article.hasMatch(own)) {
      v[4] = own.replaceFirstMapped(article, (m) => '${m[1]}ۜ');
      continue;
    }
    // What follows the sign in Hafs's word (the tanween's alif, a stop
    // sign): the sign before the same in the farsh's word.
    final after = text.substring(text.lastIndexOf('ۜ') + 1);
    v[4] = after.isNotEmpty && own.endsWith(after)
        ? '${own.substring(0, own.length - after.length)}ۜ$after'
        : RegExp(r'[ۖ-ۛ]$').hasMatch(own)
        ? '${own.substring(0, own.length - 1)}ۜ${own.substring(own.length - 1)}'
        : '$ownۜ';
  }
}
