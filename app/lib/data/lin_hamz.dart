import 'arabic.dart';

/// A sakin waw/ya after a fatha, immediately before a hamza in the same
/// word. Includes Uthmani hamzas carried by a tatweel and Maghribi ya forms.
/// An alif written and not read between them (تَاْيۡـَٔسُواْ) is passed over.
List<int> linHamzLetters(String word) {
  final letters = lettersOf(word);
  bool fathaBefore(int i) =>
      letters[i - 1].contains('َ') ||
      i > 1 && letters[i - 1] == 'اْ' && letters[i - 2].contains('َ');
  return [
    for (var i = 1; i + 1 < letters.length; i++)
      if ('ويىے'.contains(letters[i][0]) &&
          !RegExp('[ًٌٍَُِّ]').hasMatch(letters[i]) &&
          fathaBefore(i) &&
          ('ءأإؤئ'.contains(letters[i + 1][0]) || letters[i + 1].contains('ٔ')))
        i,
  ];
}

enum LinHamz {
  regular(
    'lin_hamz',
    'مد اللين المهموز',
    'مد اللين المهموز لورش عن نافع من طريق الأزرق: التوسط ٤ حركات أو الإشباع ٦ حركات وصلًا ووقفًا، ولا قصر فيه',
    ['التوسط ٤ حركات وصلًا ووقفًا', 'الإشباع ٦ حركات وصلًا ووقفًا'],
  ),
  exception(
    'lin_hamz_exception',
    'مد اللين المهموز (مستثنى)',
    'من مستثنيات مد اللين المهموز: القصر حركتان فقط وصلًا ووقفًا، دون توسط أو إشباع',
    ['القصر حركتان فقط وصلًا ووقفًا'],
  ),
  sawat(
    'lin_hamz_sawat',
    'مد اللين المهموز (مع مد البدل)',
    'في واو سوءات خلاف لورش من طريق الأزرق: قصر اللين مع أوجه البدل الثلاثة، أو توسط اللين مع توسط البدل',
    [
      'قصر اللين مع قصر البدل أو توسطه أو إشباعه',
      'توسط اللين ٤ حركات مع توسط البدل ٤ حركات',
    ],
  );

  const LinHamz(this.rule, this.label, this.description, this.ways);
  final String rule, label, description;
  final List<String> ways;

  static LinHamz? of(String word) {
    if (linHamzLetters(word).isEmpty) return null;
    final plain = word
        .replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '')
        .replaceAll('ٱ', 'ا');
    if (plain == 'موئلا' || plain == 'الموءودة' || plain == 'الموءدة') {
      return exception;
    }
    if (plain.contains('سوءات') || plain.contains('سوءت')) return sawat;
    return regular;
  }
}
