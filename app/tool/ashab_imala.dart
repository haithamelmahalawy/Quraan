part of 'build_ashab_usul.dart';

/// «الإمالة والتقليل» of [id], from the section «الممال» of «التسهيل
/// لقراءات التنزيل»: Ibn Dhakwan's row where he reads the word alike, worded
/// as his («بإمالة الألف»); a stop's own imala as Warsh's taqlil
/// («بالإمالة وقفًا»), and al-Kisa'i's feminine ha with the letter before it.
int _imala(
  String id,
  Map book,
  Map<String, _Word> index,
  Map<String, List<List>> ibnDhakwan,
  void Function(List row) put,
) {
  var n = 0;
  final done = <String>{};
  for (final e in book['entries'] as List) {
    if (e[4] != 'mumal') continue;
    final (s, a) = (e[0] as int, e[1] as int);
    // The word of the span the alif is in: «وَلَن تَرۡضَىٰ», «لَا يَخۡفَىٰ»,
    // «مُوسَى ٱلۡكِتَٰبَ», «رَءَا ٱلشَّمۡسَ»: an alif maqsura first, then an
    // alif, never «لا» itself.
    final span = [
      for (var i = e[2] as int; i < (e[2] as int) + (e[3] as int); i++)
        index[_key(s, a, i)],
    ].whereType<_Word>().toList();
    if (span.isEmpty) continue;
    String bare(_Word x) => _bare(x.t);
    final word =
        span.where((x) => RegExp(r'ى$').hasMatch(bare(x))).firstOrNull ??
        span
            .where(
              (x) =>
                  RegExp(r'ا$').hasMatch(bare(x)) &&
                  !RegExp(r'^[وف]?لا$').hasMatch(bare(x)),
            )
            .firstOrNull ??
        // An alif inside the word: «إِذۡ جَآءَهُمۡ».
        span
            .where((x) => RegExp('[اٰ]').hasMatch(x.t.substring(1)))
            .firstOrNull ??
        span.first;
    final w = word.w;
    // A word with no alif to lean, the book's number amiss (لَّهُمۡ، سِتَّةِ):
    // none, but the openings' letters and al-Kisa'i's feminine ha.
    final fawatih = RegExp('[ٓ]').hasMatch(word.t) && word.w == 0;
    final ha = _kisai.contains(id) && RegExp(r'ة[ً-ٟۖ-ۛ]*$').hasMatch(word.t);
    if (!fawatih && !ha && !RegExp('[اىٰ]').hasMatch(word.t.substring(1))) {
      continue;
    }
    for (final g in e[5] as List) {
      final all = (g[1] as List).cast<String>();
      final disputed = (g[2] as List).cast<String>();
      if (!all.contains(id) && !disputed.contains(id)) continue;
      // al-Kisa'i's feminine ha (غِشَٰوَةٞ): when stopping, whatever the book.
      final kisaiHa =
          _kisai.contains(id) && RegExp(r'ة[ً-ٟۖ-ۛ]*$').hasMatch(word.t);
      // Told below by the letter before it, the book aside.
      if (kisaiHa) continue;
      // The taqlil as the book words the reading (التوراة: «وقللها» for
      // Hamza), not its flag, set where any reader of the group reduces it
      // (Warsh with al-Duri's imala, أَبۡصَٰرِهِمۡ).
      final stop = g[4] == true || kisaiHa,
          taqlil = RegExp('قلل|(?<!لا )تقليل').hasMatch('${g[3]}');
      if (!done.add('${_key(s, a, w)}:$stop')) continue;
      final khulf = disputed.contains(id);
      // Ibn Dhakwan's row where he reads it alike, by the same name.
      final his = (ibnDhakwan[_key(s, a, w)] ?? const <List>[])
          .where(
            (v) =>
                v[3] == 1 &&
                RegExp('مال').hasMatch('${v.length > 6 ? v[6] : ''}') &&
                (v.length > 8 &&
                        v[8] is Map &&
                        (v[8] as Map)['stopOnly'] == true) ==
                    stop &&
                // His own khulf is not theirs; nor a note.
                !RegExp('بخلف|وجه|يخفى').hasMatch('${v[6]}'),
          )
          .firstOrNull;
      if (his != null &&
          (all.contains('ibn_dhakwan') || disputed.contains('ibn_dhakwan')) &&
          !khulf &&
          !taqlil) {
        put([
          s,
          a,
          w,
          1,
          his[4],
          'u',
          his[6],
          his.length > 7 ? his[7] : '',
          {
            if (his.length > 8 && his[8] is Map)
              ...Map<String, Object?>.from(his[8] as Map)..remove('source'),
            'source': ashabSource,
            'farshFrom': 'ibn_dhakwan',
          },
        ]);
        n++;
        continue;
      }
      // The alif before a final ra leans only with the ra's kasra (ٱلنَّارِ،
      // بِقِنطَارٖ), not its fatha or damma (ٱلنَّارُ، ٱلۡأَبۡرَارَ) (the user,
      // 2026-11-12).
      if (RegExp('ار[ًٌَُٗٞ][ۖ-ۛ]*\$').hasMatch(word.t.replaceAll('ّ', ''))) {
        continue;
      }
      final ha =
          kisaiHa || stop && RegExp(r'[ة][ًٌٍَُِۖ-ۛ]*$').hasMatch(word.t);
      var how = taqlil
          ? 'بالتقليل'
          : ha
          ? 'بإمالة هاء التأنيث وما قبلها'
          : 'بإمالة الألف';
      if (stop) how = '$how وقفًا';
      if (khulf) how = '$how بخلف عنه';
      put([
        s,
        a,
        w,
        1,
        '',
        'u',
        how,
        // «إمالة هاء التأنيث», a chapter of its own (the user, 2026-11-12).
        ha && !taqlil ? 'imala_ha' : '',
        {
          'source': ashabSource,
          'book': 'kharouf',
          if (stop) 'stopOnly': true,
          if (khulf) 'ways': [taqlil ? 'التقليل' : 'الإمالة', 'الفتح'],
          if (khulf) 'ownWays': true,
        },
      ]);
      n++;
    }
  }
  // هاء التأنيث وقفًا للكسائي، بالمذهبين معًا (المستخدم، 2026-11-12):
  // الإجمالي يميلها بعد كل حرف إلا الألف، والتفصيلي بعد «فجثت زينب لذود
  // شمس»، وبعد «أكهر» إن كان قبله كسر أو ياء ساكنة أو ساكن قبله كسر، ولا
  // يميلها بعد «حق ضغط عص خظ»، والألف لا تمال. فما اتفقا عليه قولًا واحدًا، وما أماله
  // الإجمالي وحده بخلف عنه، ولا إمالة بعد الألف.
  if (_kisai.contains(id)) {
    for (final word in index.values) {
      if (done.contains('${_key(word.s, word.a, word.w)}:true')) continue;
      final how = _kisaiHa(word.t);
      if (how == null) continue;
      done.add('${_key(word.s, word.a, word.w)}:true');
      final khulf = how == _KisaiHa.khulf;
      put([
        word.s,
        word.a,
        word.w,
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
      n++;
    }
  }
  return n;
}

enum _KisaiHa { one, khulf }

/// How al-Kisa'i reads the feminine ha of [word] in the stop, by the letter
/// before it; null when there is none or it is an alif (ٱلصَّلَوٰةِ، حَيَوٰةٞ).
_KisaiHa? _kisaiHa(String word) {
  final cs = _letters(word);
  final k = cs.lastIndexWhere((c) => c.base == 'ة');
  if (k < 1) return null;
  final p = cs[k - 1];
  if (p.base == 'ا' || p.base == 'ى' || p.marks.contains('ٰ')) return null;
  if ('فجثتزينبلذودشمس'.contains(p.base)) return _KisaiHa.one;
  if ('حقضغطعصخظ'.contains(p.base)) return _KisaiHa.khulf;
  // أكهر: its hamza on any seat, a kaf, a ha or a ra.
  bool kasr(int i) => i >= 0 && _vowelOf(cs[i]) == 'i';
  bool quiet(int i) =>
      i >= 0 &&
      (RegExp('[ْۡ]').hasMatch(cs[i].marks) ||
          _vowelOf(cs[i]) == '' && 'يى'.contains(cs[i].base));
  final b = k - 2;
  final ya = b >= 0 && cs[b].base == 'ي' && quiet(b);
  return kasr(b) || ya || quiet(b) && kasr(b - 1)
      ? _KisaiHa.one
      : _KisaiHa.khulf;
}
