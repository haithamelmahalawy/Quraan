import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/usul_text.dart';
import 'package:qiraat_mushaf/data/arabic.dart';

import '../tool/build_yaqub_usul.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  Map load(String id) =>
      jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync()) as Map;
  List<List> rules(Map d, String rule, int s, int a) => (d['variants'] as List)
      .cast<List>()
      .where((v) => v.length > 7 && v[7] == rule && v[0] == s && v[1] == a)
      .toList();
  test('Yaqub source builder is deterministic for both narrators', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      buildYaqubUsul(quran, d, id);
      final once = jsonEncode(d);
      buildYaqubUsul(quran, d, id);
      expect(jsonEncode(d), once, reason: id);
    }
  });
  test('ishmam belongs to Ruways and carries no Warsh badal', () {
    final rw = load('ruways'), rh = load('rawh');
    final v = rules(rw, 'ishmam', 2, 11).single;
    expect(v[3], 1);
    expect(v[6], isNot(contains('البدل')));
    expect(rules(rh, 'ishmam', 2, 11), isEmpty);
    expect(rules(rw, 'badal', 2, 13), isEmpty);
  });
  test(
    'Rawh malaikatu is nominative farsh while Ruways keeps accusative',
    () async {
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['ruways', 'rawh']);
      final q = await QuranRepository.load();
      final ayah = q.ayah(16, 2);
      expect(readingText(repo, 'rawh', ayah, 1, 2), endsWith('ةُ'));
      expect(readingText(repo, 'ruways', ayah, 1, 2), endsWith('ةَ'));
      final row = repo.at(['rawh'], 16, 2, 1).singleWhere((v) => v.inHamesh);
      expect(row.description, 'برفع التاء');
      expect(row.isUsul, isFalse);
      expect(
        compareReadings(
          repository: repo,
          ayah: ayah,
          word: 1,
          displayed: 'rawh',
          selected: ['hafs'],
        ).where((v) => v.inHamesh),
        hasLength(1),
      );
    },
  );

  test(
    'all separate Khalaf sakt examples include the following hamza word',
    () async {
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['khalaf_hamzah']);
      final q = await QuranRepository.load();
      var count = 0;
      for (final row in load('khalaf_hamzah')['variants'] as List) {
        if (row.length < 8 || row[7] != 'sakt' || row[3] != 1) continue;
        final a = q.ayah(row[0], row[1]);
        final next = a.number < q.surah(a.surah).ayahCount
            ? q.ayah(a.surah, a.number + 1)
            : null;
        final following = row[2] + 1 < a.words.length ? a : next;
        final w = following == a ? row[2] + 1 : 0;
        final v = repo
            .at(['khalaf_hamzah'], row[0], row[1], row[2])
            .firstWhere((v) => v.isSakt && v.word == row[2]);
        final text = usulReadingText(v, a, repo, nextAyah: next);
        if (RegExp(r'ۜ(?:[اى][ً-ٰٟۖ-ۭ]*)?$').hasMatch(v.text) &&
            following != null &&
            RegExp(r'^[ءأإؤئآ]').hasMatch(following.words[w])) {
          count++;
          expect(
            text.split(' '),
            hasLength(2),
            reason: '${a.surah}:${a.number}:${row[2]}',
          );
          expect(skeleton(text.split(' ').last), skeleton(following.words[w]));
        }
      }
      expect(count, greaterThan(100));
      for (final (s, a, w) in [(15, 92, 1), (16, 2, 3), (16, 2, 10)]) {
        final v = repo
            .at(['khalaf_hamzah'], s, a, w)
            .firstWhere((v) => v.isSakt);
        expect(usulReadingText(v, q.ayah(s, a), repo).split(' '), hasLength(2));
      }
    },
  );
  test(
    'Yaqub tasal keeps the Mushaf nabra and agrees with reviewed Warsh',
    () async {
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['ruways', 'rawh', 'warsh']);
      final q = await QuranRepository.load();
      final ayah = q.ayah(2, 119);
      for (final id in ['ruways', 'rawh']) {
        final own = repo.at([id], 2, 119, 6).singleWhere((v) => v.inHamesh);
        expect(own.text, 'تَسۡـَٔلۡ');
        expect(own.text, isNot(contains('أ')));
        expect(readingText(repo, id, ayah, 6, 7), own.text);
        expect(
          compareReadings(
            repository: repo,
            ayah: ayah,
            word: 6,
            displayed: id,
            selected: ['warsh'],
          ).where((v) => v.inHamesh),
          isEmpty,
        );
        expect(
          compareReadings(
            repository: repo,
            ayah: ayah,
            word: 6,
            displayed: id,
            selected: ['hafs'],
          ).where((v) => v.inHamesh),
          hasLength(1),
        );
      }
    },
  );
  test(
    'Yaqub yunzilla at 2:90 is light farsh in both comparison directions',
    () async {
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['ruways', 'rawh']);
      final q = await QuranRepository.load();
      final ayah = q.ayah(2, 90);
      for (final id in ['ruways', 'rawh']) {
        final own = repo.at([id], 2, 90, 11).singleWhere((v) => v.inHamesh);
        expect(own.text, 'يُنزِلَ');
        expect(own.isUsul, isFalse);
        expect(own.description, 'بإسكان النون وكسر الزاي مخففة');
        expect(readingText(repo, id, ayah, 11, 12), 'يُنزِلَ');
        for (final base in [null, id]) {
          final compared = compareReadings(
            repository: repo,
            ayah: ayah,
            word: 11,
            displayed: base,
            selected: [base == null ? id : 'hafs'],
          );
          expect(compared.where((v) => v.inHamesh), hasLength(1));
        }
        expect(
          compareReadings(
            repository: repo,
            ayah: ayah,
            word: 11,
            displayed: id,
            selected: [id == 'ruways' ? 'rawh' : 'ruways'],
          ),
          isEmpty,
        );
      }
    },
  );
  test(
    'Yaqub singular khatiatuhu agrees with Hafs and differs from Warsh',
    () async {
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['ruways', 'rawh', 'warsh']);
      final q = await QuranRepository.load();
      final ayah = q.ayah(2, 81);
      for (final id in ['ruways', 'rawh']) {
        expect(readingText(repo, id, ayah, 6, 7), ayah.words[6]);
        expect(repo.at([id], 2, 81, 6).where((v) => v.inHamesh), isEmpty);
        for (final base in [null, id]) {
          expect(
            compareReadings(
              repository: repo,
              ayah: ayah,
              word: 6,
              displayed: base,
              selected: [base == null ? id : 'hafs'],
            ),
            isEmpty,
          );
        }
        expect(
          compareReadings(
            repository: repo,
            ayah: ayah,
            word: 6,
            displayed: id,
            selected: ['warsh'],
          ).any((v) => v.inHamesh),
          isTrue,
        );
      }
    },
  );
  test(
    'Yaqub return verbs retain active vowels and narrator pronouns',
    () async {
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['ruways', 'rawh']);
      final q = await QuranRepository.load();
      for (final id in ['ruways', 'rawh']) {
        var count = 0;
        for (final a in quran['ayahs'] as List) {
          for (final (w, t) in (a[4] as String).split(' ').indexed) {
            if (!RegExp(r'^[وف]?[تي]ُ').hasMatch(t) ||
                !skeleton(t).contains('رجع')) {
              continue;
            }
            count++;
            final ayah = q.ayah(a[0], a[1]);
            final own = repo.at([id], a[0], a[1], w).where((v) => v.inHamesh);
            expect(own, hasLength(1), reason: '$id ${a[0]}:${a[1]}');
            final text = readingText(repo, id, ayah, w, w + 1);
            expect(text, matches(RegExp(r'^[تي]َ')));
            expect(text, contains('جِ'));
          }
        }
        expect(count, 32);
        expect(
          readingText(repo, id, q.ayah(30, 11), 7, 8),
          startsWith(id == 'ruways' ? 'تَ' : 'يَ'),
        );
        expect(
          readingText(repo, id, q.ayah(43, 85), 12, 13),
          startsWith(id == 'ruways' ? 'يَ' : 'تَ'),
        );
      }
    },
  );
  test('source imala is restricted to its narrator and first aama', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      expect(rules(d, 'imala', 17, 72), hasLength(1));
      expect(rules(d, 'imala', 27, 43), hasLength(1));
      expect(rules(d, 'imala', 11, 41), isEmpty);
      expect(rules(d, 'imala', 2, 19), id == 'ruways' ? hasLength(1) : isEmpty);
    }
    expect(rules(load('rawh'), 'imala', 36, 1), hasLength(1));
    expect(rules(load('ruways'), 'imala', 36, 1), isEmpty);
  });
  test('Ruways kafirin imala covers every prefix and marks the kaf', () {
    final rw = load('ruways'), rh = load('rawh');
    var count = 0;
    for (final a in quran['ayahs'] as List) {
      for (final (w, text) in (a[4] as String).split(' ').indexed) {
        if (!skeleton(text).endsWith('كفرين')) continue;
        count++;
        final own = rules(rw, 'imala', a[0], a[1]).where((v) => v[2] == w);
        expect(own, hasLength(1), reason: '${a[0]}:${a[1]} $text');
        expect(
          rules(rh, 'imala', a[0], a[1]).where((v) => v[2] == w),
          a[0] == 27 && a[1] == 43 ? hasLength(1) : isEmpty,
        );
        final marked = lettersOf(withImalaSign(text));
        expect(
          marked.singleWhere((c) => c.contains(imalaSign)),
          startsWith('ك'),
        );
      }
    }
    expect(count, 93);
  });
  test('hamza boundary rules preserve first hamza and their context', () {
    final d = load('ruways');
    final v = rules(d, 'ibdal_waw', 2, 13).single;
    expect(v[3], 1);
    expect((v[8] as Map)['context'], contains('ٱلسُّفَهَآءُ'));
    expect(v[4], startsWith('وَ'));
    expect(rules(load('rawh'), 'ibdal_waw', 2, 13), isEmpty);
    final source = rules(d, 'naql_source', 55, 54).single;
    expect(source[4], endsWith('نِ'));
    expect(rules(load('rawh'), 'naql_source', 55, 54), isEmpty);
    expect(rules(d, 'naql', 53, 50).single[4], contains('لُّ'));
  });
  test('routine Yaqub madd has no row, colour, or margin exception', () {
    for (final id in ['ruways', 'rawh']) {
      final rows = (load(id)['variants'] as List).cast<List>();
      expect(
        rows.where(
          (v) =>
              v.length > 7 &&
              const {'madd_munfasil', 'madd_muttasil'}.contains(v[7]),
        ),
        isEmpty,
        reason: id,
      );
      expect(
        rows.where((v) => v[0] == 2 && v[1] == 152 && v[2] == 0),
        isEmpty,
        reason: '$id فاذكروني',
      );
    }
  });
  test('reviewed early Baqara phrases are written and fully vocalised', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      final tara = (d['variants'] as List).cast<List>().singleWhere(
        (v) => v[0] == 2 && v[1] == 165 && v[2] == 17,
      );
      expect(tara.sublist(2, 5), [17, 1, 'تَرَى']);
      final birr = (d['variants'] as List).cast<List>().singleWhere(
        (v) => v[0] == 2 && v[1] == 177 && v[2] == 1,
      );
      // «لَّيۡسَ» is read as Hafs: only «ٱلۡبِرُّ», with its damma.
      expect(birr.sublist(2, 4), [1, 1]);
      expect(birr[4], contains('ُ'));
    }
  });
  test('all Yaqub replacement quotations carry the source vowel marks', () {
    final ayahs = {
      for (final a in quran['ayahs'] as List) '${a[0]}:${a[1]}': a,
    };
    for (final id in ['ruways', 'rawh']) {
      for (final v in (load(id)['variants'] as List).cast<List>()) {
        if (!const {'f', 'h'}.contains(v[5]) || (v[4] as String).isEmpty) {
          continue;
        }
        final own = (v[4] as String).split(RegExp(r'\s+'));
        if (own.length != v[3]) continue;
        final source = (ayahs['${v[0]}:${v[1]}']![4] as String)
            .split(' ')
            .sublist(v[2] as int, (v[2] as int) + (v[3] as int))
            .join(' ');
        expect(
          completeReadingVowels(v[4] as String, source),
          v[4],
          reason: '$id ${v[0]}:${v[1]}:${v[2]}',
        );
      }
    }
  });
  test('tanweened first hamza never creates a two-word hamza rule', () {
    final rows = (load('ruways')['variants'] as List).cast<List>();
    expect(
      rows.where(
        (v) =>
            v[0] == 2 &&
            v[1] == 178 &&
            v[2] == 23 &&
            v.length > 7 &&
            v[7] == 'tasheel_pair',
      ),
      isEmpty,
    );
    for (final v in rows.where(
      (v) =>
          v.length > 7 &&
          const {'tasheel_pair', 'ibdal_waw', 'ibdal_ya'}.contains(v[7]),
    )) {
      final context = (v[8] as Map)['context'] as String;
      final previous = context.split(RegExp(r'\s+')).first;
      expect(
        lettersOf(previous).last,
        isNot(matches(RegExp('[ًࣰٌࣱٍࣲٖٗٞ]'))),
        reason: '${v[0]}:${v[1]}:${v[2]} $previous',
      );
    }
  });
  test('performance prose is never stored as replacement Quran text', () {
    for (final id in ['ruways', 'rawh']) {
      for (final v in (load(id)['variants'] as List).cast<List>()) {
        expect(
          v[4] as String,
          isNot(
            matches(
              RegExp(r'^(?:إشمام|اشمام|إظهار|اظهار|إدغام|ادغام)(?:\s|$)'),
            ),
          ),
          reason: '$id ${v[0]}:${v[1]}:${v[2]}',
        );
      }
    }
  });
  test('extra ya is drawn as a small silah ya throughout Yaqub', () {
    for (final id in ['ruways', 'rawh']) {
      final rows = (load(id)['variants'] as List).cast<List>().where(
        (v) => v.length > 8 && v[7] == 'ya_zaida',
      );
      for (final v in rows) {
        final metadata = v[8] as Map;
        final written = metadata['stopOnly'] == true
            ? metadata['stopText'] as String
            : v[4] as String;
        if (written.isEmpty) continue;
        expect(written, endsWith('ۦ'), reason: '$id ${v[0]}:${v[1]}:${v[2]}');
        expect(
          written,
          isNot(matches(RegExp(r'[يى]$'))),
          reason: '$id ${v[0]}:${v[1]}:${v[2]}',
        );
      }
      expect(rules(load(id), 'ya_zaida', 2, 186)[1][4], 'دَعَانِۦ');
      expect(rules(load(id), 'ya_zaida', 2, 40).single[4], 'فَٱرۡهَبُونِۦ');
    }
  });
  test('stop annotations do not replace continuous text', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      for (final v in (d['variants'] as List).cast<List>()) {
        if (v.length < 9 ||
            v[8] is! Map ||
            (v[8] as Map)['source'] != yaqubSource) {
          continue;
        }
        expect((v[8] as Map)['sourcePage'], inInclusiveRange(7, 39));
        if ((v[8] as Map)['stopOnly'] == true) {
          expect(v[4], isEmpty);
          expect((v[8] as Map)['stopText'], isNotEmpty);
        }
      }
      expect(
        rules(d, 'ha_sakt', 2, 2),
        isEmpty,
        reason: 'negative lam is not interrogative lim',
      );
      expect(
        rules(d, 'ha_silah', 25, 69).single[6],
        matches(RegExp('(بلا|دون) صلة')),
      );
      expect(rules(d, 'ha_damir', 1, 7), isNotEmpty);
    }
  });
  test('unsupported narrator is refused before any mutation', () {
    final d = load('ruways'), before = jsonEncode(load('ruways'));
    expect(() => buildYaqubUsul(quran, d, 'warsh'), throwsArgumentError);
    expect(jsonEncode(d), before);
  });
  test(
    'all 24 Ruways kabir examples have their own assimilated spelling',
    () async {
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['ruways']);
      final q = await QuranRepository.load();
      final rows = (load('ruways')['variants'] as List)
          .cast<List>()
          .where((v) => v.length > 7 && v[7] == 'idgham_kabir')
          .toList();
      expect(rows, hasLength(24));
      for (final row in rows) {
        expect(row[3], 2, reason: '${row[0]}:${row[1]}:${row[2]}');
        final v = repo
            .at(['ruways'], row[0] as int, row[1] as int, row[2] as int)
            .singleWhere((v) => v.rule == 'idgham_kabir');
        final example = usulReadingText(
          v,
          q.ayah(v.surah, v.ayah),
          repo,
        ).split(' ');
        final first = lettersOf(example.first),
            second = lettersOf(example.last);
        if (v.surah == 27 && v.ayah == 36) {
          expect(example.first, contains('وٓنّ'));
        } else if (v.surah == 53 && v.ayah == 55) {
          expect(example.first, 'رَبِّكَ');
          expect(second[0], 'ت');
          expect(second[1], contains('ّ'));
        } else if (v.surah == 34 && v.ayah == 46) {
          expect(example.first, 'ثُمَّ');
          expect(second[0], 'ت');
          expect(second[1], contains('ّ'));
        } else {
          expect(first.last.length, 1, reason: example.join(' '));
          expect(second.first, contains('ّ'), reason: example.join(' '));
        }
      }
    },
  );
  test('every Rawh large-idgham span also covers both words', () {
    final rows = (load('rawh')['variants'] as List).cast<List>().where(
      (v) => v.length > 7 && v[7] == 'idgham_kabir',
    );
    expect(rows, hasLength(3));
    expect(rows.every((v) => v[3] == 2), isTrue);
  });
  test(
    'hasrati is a Ruways stopping rule with six-count madd, never lexical ha',
    () {
      final v = rules(load('ruways'), 'ha_sakt', 39, 56).single;
      expect(v[2], 3);
      expect(v[4], isEmpty);
      expect(v[8]['stopOnly'], isTrue);
      expect(v[8]['stopText'], 'يَٰحَسۡرَتَآهۡ');
      expect(v[6], contains('المد المشبع ست حركات'));
      expect(rules(load('rawh'), 'ha_sakt', 39, 56), isEmpty);
    },
  );
  test('ha sakt excludes lexical doubled ya and retains first-person ya', () {
    for (final id in ['ruways', 'rawh']) {
      final d = load(id);
      final hs = (d['variants'] as List)
          .cast<List>()
          .where(
            (v) =>
                v.length > 8 && v[7] == 'ha_sakt' && v[8]['stopOnly'] == true,
          )
          .toList();
      for (final v in hs) {
        final a = (quran['ayahs'] as List).firstWhere(
          (a) => a[0] == v[0] && a[1] == v[1],
        );
        final hf = (a[4] as String).split(' ')[v[2] as int];
        expect(hf.contains('نَّبِيّ'), isFalse, reason: '$id $hf');
        expect(hf.contains('ٱلۡحَيّ'), isFalse, reason: '$id $hf');
        expect(hf.contains('بُنَيّ'), isFalse, reason: '$id $hf');
      }
      expect(rules(d, 'ha_sakt', 3, 68), isEmpty); // النبي
      expect(
        rules(
          d,
          'ha_sakt',
          31,
          13,
        ).any((v) => (v[8]['stopText'] as String).contains('بُنَيّ')),
        isFalse,
      );
      expect(
        rules(
          d,
          'ha_sakt',
          14,
          22,
        ).any((v) => (v[8]['stopText'] as String).contains('مُصرِخِيَّ')),
        isTrue,
      );
      expect(
        rules(
          d,
          'ha_sakt',
          50,
          23,
        ).any((v) => (v[8]['stopText'] as String).startsWith('لَدَيَّ')),
        isTrue,
      );
      expect(
        rules(
          d,
          'ha_sakt',
          2,
          132,
        ).any((v) => (v[8]['stopText'] as String).contains('بَنِيَّ')),
        isTrue,
      );
    }
  });
  test(
    'checked extra ya catalogue covers all 86 verse endings and exclusions',
    () {
      final lengths = {
        for (final a in quran['ayahs'] as List)
          '${a[0]}:${a[1]}': (a[4] as String).split(' ').length,
      };
      for (final id in ['ruways', 'rawh']) {
        final d = load(id);
        final ys = (d['variants'] as List)
            .cast<List>()
            .where((v) => v.length > 8 && v[7] == 'ya_zaida')
            .toList();
        final continuousEnd = ys
            .where(
              (v) =>
                  (v[8] as Map)['stopOnly'] != true &&
                  v[2] == lengths['${v[0]}:${v[1]}']! - 1,
            )
            .toList();
        expect(continuousEnd, hasLength(86), reason: id);
        expect(rules(d, 'ya_zaida', 2, 186), hasLength(2));
        expect(rules(d, 'ya_zaida', 3, 175), hasLength(1));
        expect(
          rules(d, 'ya_zaida', 12, 90),
          isEmpty,
          reason: 'يتق is excluded',
        );
        expect(
          rules(d, 'ya_zaida', 12, 12),
          isEmpty,
          reason: 'نرتع is not a Yaqub extra ya',
        );
        expect(
          rules(d, 'ya_zaida', 39, 10),
          isEmpty,
          reason: 'vocative يا عباد الذين is deleted by agreement',
        );
        final stopped = ys
            .where((v) => (v[8] as Map)['stopOnly'] == true)
            .toList();
        expect(stopped, hasLength(id == 'rawh' ? 19 : 18));
        expect(
          (rules(d, 'ya_zaida', 6, 57).single[8] as Map)['stopText'],
          'يَقْضِۦ',
        );
        final atan = rules(d, 'ya_zaida', 27, 36).singleWhere((v) => v[2] == 7);
        expect((atan[8] as Map)['stopOnly'] == true, id == 'rawh');
        expect(
          rules(d, 'ya_zaida', 39, 16).any((v) => v[2] == 14),
          id == 'ruways',
        );
      }
    },
  );
  test('reviewed assets do not revive stale book usul at runtime', () async {
    final repo = await VariantRepository.discover();
    await repo.ensureLoaded(['ruways', 'rawh']);
    final q = await QuranRepository.load();
    for (final id in ['ruways', 'rawh']) {
      for (final w in [2, 19, 24]) {
        // Only kafirin has genuine Ruways imala in these early-page words.
        final rows = repo.at(
          [id],
          2,
          w,
          w == 2
              ? 0
              : w == 19
              ? 18
              : 12,
        );
        expect(
          rows.any((v) => v.isImala),
          id == 'ruways' && w != 2,
          reason: '$id 2:$w',
        );
      }
      final own = repo.at([id], 2, 11, 1);
      expect(own.any((v) => v.rule == 'ishmam'), id == 'ruways');
      final compared = compareReadings(
        repository: repo,
        ayah: q.ayah(2, 11),
        word: 1,
        displayed: null,
        selected: [id],
      );
      expect(compared.any((v) => v.rule == 'badal'), isFalse);
    }
    expect(
      repo.at(['ruways'], 19, 4, 3).any((v) => v.rule == 'ha_sakt'),
      isFalse,
      reason: 'وهن is a verb, not the feminine plural pronoun',
    );
  });
}
