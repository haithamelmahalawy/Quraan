// Refines Warsh's boundary hamza rules and stopping taqlil from the Hafs
// context and the transcribed book. Run after the other data tools:
//   dart run tool/build_warsh_usul.dart
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

typedef _Word = ({int surah, int ayah, int word, String text});

const _rules = {
  'naql',
  'naql_source',
  'hamza_source',
  'ibdal_waw',
  'ibdal_ya',
  'tasheel_pair',
  'tasheel_word',
  'ibdal_pair',
  'ibdal_single',
  'taqlil_stop',
  'ha_antum',
  'hamza_wasl',
};

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final book =
      jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
  final file = File('assets/data/qiraat/warsh.json');
  final data = jsonDecode(file.readAsStringSync()) as Map;
  final counts = correctWarshUsul(quran, book, data['variants'] as List);
  file.writeAsStringSync(jsonEncode(data));
  stdout.writeln('Warsh usul: $counts');
}

/// Keeps the source's word readings; tags the rules and supplies both words
/// for the footer. Explicit hamza replacement is represented on the Hafs
/// word by a circled letter, rather than changing its orthography.
Map<String, int> correctWarshUsul(Map quran, Map book, List variants) {
  final words = <_Word>[
    for (final a in quran['ayahs'] as List)
      for (final (w, text) in (a[4] as String).split(' ').indexed)
        (surah: a[0] as int, ayah: a[1] as int, word: w, text: text),
  ];
  String key(_Word w) => '${w.surah}:${w.ayah}:${w.word}';
  final source = {for (final w in words) key(w): w};
  final at = <String, List<List>>{};
  for (final raw in variants) {
    final v = raw as List;
    (at['${v[0]}:${v[1]}:${v[2]}'] ??= []).add(v);
  }
  final counts = <String, int>{};
  List? reading(_Word w) {
    final candidates =
        at[key(w)]
            ?.where((v) => v.length < 8 || v[7] == '' || _rules.contains(v[7]))
            .toList() ??
        const <List>[];
    return candidates
            .where((v) => v.length > 7 && _rules.contains(v[7]))
            .firstOrNull ??
        candidates
            .where((v) => v[3] == 1 && !(v[4] as String).contains(' '))
            .firstOrNull ??
        candidates.firstOrNull;
  }

  List add(_Word w) {
    final v = <Object?>[w.surah, w.ayah, w.word, 1, '', 'h', ''];
    variants.add(v);
    (at[key(w)] ??= []).add(v);
    return v;
  }

  String endingText(_Word w) {
    // Hafs does not have the final hamza of Warsh's النبيء / زكرياء.
    // Do not use a description-only rule in place of the actual reading.
    final p = at[key(w)]
        ?.where(
          (v) =>
              v[3] == 1 &&
              (v[4] as String).isNotEmpty &&
              !(v[4] as String).contains(' '),
        )
        .firstOrNull;
    if (p != null && _hamza(_ending(p[4] as String))) {
      return madinahScript(p[4] as String);
    }
    return w.text;
  }

  void tag(
    List v,
    String rule,
    String how, {
    String? context,
    bool stop = false,
    List<String> ways = const [],
  }) {
    final farsh = v[5] == 'f' ? _farshOnly(v[6] as String) : '';
    if (farsh.isNotEmpty && rule != 'naql_source' && rule != 'hamza_source') {
      // One word can contain both a lexical variant and a hamza rule.
      // Keep the former for the margin and add a description-only rule.
      v[6] = farsh;
      final w = source['${v[0]}:${v[1]}:${v[2]}']!;
      v =
          at[key(w)]
              ?.where((p) => p.length > 7 && p[7] == rule && p[4] == '')
              .firstOrNull ??
          add(w);
    }
    while (v.length < 9) {
      v.add(null);
    }
    v[5] = rule == 'taqlil_stop' ? 'u' : 'h';
    v[6] = how;
    v[7] = rule;
    v[8] = <String, Object>{
      'context': ?context,
      if (stop) 'stopOnly': true,
      if (ways.isNotEmpty) 'ways': ways,
    };
    counts[rule] = (counts[rule] ?? 0) + 1;
  }

  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final previous = i > 0 && words[i - 1].surah == w.surah
        ? words[i - 1]
        : null;
    var v = reading(w);
    final how = v != null && v.length > 6 ? v[6] as String : '';
    final first = lettersOf(w.text).first;
    final previousText = previous == null ? '' : endingText(previous);
    final last = previous == null ? '' : _ending(previousText);
    final pair = previous == null ? '' : '$previousText ${w.text}';
    final firstHamza = _hamza(first);
    final lastHamza = _hamza(last) && !RegExp('[ًٌٍٖٗٞ]').hasMatch(last);
    final cs = lettersOf(w.text);

    // The third, originally sakin hamza is already written as an alif in
    // Hafs. Warsh adds the interrogative and facilitates the middle one;
    // that middle hamza has no ibdal face in these three occurrences.
    if ((w.surah == 7 && w.ayah == 123 && w.word == 2) ||
        (w.surah == 20 && w.ayah == 71 && w.word == 1) ||
        (w.surah == 26 && w.ayah == 49 && w.word == 1)) {
      v ??= add(w);
      v[4] = w.text.replaceFirst('ءَا', 'ءَاٰ۬');
      v[5] = 'h';
      const ways = [
        'تحقيق الأولى وتسهيل الثانية بلا إدخال مع ثلاثة البدل؛ ولا إبدال للثانية',
      ];
      tag(v, 'tasheel_word', ways.single, context: w.text, ways: ways);
      continue;
    }
    if (RegExp(r'^هَٰٓأَنتُم').hasMatch(w.text)) {
      v ??= add(w);
      v[5] = 'h';
      const ways = [
        'حذف الألف بعد الهاء وتسهيل الهمزة بين بين',
        'حذف الألف بعد الهاء وإبدال الهمزة ألفًا مع المد المشبع (٦ حركات)',
      ];
      tag(
        v,
        'ha_antum',
        'بوجهين: ${ways.join('؛ أو ')}',
        context: w.text,
        ways: ways,
      );
      continue;
    }
    // Interrogative followed by the al- wasl hamza: distinguish this
    // from two qat' hamzas. These faces also occur in Hafs.
    if (RegExp(r'^ءَآل').hasMatch(w.text)) {
      v ??= add(w);
      final alan = w.text.contains('ـَٰٔن');
      final ways = [
        'تسهيل همزة الوصل بلا إدخال',
        alan
            ? 'إبدال همزة الوصل ألفًا مع القصر أو الإشباع بعد نقل حركة همزة الآن إلى اللام'
            : 'إبدال همزة الوصل ألفًا مع المد المشبع (٦ حركات)',
      ];
      v[5] = 'h';
      tag(
        v,
        'hamza_wasl',
        'بوجهين: ${ways.join('؛ أو ')}',
        context: w.text,
        ways: ways,
      );
      continue;
    }
    if (v != null &&
        cs.length > 1 &&
        _hamza(cs[0]) &&
        _hamza(cs[1]) &&
        _vowel(cs[0]) == 'َ') {
      final open = _vowel(cs[1]) == 'َ';
      final readingFirst = (v[4] as String).isEmpty
          ? ''
          : lettersOf(v[4] as String).first;
      // A riwaya that reads by ikhbar has no interrogative hamza here.
      // Its lexical difference must not be replaced by a tasheel rule.
      if (open || (_hamza(readingFirst) && _vowel(readingFirst) == 'َ')) {
        final ways = [
          'تسهيل الهمزة الثانية بلا إدخال',
          // A third hamza changed to madd (ءأٰلهتنا) rules out this face.
          if (open && !cs[1].contains('ٰ'))
            _ibdal('ألفًا', _hasSakin(cs[2]) ? 6 : 2),
        ];
        // These are all recitation rules; the source's generic comparison
        // may have labelled their spelling as farsh.
        v[5] = 'h';
        tag(
          v,
          'tasheel_word',
          [
            ways.length == 1
                ? 'ب${ways.single}'
                : 'بوجهين: ${ways.join('؛ أو ')}',
            if (how.contains('صلة ميم الجمع')) 'بصلة ميم الجمع',
          ].join('، '),
          context: w.text,
          ways: ways,
        );
        continue;
      }
      // Ikhbar is a separate lexical choice, even if naql also acts on
      // its remaining hamza after a sakin/tanween. Keep both records.
      if (_vowel(cs[1]) == 'ِ' && _vowel(readingFirst) == 'ِ') {
        final lexicalRows = at[key(w)]!
            .where((p) => p.length < 8 || p[7] == '')
            .toList();
        final lexical = lexicalRows.firstOrNull ?? add(w);
        lexical[4] = v[4];
        lexical[5] = 'f';
        lexical[6] = 'بالإخبار بهمزة واحدة';
        for (final duplicate in lexicalRows.skip(1)) {
          if (duplicate[4] == lexical[4] &&
              RegExp('همزة').hasMatch(duplicate[6] as String)) {
            variants.remove(duplicate);
            at[key(w)]!.remove(duplicate);
          }
        }
      }
    }
    if (previous != null && firstHamza && lastHamza) {
      final a = _vowel(last), b = _vowel(first);
      String rule, description;
      List<String> ways;
      if (a == 'ُ' && (b == 'َ' || b == 'ِ')) {
        rule = 'ibdal_waw';
        ways = [
          b == 'َ'
              ? 'إبدال الهمزة الثانية واوًا خالصة وصلاً'
              : 'إبدال الهمزة الثانية واوًا مكسورة خالصة وصلاً',
          if (b == 'ِ') 'تسهيل الهمزة الثانية بين بين وصلاً',
        ];
      } else if (a == 'ِ' && b == 'َ') {
        rule = 'ibdal_ya';
        ways = ['إبدال الهمزة الثانية ياءً خالصة وصلاً'];
      } else if ((a == 'َ' && (b == 'ِ' || b == 'ُ')) ||
          (a != null && a == b)) {
        rule = 'tasheel_pair';
        ways = a == b
            ? _sameVowelWays(w, a!)
            : ['تسهيل الهمزة الثانية بين بين وصلاً'];
      } else {
        continue;
      }
      description = 'ب${ways.join('؛ أو ')}';
      // These accompanying rules are independent of the hamza face.
      for (final other in ['صلة ميم الجمع', 'التقليل', 'الإمالة']) {
        if (how.contains(other)) description += '، ب$other';
      }
      v ??= add(w);
      // Use the Hafs hamza with the explicit circled replacement in the
      // display. The Maghribi tasheel dot on an alif is not a wasl sign.
      final shown = lettersOf(v[4] as String);
      if (shown.isNotEmpty) {
        final prefix = shown.first.startsWith('ا') ? cs.first : shown.first;
        // Maghribi اٰ۬ represents both the changed hamza and its following
        // badal alif. Restoring the hamza must retain that alif too.
        final alif =
            cs.length > 1 &&
                cs[1].startsWith('ا') &&
                shown.length > 1 &&
                !shown[1].startsWith('ا')
            ? cs[1]
            : '';
        v[4] = '$prefix$alif${shown.skip(1).join()}';
      }
      tag(v, rule, description, context: pair, ways: ways);
      // A generic spelling comparison can misdescribe the preceding
      // hamza's vowel too. Keep that reading out of the farsh margin.
      final p = reading(previous);
      if (p != null &&
          p[3] == 1 &&
          RegExp(r'^ب(فتح|كسر|ضم) الهمزة$').hasMatch(p[6] as String)) {
        tag(p, 'hamza_source', description);
      }
      continue;
    }
    if (v == null) continue;
    if (how.contains('نقل حركة الهمزة إلى اللام')) {
      tag(v, 'naql', how, context: w.text);
    } else if (previous != null &&
        firstHamza &&
        _sakinEnd(previous.text) &&
        RegExp(r'^ا[َُِء-ي]').hasMatch(madinahScript(v[4] as String))) {
      tag(
        v,
        'naql',
        [
          'بنقل حركة الهمزة إلى الساكن قبلها وصلاً',
          if (how.contains('صلة ميم الجمع')) 'بصلة ميم الجمع',
          if (how.contains('التقليل')) 'بالتقليل',
          if (how.contains('الإمالة')) 'بالإمالة',
          if (how.contains('الإدغام')) 'بالإدغام',
        ].join('، '),
        context: pair,
      );
      final p = reading(previous);
      if (p != null &&
          p[3] == 1 &&
          RegExp(r'^(ب(فتح|كسر|ضم) (ال)?[ء-ي]+|بنقل حركة الهمزة إليها)$')
              .hasMatch(p[6] as String)) {
        tag(p, 'naql_source', 'بنقل حركة الهمزة إليها');
      }
    } else if (_singleIbdal(w.text, v[4] as String, how)
        case final String refined) {
      tag(v, 'ibdal_single', refined, context: w.text);
    } else if (how.contains('إبدال الهمزة') && !how.contains('استفهام')) {
      tag(v, 'ibdal_single', how, context: w.text);
    }
  }

  // The tanweened final alif is dropped in wasl. Its taqlil is visible
  // only on stopping, and is not spelled in the continuous KFGQPC text.
  for (final e in book['entries'] as List) {
    if (e[4] != 'mumal') continue;
    final mine = (e[5] as List).where(
      (g) =>
          ((g[1] as List).contains('warsh') ||
              (g[2] as List).contains('warsh')) &&
          (g[5] == true || (g[3] as String).contains('تقليل')),
    );
    if (mine.isEmpty) continue;
    final w = source['${e[0]}:${e[1]}:${e[2]}'];
    if (w == null || !RegExp(r'[ًٗ].*[ىا][ۖ-ۜ]?$').hasMatch(w.text)) continue;
    final v = reading(w) ?? add(w);
    tag(v, 'taqlil_stop', 'بالتقليل وقفًا', stop: true);
  }
  variants.sort((a, b) {
    for (var i = 0; i < 3; i++) {
      final c = (a[i] as int).compareTo(b[i] as int);
      if (c != 0) return c;
    }
    final ruleA = a.length > 7 ? a[7] as String? ?? '' : '';
    final ruleB = b.length > 7 ? b[7] as String? ?? '' : '';
    final c = ruleA.compareTo(ruleB);
    if (c != 0) return c;
    for (final i in [4, 5, 6]) {
      final c = (a[i] as String).compareTo(b[i] as String);
      if (c != 0) return c;
    }
    return 0;
  });
  return counts;
}

String _ibdal(String letter, int length) =>
    'إبدال الهمزة الثانية $letter مع ${length == 6 ? 'المد المشبع (٦ حركات)' : 'القصر (حركتان)'}';

bool _hasSakin(String cluster) =>
    RegExp('[ّْۡ]').hasMatch(cluster) || _vowel(cluster) == null;

List<String> _sameVowelWays(_Word w, String vowel) {
  const tasheel = 'تسهيل الهمزة الثانية بين بين وصلاً';
  // The madd that follows the facilitated hamza is a changed badal.
  // On ibdal the two alifs merge (qasr) or are kept apart (ishba').
  if ((w.surah == 15 && w.ayah == 61) || (w.surah == 54 && w.ayah == 41)) {
    return [
      for (final n in ['حركتان', '٤ حركات', '٦ حركات'])
        '$tasheel مع مد البدل $n',
      _ibdal('ألفًا', 2),
      _ibdal('ألفًا', 6),
    ];
  }
  final letter = vowel == 'َ'
      ? 'ألفًا'
      : vowel == 'ِ'
      ? 'ياءً مدية'
      : 'واوًا مدية';
  final arid =
      (w.surah == 33 && (w.ayah == 32 || w.ayah == 50)) ||
      (w.surah == 24 && w.ayah == 33);
  // The waw of أولئك is silent; the pronounced lam is moving.
  final sakin =
      !(w.surah == 46 && w.ayah == 32) && _hasSakin(lettersOf(w.text)[1]);
  return [
    tasheel,
    if (arid) ...[
      '${_ibdal(letter, 6)} اعتبارًا بالسكون الأصلي',
      '${_ibdal(letter, 2)} اعتدادًا بالحركة العارضة',
    ] else
      _ibdal(letter, sakin ? 6 : 2),
    if (vowel == 'ِ' &&
        ((w.surah == 2 && w.ayah == 31) || (w.surah == 24 && w.ayah == 33)))
      'إبدال الهمزة الثانية ياءً مكسورة خالصة وصلاً',
  ];
}

/// Refine the source's ambiguous "تخفيف" only where the actual single
/// hamza has been replaced. Derivatives of الإيواء retain their hamza.
String? _singleIbdal(String hafs, String reading, String how) {
  if (how != 'بتخفيف الهمزة' &&
      !RegExp(r'^بإبدال الهمزة (الساكنة|المفتوحة) (ألفًا|ياءً|واوًا)$')
          .hasMatch(how)) {
    return null;
  }
  if (reading.isEmpty || reading.contains(' ')) return null;
  final h = lettersOf(hafs), r = lettersOf(madinahScript(reading));
  if (h.length != r.length || h.where(_hamza).length != 1) return null;
  for (var i = 1; i < h.length; i++) {
    if (!_hamza(h[i]) || _hamza(r[i])) continue;
    final before = _vowel(h[i - 1]);
    final sakin = RegExp('[ْۡ]').hasMatch(h[i]);
    final moving = before == 'ُ' && _vowel(h[i]) == 'َ';
    if (!sakin && !moving) return null;
    final replacement = before == 'َ'
        ? 'ا'
        : before == 'ِ'
        ? 'ي'
        : 'و';
    if (r[i][0] != replacement) return null;
    final letter = replacement == 'ا'
        ? 'ألفًا'
        : replacement == 'ي'
        ? 'ياءً'
        : 'واوًا';
    return 'بإبدال الهمزة ${sakin ? 'الساكنة' : 'المفتوحة'} $letter';
  }
  return null;
}

String _farshOnly(String description) {
  var s = description.replaceAll(
    RegExp(
      r'ب?صلة ميم الجمع|ب?تخفيف الهمزة|ب?إبدال الهمزة (واوًا|ألفًا|ياءً)|'
      r'ب?الإدغام|ب?المد|ب?القصر|ب?التقليل|ب?الإمالة',
    ),
    '',
  );
  s = s.replaceAll(RegExp(r'^[بو\s،]+|[و\s،]+$'), '').trim();
  return s.isEmpty ? '' : 'ب$s';
}

bool _hamza(String cluster) =>
    cluster.isNotEmpty &&
    ('ءأإؤئ'.contains(cluster[0]) || cluster.contains('ٔ'));
String? _vowel(String cluster) => RegExp('[َُِ]').firstMatch(cluster)?[0];

bool _sakinEnd(String word) {
  final cs = lettersOf(word);
  if (cs.length > 1 &&
      'اى'.contains(cs.last[0]) &&
      RegExp('[ًٗ]').hasMatch(cs[cs.length - 2])) {
    return true;
  }
  if (cs.length > 1 &&
      cs.last.startsWith('ا') &&
      !RegExp('[َُِ]').hasMatch(cs.last)) {
    cs.removeLast(); // silent alif after the plural waw / tanween alif
  }
  final last = cs.last;
  if (RegExp('[ًٌٍٖٗٞ]').hasMatch(last)) return true;
  if (RegExp('[َُِ]').hasMatch(last)) return false;
  // A long vowel is not a recipient of naql; a waw/ya of lin is.
  if ('اىوي'.contains(last[0])) {
    if (cs.length < 2) return false;
    return (last[0] == 'و' || last[0] == 'ي') &&
        cs[cs.length - 2].contains('َ');
  }
  return true;
}

String _ending(String word) {
  final cs = lettersOf(word);
  if (cs.length > 1 &&
      cs.last.startsWith('ا') &&
      RegExp('[ْ۟]').hasMatch(cs.last)) {
    cs.removeLast();
  }
  return cs.last;
}
