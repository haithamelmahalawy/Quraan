import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran.dart';

/// Qiraat of the twenty riwayat from Quranpedia (الموسوعة القرآنية),
/// fetched per ayah while reading and cached on the device.
///
/// Used for the riwayat that have no offline KFGQPC text. Quranpedia allows
/// in-app use of its API; it asks not to bulk-download and republish the
/// data, so nothing is mirrored into the app's assets.
/// https://api.quranpedia.net — `GET /v1/ayah/{surah}/{ayah}/qiraat`
class OnlineQiraat {
  OnlineQiraat({http.Client? client, this.prefs})
      : _client = client ?? http.Client();

  static const source = 'الموسوعة القرآنية (quranpedia.net)';

  /// Quranpedia rawi id -> riwaya id of the catalogue.
  static const riwayaOf = {
    1: 'qalun', 2: 'warsh', 3: 'bazzi', 4: 'qunbul', 5: 'duri_abuamr', //
    6: 'susi', 7: 'hisham', 8: 'ibn_dhakwan', 9: 'shubah', 10: 'hafs',
    11: 'khalaf_hamzah', 12: 'khallad', 13: 'abul_harith', 14: 'duri_kisai',
    15: 'ibn_wardan', 16: 'ibn_jammaz', 17: 'ruways', 18: 'rawh',
    19: 'ishaq', 20: 'idris',
  };

  final http.Client _client;

  /// On-device cache of converted ayahs.
  final SharedPreferences? prefs;

  /// The variants of every riwaya that differs from Hafs in [ayah].
  Future<List<Variant>> fetch(Ayah ayah) async {
    final cacheKey = 'qp1:${ayah.surah}:${ayah.number}';
    final cached = prefs?.getString(cacheKey);
    if (cached != null) return decodeCache(ayah, cached);

    final uri = Uri.parse(
        'https://api.quranpedia.net/v1/ayah/${ayah.surah}/${ayah.number}/qiraat');
    final response = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final variants = convert(ayah, jsonDecode(utf8.decode(response.bodyBytes)));
    await prefs?.setString(cacheKey, encodeCache(variants));
    return variants;
  }

  /// Converts a Quranpedia qiraat response into variants against the Hafs
  /// words of [ayah].
  static List<Variant> convert(Ayah ayah, Object? json) {
    final out = <Variant>[];
    final hafs = [for (final w in ayah.words) skeleton(w)];
    var from = 0;
    for (final entry in (json as List? ?? const [])) {
      final phrase = skeleton(entry['ayah_word'] as String? ?? '');
      final match = _find(hafs, phrase, from) ?? _find(hafs, phrase, 0);
      if (match == null) continue; // a word this text spells too differently
      final (at, count) = match;
      from = at + count;

      for (final reading in entry['qiraat'] as List) {
        final rewayat = [
          for (final r in reading['rewayat'] as List)
            riwayaOf[(r['rawi'] as Map)['id']],
        ];
        if (rewayat.contains('hafs')) continue; // the base text itself
        final (text, description) =
            split((reading['qiraa_text'] as String).trim());
        final kind =
            kindOf(text, description, hafs.sublist(at, at + count).join());
        for (final id in rewayat.whereType<String>()) {
          out.add(Variant(
            riwayaId: id,
            surah: ayah.surah,
            ayah: ayah.number,
            word: at,
            count: count,
            text: text,
            description: description,
            kind: kind,
          ));
        }
      }
    }
    return out;
  }

  /// First run of Hafs words from [from] whose letters spell [phrase]
  /// (word breaks may differ: يَٰعِبَادِ / يَا عِبَادِ); (index, word count).
  static (int, int)? _find(List<String> hafs, String phrase, int from) {
    if (phrase.isEmpty) return null;
    for (var i = from; i < hafs.length; i++) {
      var joined = '';
      for (var k = i; k < hafs.length && joined.length < phrase.length; k++) {
        joined += hafs[k];
        if (joined == phrase) return (i, k - i + 1);
      }
    }
    return null;
  }

  /// "(تَدْعُونَ) بالتاء" → reading "تَدْعُونَ", description "بالتاء";
  /// "يُكَذِّبون" → the reading alone; "بالإمالة" → the description alone.
  static (String, String) split(String raw) {
    final m = RegExp(r'^\(+([^()]+)\)+\s*(.*)$').firstMatch(raw);
    if (m != null) return (m[1]!.trim(), m[2]!.trim());
    return isDescription(raw) ? ('', raw) : (raw, '');
  }

  /// "بالإمالة", "بإسكان الهاء", "تشديد الذال" describe a reading;
  /// "يُكَذِّبون" is the reading itself.
  static bool isDescription(String text) =>
      RegExp(r'[0-9٠-٩]').hasMatch(text) ||
      RegExp(r'^(ب(ال|إ|ا|ضم|فتح|كسر|رفع|جزم|ين|غير|حذف|ترك|تنوين|تسهيل|تحقيق|تشديد|تخفيف|صلة|قصر|مد|نقل|سكت|روم|إشمام|همز)'
              r'|تشديد|تخفيف|إمالة|ادغام|إدغام|مع |دون |وقف|بين )')
          .hasMatch(text);

  /// Layer of a reading: letters that differ from Hafs make it farsh;
  /// otherwise hamza or recitation rules by its description.
  static VariantKind kindOf(String text, String description, String hafs) {
    if (text.isNotEmpty && skeleton(text) != hafs) return VariantKind.farsh;
    final d = description.isEmpty ? text : description;
    if (RegExp(r'تسهيل|إبدال|بالإبدال|نقل|همزتين|بالهمز|دون همز|بتحقيق|مسهلة')
        .hasMatch(d)) {
      return VariantKind.hamza;
    }
    if (RegExp(r'إمالة|تقليل|الفتح|مد|قصر|صلة|إدغام|ادغام|إظهار|سكت|غنة|ترقيق|تفخيم|تغليظ|إشمام|روم')
        .hasMatch(d)) {
      return VariantKind.usul;
    }
    return VariantKind.farsh;
  }

  /// Letters only, with alef / hamza seats / ya forms unified, to match a
  /// Quranpedia word against the KFGQPC Hafs word.
  static String skeleton(String word) {
    final b = StringBuffer();
    for (final c in word.runes) {
      final ch = String.fromCharCode(c);
      if (ch == 'ى' || c == 0x06E6) {
        b.write('ي');
      } else if (ch == 'ؤ' || c == 0x06E5) {
        b.write('و');
      } else if (ch == 'ة') {
        b.write('ه');
      } else if (c >= 0x0621 && c <= 0x064A &&
          !'ءئأإآا'.contains(ch)) {
        // Alef (full or dagger) and hamza seats are spelled differently in
        // the two texts, so they are left out of the comparison.
        b.write(ch);
      }
    }
    return b.toString();
  }

  static String encodeCache(List<Variant> vs) => jsonEncode([
        for (final v in vs)
          [v.riwayaId, v.word, v.count, v.text, v.kind.code, v.description],
      ]);

  static List<Variant> decodeCache(Ayah ayah, String raw) => [
        for (final v in jsonDecode(raw) as List)
          Variant(
            riwayaId: v[0] as String,
            surah: ayah.surah,
            ayah: ayah.number,
            word: v[1] as int,
            count: v[2] as int,
            text: v[3] as String,
            kind: VariantKind.fromCode(v[4] as String),
            description: v[5] as String,
          ),
      ];
}
