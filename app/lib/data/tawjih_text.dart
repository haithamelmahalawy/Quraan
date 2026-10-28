/// The reasons of the readings (توجيه القراءات) of chosen riwayat, out of a
/// book of the seven readers that goes word by word: «قرأ نافع وابن عامر
/// ﴿قيما﴾ بغير ألف … وقرأ الباقون ﴿قياما﴾ … وحجتهم …».
library;

/// How the book names the reader of each riwaya, and the narrator himself.
const tawjihNames = <String, List<String>>{
  'qalun': ['نافع', 'قالون'],
  'warsh': ['نافع', 'ورش'],
  'bazzi': ['ابن كثير', 'البزي'],
  'qunbul': ['ابن كثير', 'قنبل'],
  'duri_abuamr': ['أبو عمرو', 'أبي عمرو', 'الدوري'],
  'susi': ['أبو عمرو', 'أبي عمرو', 'السوسي'],
  'hisham': ['ابن عامر', 'هشام'],
  'ibn_dhakwan': ['ابن عامر', 'ابن ذكوان'],
  'shubah': ['عاصم', 'أبو بكر', 'أبي بكر', 'شعبة'],
  'hafs': ['عاصم', 'حفص'],
  'khalaf_hamzah': ['حمزة', 'خلف'],
  'khallad': ['حمزة', 'خلاد'],
  'abul_harith': ['الكسائي', 'أبو الحارث'],
  'duri_kisai': ['الكسائي', 'الدوري'],
};

/// The paragraphs of [text] (a passage per heading, ﴿…﴾, its paragraphs
/// one per line) that give the reading of [riwayat] and its reason: those
/// naming its reader, else, when none does, those of «الباقون». The
/// heading of each passage is kept. Riwayat of readers the book does not
/// treat (Abu Ja'far, Ya'qub, Khalaf) have none.
String tawjihOf(String text, Iterable<String> riwayat) {
  final readers = [for (final r in riwayat) ?tawjihNames[r]];
  final passages = <String>[];
  for (final passage in text.split('\n\n')) {
    final lines = passage.split('\n');
    final head = <String>[];
    final blocks = <List<String>>[];
    for (final line in lines) {
      if (_reading.hasMatch(line)) {
        blocks.add([line]);
      } else if (blocks.isEmpty) {
        head.add(line);
      } else {
        blocks.last.add(line);
      }
    }
    final kept = <int>{};
    for (final names in readers) {
      final own = [
        for (final (i, b) in blocks.indexed)
          if (names.any((n) => _names(b.first, n))) i,
      ];
      kept.addAll(
        own.isNotEmpty
            ? own
            : [
                for (final (i, b) in blocks.indexed)
                  if (b.first.contains('الباقون')) i,
              ],
      );
    }
    if (kept.isEmpty) continue;
    passages.add(
      [
        ...head,
        for (final (i, b) in blocks.indexed)
          if (kept.contains(i)) ...b,
      ].join('\n'),
    );
  }
  return passages.join('\n\n');
}

/// A paragraph telling who reads how: «قرأ …», «وقرأ …».
final _reading = RegExp(r'^(?:و)?قر[أا] ');

/// Whether [line] names [name] as a word (نافع، not نافعا).
bool _names(String line, String name) =>
    RegExp('(^|[\\sو])${RegExp.escape(name)}(\$|[\\s،.,])').hasMatch(line);
