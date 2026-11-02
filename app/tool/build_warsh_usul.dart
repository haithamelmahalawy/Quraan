// Refines Warsh's boundary hamza rules and stopping taqlil from the Hafs
// context and the transcribed book. Run after the other data tools:
//   dart run tool/build_warsh_usul.dart
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

import 'correct_warsh_lin_hamz.dart';
import 'correct_warsh_lexical_badal.dart';
import 'correct_ya_zawaid.dart';
import 'correct_iqlab_spelling.dart';
import 'correct_warsh_tarqiq.dart';

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
  final source = jsonDecode(
    File('assets/data/reading_texts/warsh.json').readAsStringSync(),
  ) as Map;
  final counts = correctWarshUsul(
    quran,
    book,
    data['variants'] as List,
    sourceText: source,
  );
  file.writeAsStringSync(jsonEncode(data));
  stdout.writeln('Warsh usul: $counts');
}

/// Keeps the source's word readings; tags the rules and supplies both words
/// for the footer. Explicit hamza replacement is represented on the Hafs
/// word by a circled letter, rather than changing its orthography.
Map<String, int> correctWarshUsul(
  Map quran,
  Map book,
  List variants, {
  Map? sourceText,
}) {
  final words = <_Word>[
    for (final a in quran['ayahs'] as List)
      for (final (w, text) in (a[4] as String).split(' ').indexed)
        (surah: a[0] as int, ayah: a[1] as int, word: w, text: text),
  ];
  String key(_Word w) => '${w.surah}:${w.ayah}:${w.word}';
  correctIqlabSpelling(quran, variants);
  final actual = <String, String>{
    if (sourceText != null)
      for (final a in sourceText['ayahs'] as List)
        for (final (w, text) in (a[2] as List).indexed)
          '${a[0]}:${a[1]}:$w': text as String,
  };
  // The generic source comparison mistakes a hamza glyph for omission.
  // Warsh agrees with Hafs here; al-Susi's separate file keeps its reading.
  variants.removeWhere((v) => v[0] == 2 && v[1] == 72 && v[2] == 3);
  // The source's generic hamza comparison must not turn the lexical
  // الصابين / الصابون reading into madd al-badal.
  const sabiPlaces = {'2:62:6', '5:69:5', '22:17:5'};
  bool isSabi(List v) => sabiPlaces.contains('${v[0]}:${v[1]}:${v[2]}');
  variants.removeWhere(
    (v) => isSabi(v as List) && v.length > 7 && v[7] == 'badal',
  );
  for (final v in variants.cast<List>().where(isSabi)) {
    if (v.length <= 7 || v[7] == '') {
      v[5] = 'f';
      v[6] = 'بلا همز';
    }
  }
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
            ?.where(
              (v) =>
                  (v.length < 8 || v[7] == '' || _rules.contains(v[7])) &&
                  !(v.length > 7 && v[7] == 'naql_source' && v[4] == ''),
            )
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
    var how = v != null && v.length > 6 ? v[6] as String : '';
    if (v != null &&
        previous != null &&
        how.contains('الإدغام') &&
        RegExp(r'^[يرملون][َُِ]*ّ').hasMatch(v[4] as String) &&
        lettersOf(v[4] as String).first[0] == lettersOf(w.text).first[0] &&
        (RegExp(r'ن[ْۡ]?[ۖ-ۭ]*$').hasMatch(previous.text) ||
            RegExp(r'[ًٌٍٖٗٞ][اى]?[ۖ-ۭ]*$').hasMatch(previous.text)) &&
        (v[5] == 'f' ||
            RegExp('إبدال الهمزة|تخفيف الهمزة|نقل').hasMatch(how))) {
      // Nun/tanween idgham shared with Hafs is notation, not a Warsh
      // difference. Keep the independent hamza/silah/lexical description.
      how = how
          .replaceAll(RegExp(r'[بو]?الإدغام'), '')
          .replaceAll(RegExp(r'^[و\s،]+|[\s،]+$'), '');
      if (!how.startsWith('ب')) how = 'ب$how';
      v[6] = how;
    }
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
      // The question's hamza added: a farsh of its own, with the word; the
      // eased hamza (ءَا۬) and the alif after it apart (ـٰ) as the Madinah
      // mushaf writes them.
      final farsh = at[key(w)]?.where((x) => x[5] == 'f').firstOrNull ?? add(w);
      farsh
        ..[4] = w.text.replaceFirst('ءَا', 'ءَا\u06EC\u0640\u0670')
        ..[5] = 'f'
        ..[6] = 'بزيادة همزة الاستفهام';
      final rule =
          at[key(w)]
              ?.where((x) => x.length > 7 && x[7] == 'tasheel_word')
              .firstOrNull ??
          add(w);
      rule
        ..[4] = ''
        ..[5] = 'h';
      const ways = [
        'تحقيق الأولى وتسهيل الثانية بلا إدخال مع ثلاثة البدل؛ ولا إبدال للثانية',
      ];
      tag(rule, 'tasheel_word', ways.single, context: w.text, ways: ways);
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
    // ءَآللَّهُ، ءَآلذَّكَرَيۡنِ: read as Hafs reads them, nothing told.
    if (const {'6:143:9', '6:144:7', '10:59:13', '27:59:8'}.contains(key(w))) {
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
          // The second hamza on its tooth (أَئِمَّةٗ), told with the first.
          cs[1].startsWith('ئ')
              ? 'تحقيق الأولى وتسهيل الثانية بلا إدخال'
              : 'تسهيل الهمزة الثانية بلا إدخال',
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
    final ownText = v != null && v[4] != ''
        ? v[4] as String
        : actual[key(w)] ?? '';
    final own = lettersOf(madinahScript(ownText));
    final lam = naqlLetter(cs);
    final internalNaql =
        lam != null &&
        _hamza(cs[lam + 1]) &&
        own.length > lam &&
        (own[lam].contains('ٰ') ||
            own.length > lam + 1 &&
                !_hamza(own[lam + 1]) &&
                own[lam + 1].startsWith('ا')) &&
        _vowel(own[lam]) != null;
    if (v == null && internalNaql) {
      v = add(w);
      v[4] = ownText;
    }
    if (v == null) continue;
    if (how.contains('نقل حركة الهمزة إلى اللام') || internalNaql) {
      tag(
        v,
        'naql',
        [
          'بنقل حركة الهمزة إلى اللام',
          if (how.contains('التقليل')) 'بالتقليل',
          if (how.contains('الإمالة')) 'بالإمالة',
        ].join('، '),
        context: w.text,
      );
    } else if (previous != null &&
        firstHamza &&
        _sakinEnd(previous.text) &&
        RegExp(r'^ا[َُِٰء-ي]').hasMatch(madinahScript(v[4] as String))) {
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
        // A farsh of its own before its last letter (بِرُبْوَةٍ): it keeps
        // its row, and the naql is told apart.
        if (p[5] == 'f' && _farshBeforeEnd(previous.text, p[4] as String)) {
          tag(
            at[key(previous)]
                    ?.where(
                      (x) =>
                          x.length > 7 && x[7] == 'naql_source' && x[4] == '',
                    )
                    .firstOrNull ??
                add(previous),
            'naql_source',
            'بنقل حركة الهمزة إليها',
            context: pair,
          );
        } else {
          tag(p, 'naql_source', 'بنقل حركة الهمزة إليها');
        }
      }
    } else if (previous != null &&
        _waslSakinHamza(w.text) &&
        _waslVowel(previous.text) != null) {
      // ٱئۡتِنَا، ٱؤۡتُمِنَ: in wasl the hamza follows the vowel ending the
      // word before, and is read by it (يَٰصَٰلِحُ وتِنَا، ٱلَّذِيتُمِنَ،
      // ٱلۡهُدَاتِنَا); begun with, by the alif's own vowel.
      final vowel = _waslVowel(previous.text);
      final begun = w.text.contains('ؤ') ? 'واوًا' : 'ياءً';
      final read = switch (vowel) {
        'ُ' => 'واوًا',
        'ِ' => 'ياءً',
        _ => 'ألفًا',
      };
      tag(
        v,
        switch (vowel) {
          'ُ' => 'ibdal_waw',
          'ِ' => 'ibdal_ya',
          _ => 'ibdal_single',
        },
        read == begun
            ? 'بإبدال الهمزة $read'
            : 'بإبدال الهمزة $read وصلاً، و$begun ابتداءً',
        context: '${previous.text} ${w.text}',
        ways: ['إبدال الهمزة $read وصلاً'],
      );
    } else if (_singleIbdal(w.text, v[4] as String, how)
        case final String refined) {
      tag(
        v,
        'ibdal_single',
        [
          refined,
          if (how.contains('صلة ميم الجمع')) 'بصلة ميم الجمع',
          if (how.contains('الإدغام')) 'بالإدغام',
          if (how.contains('التقليل')) 'بالتقليل',
          if (how.contains('الإمالة')) 'بالإمالة',
        ].join('، '),
        context: w.text,
      );
    } else if (how.contains('إبدال الهمزة') && !how.contains('استفهام')) {
      tag(v, 'ibdal_single', how, context: w.text);
    }
  }

  // The book's easing of the second of two hamzas of a word (أَئِنَّكُمۡ،
  // أَئِمَّةٗ «بالتسهيل من غير إدخال»), where the source writes the hamza.
  final byKey = {for (final w in words) key(w): w};
  for (final p in ((book['riwayat'] as Map)['warsh'] as List).cast<List>()) {
    final how = p[5] as String;
    if ((p[4] as String).isNotEmpty ||
        p[3] != 1 ||
        !how.contains('تسهيل') ||
        !RegExp('(من غير|بلا) إدخال').hasMatch(how)) {
      continue;
    }
    final w = byKey['${p[0]}:${p[1]}:${p[2]}'];
    if (w == null) continue;
    final cs = lettersOf(w.text);
    if (cs.length < 2 || !_hamza(cs[0]) || !_hamza(cs[1])) continue;
    if (at[key(w)]?.any((v) => v.length > 7 && v[7] == 'tasheel_word') ??
        false) {
      continue;
    }
    tag(
      add(w),
      'tasheel_word',
      'بتسهيل الهمزة الثانية بلا إدخال',
      context: w.text,
      ways: ['تسهيل الهمزة الثانية بلا إدخال'],
    );
  }

  // The source represents a facilitated second hamza on waw/ya with a
  // round sign. Naql on the first hamza must not hide this separate rule.
  for (final w in words) {
    final own = actual[key(w)];
    final cs = lettersOf(w.text);
    if (own == null ||
        !RegExp(r'^[اأ]َ[وي][ْۡ]۟').hasMatch(own) ||
        cs.length < 2 ||
        !_hamza(cs[0]) ||
        !_hamza(cs[1])) {
      continue;
    }
    if (at[key(w)]?.any((v) => v.length > 7 && v[7] == 'tasheel_word') ==
        true) {
      continue;
    }
    tag(
      add(w),
      'tasheel_word',
      'بتسهيل الهمزة الثانية بلا إدخال',
      context: w.text,
      ways: ['تسهيل الهمزة الثانية بلا إدخال'],
    );
  }

  // The tanweened final alif is dropped in wasl. Its taqlil is visible
  // only on stopping, and is not spelled in the continuous KFGQPC text.
  for (final e in book['entries'] as List) {
    if (e[4] != 'mumal') continue;
    final mine = (e[5] as List).where(
      (g) =>
          ((g[1] as List).contains('warsh') ||
              (g[2] as List).contains('warsh')) &&
          (g[5] == true || g[4] == true || (g[3] as String).contains('تقليل')),
    );
    if (mine.isEmpty) continue;
    final w = source['${e[0]}:${e[1]}:${e[2]}'];
    if (w == null || !RegExp(r'[ىا][ۖ-ۭ]*$').hasMatch(w.text)) continue;
    final stopping =
        RegExp(r'ى[ۖ-ۭ]*$').hasMatch(w.text) &&
            mine.any((g) => g[4] == true || (g[3] as String).contains('وقف')) ||
        RegExp(r'[ًٗ].*[ىا][ۖ-ۜ]?$').hasMatch(w.text) &&
            mine.any((g) => g[5] == true || (g[3] as String).contains('تقليل'));
    if (!stopping) continue;
    final v = reading(w) ?? add(w);
    tag(v, 'taqlil_stop', 'بالتقليل وقفًا', stop: true);
  }
  // تَرَٰٓءَا (الشعراء 61), its alif dropped in wasl: the ra and the hamza
  // lessened on stopping, opened in wasl.
  tag(
    at['26:61:1']
            ?.where((v) => v.length > 7 && v[7] == 'taqlil_stop')
            .firstOrNull ??
        add(source['26:61:1']!),
    'taqlil_stop',
    'بتقليل الراء والهمزة وقفًا',
    stop: true,
  );
  correctWarshLexicalBadal(quran, variants, sourceText: sourceText);
  correctYaZawaid(quran, variants, 'warsh', book);
  counts.addAll(correctWarshLinHamz(quran, variants));
  correctWarshTarqiq(quran, variants, sourceText: sourceText);
  // Tanween receives the transferred vowel in wasl although its written
  // word does not change. Link both sides after all reading refinements,
  // including boundaries across ayahs, without replacing the Quran text.
  for (var i = 1; i < words.length; i++) {
    final w = words[i], previous = words[i - 1];
    if (w.surah != previous.surah ||
        !RegExp(r'[ًٌٍٖٗٞ][اى]?[ۖ-ۭ]*$').hasMatch(previous.text)) {
      continue;
    }
    final boundary =
        at[key(w)]?.any(
          (v) =>
              v.length > 7 &&
              v[7] == 'naql' &&
              (v[6] as String).startsWith('بنقل حركة الهمزة إلى الساكن قبلها'),
        ) ??
        false;
    if (!boundary) continue;
    final carrier =
        at[key(previous)]
            ?.where((v) => v.length > 7 && v[7] == 'naql_source')
            .firstOrNull ??
        add(previous);
    tag(
      carrier,
      'naql_source',
      'بنقل حركة الهمزة إليها',
      context: '${previous.text} ${w.text}',
    );
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
  if (!how.contains('تخفيف الهمزة') &&
      !RegExp(r'^بإبدال الهمزة (الساكنة|المفتوحة) (ألفًا|ياءً|واوًا)$')
          .hasMatch(how)) {
    return null;
  }
  if (reading.isEmpty || reading.contains(' ')) return null;
  final h = lettersOf(hafs), r = lettersOf(madinahScript(reading));
  if (h.length != r.length) return null;
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

/// A word begun with a wasl alif before a hamza with sukun (ٱئۡتِنَا).
bool _waslSakinHamza(String word) => RegExp('^ٱ[ؤئأ]ۡ').hasMatch(word);

/// The vowel ending [word] in wasl, before a sakin: its last letter's, or
/// the one before a madd letter that drops (قَالُواْ، ٱلۡهُدَى، لِقَآءَنَا).
String? _waslVowel(String word) {
  final letters = lettersOf(word.replaceAll(RegExp('[ۖ-ۭ]'), ''));
  for (final l in letters.reversed) {
    final v = RegExp('[َُِ]').firstMatch(l)?[0];
    if (v != null) return v;
    if (!RegExp('^[اىوي]').hasMatch(l)) return null;
  }
  return null;
}

/// [own] differs from Hafs's [hafs] before its last letter: a farsh, not
/// only the vowel naql gives the last letter (مِّنَ for مِّنۡ).
bool _farshBeforeEnd(String hafs, String own) {
  final h = lettersOf(hafs), o = lettersOf(madinahScript(own));
  if (h.length != o.length) return true;
  for (var i = 0; i < h.length - 1; i++) {
    if (h[i] != o[i]) return true;
  }
  return false;
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
