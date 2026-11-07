import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/page_matcher.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';

/// Simulates poor OCR of a printed page: no diacritics, a third of the words
/// corrupted, some words lost, the page number sometimes read.
String noisyOcr(QuranRepository quran, int page, Random rnd) {
  const letters = 'بتثجحخدذرزسشصضطظعغفقكلمنهوي';
  final out = <String>[];
  for (final a in quran.page(page)) {
    for (final w in a.words) {
      if (rnd.nextDouble() < 0.3) continue; // missed
      var plain = String.fromCharCodes(
        w.runes.where((c) => (c >= 0x0621 && c <= 0x064A) || c == 0x0671),
      ).replaceAll('ٱ', 'ا');
      if (plain.isEmpty) continue;
      if (rnd.nextDouble() < 0.35) {
        final i = rnd.nextInt(plain.length);
        final r = letters[rnd.nextInt(letters.length)];
        plain = switch (rnd.nextInt(3)) {
          0 => plain.replaceRange(i, i + 1, r), // wrong letter
          1 => plain.replaceRange(i, i + 1, ''), // missing letter
          _ => plain.replaceRange(i, i, r), // extra letter
        };
      }
      // Uthmani script is often read with the space to the previous word
      // missing.
      if (out.isNotEmpty && rnd.nextDouble() < 0.25) {
        out.last += plain;
      } else {
        out.add(plain);
      }
    }
  }
  if (rnd.nextBool()) {
    out.add(
      page
          .toString()
          .split('')
          .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
          .join(),
    );
  }
  // About ten words a line, as on a printed page.
  return [
    for (var i = 0; i < out.length; i += 10)
      out.sublist(i, min(i + 10, out.length)).join(' '),
  ].join('\n');
}

void main() {
  test('a page is recognised from noisy OCR text', () {
    final quran = QuranRepository.parse(
      File('assets/data/quran.json').readAsStringSync(),
    );
    final matcher = PageMatcher(quran);
    final rnd = Random(7);
    var right = 0, wrong = 0, unsure = 0;
    final failures = <String>[];
    for (var k = 0; k < 80; k++) {
      final page = 1 + rnd.nextInt(quran.pageCount);
      final m = matcher.match(noisyOcr(quran, page, rnd));
      if (m == null) {
        unsure++;
        failures.add('$page→?');
      } else if (m.page == page) {
        right++;
      } else {
        wrong++;
        failures.add('$page→${m.page}');
      }
    }
    // ignore: avoid_print
    print('right $right, unsure $unsure, wrong $wrong  $failures');
    expect(wrong, 0);
    expect(right, greaterThanOrEqualTo(76));
  });

  test('random Arabic text is not taken for a page', () {
    final quran = QuranRepository.parse(
      File('assets/data/quran.json').readAsStringSync(),
    );
    final matcher = PageMatcher(quran);
    expect(matcher.match('مرحبا بكم في تطبيق القراءات اليوم جميل جدا'), isNull);
  });

  test(
    'a short central band identifies pages without requiring the whole text',
    () {
      final quran = QuranRepository.parse(
        File('assets/data/quran.json').readAsStringSync(),
      );
      final matcher = PageMatcher(quran);
      var right = 0;
      for (var page = 1; page <= quran.pageCount; page++) {
        final words = quran.page(page).expand((a) => a.words).toList();
        final start = max(0, (words.length - 40) ~/ 2);
        final band = words.sublist(start, min(start + 40, words.length));
        final text = [
          for (var i = 0; i < band.length; i += 8)
            band.sublist(i, min(i + 8, band.length)).join(' '),
        ].join('\n');
        final match = matcher.match(text);
        if (match == null) {
          continue; // the full-frame fallback handles ambiguity
        }
        expect(match.page, page, reason: 'central band on page $page');
        right++;
      }
      expect(right, greaterThanOrEqualTo(590));
      // ignore: avoid_print
      print('Central bands: $right/${quran.pageCount}, no wrong pages');
    },
  );

  test('one line in the middle of the page is enough, and never wrong', () {
    final quran = QuranRepository.parse(
      File('assets/data/quran.json').readAsStringSync(),
    );
    final matcher = PageMatcher(quran);
    final rnd = Random(11);
    const letters = 'بتثجحخدذرزسشصضطظعغفقكلمنهوي';
    var clean = 0, noisy = 0, wrong = 0;
    for (var page = 1; page <= quran.pageCount; page++) {
      final words = quran.page(page).expand((a) => a.words).toList();
      final start = max(0, (words.length - 9) ~/ 2);
      final line = words.sublist(start, min(start + 9, words.length));
      final exact = matcher.match(line.join(' '), lines: 1);
      if (exact != null) {
        exact.page == page ? clean++ : wrong++;
      }
      // Read without vowels, a word in five with a wrong letter.
      final read = [
        for (final w in line)
          if (String.fromCharCodes(
                w.runes.where((c) => c >= 0x0621 && c <= 0x064A),
              )
              case final plain when plain.isNotEmpty)
            rnd.nextDouble() < 0.2
                ? plain.replaceRange(
                    plain.length - 1,
                    plain.length,
                    letters[rnd.nextInt(letters.length)],
                  )
                : plain,
      ].join(' ');
      final m = matcher.match(read, lines: 1);
      if (m != null) {
        m.page == page ? noisy++ : wrong++;
      }
    }
    // ignore: avoid_print
    print('one line: clean $clean, noisy $noisy, wrong $wrong of 604');
    expect(wrong, 0);
    expect(clean, greaterThanOrEqualTo(555));
    expect(noisy, greaterThanOrEqualTo(520));
  });

  test('the page number read alone', () {
    final quran = QuranRepository.parse(
      File('assets/data/quran.json').readAsStringSync(),
    );
    final matcher = PageMatcher(quran);
    expect(matcher.pageNumber('١٨٨'), 188);
    expect(matcher.pageNumber(' 23\n'), 23);
    expect(matcher.pageNumber('٦٠٤'), 604);
    expect(matcher.pageNumber('٧٠٠'), isNull);
    expect(matcher.pageNumber('١٢ ٣٤'), isNull);
    expect(matcher.pageNumber(''), isNull);
  });

  test('Tesseract output of a photographed page', () {
    final quran = QuranRepository.parse(
      File('assets/data/quran.json').readAsStringSync(),
    );
    final matcher = PageMatcher(quran);
    // Al-A'raf 188-195, read from a phone photo (binarized, psm 6).
    final read = File('test/fixtures/ocr_page175.txt').readAsStringSync();
    expect(matcher.match(read)?.page, 175);
    // The same photo read as little more than noise: no page, not a wrong one.
    final noise = File('test/fixtures/ocr_noise.txt').readAsStringSync();
    expect(matcher.match(noise), isNull);
  });
}
