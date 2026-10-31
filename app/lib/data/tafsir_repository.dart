import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'tafsir_text.dart';

/// A book of tafsir.
class TafsirBook {
  const TafsirBook(
    this.id,
    this.name,
    this.author, {
    this.offline = false,
    this.source = TafsirRepository.source,
  });

  /// Quranpedia's book id (90000 and above: the app's own).
  final int id;
  final String name;
  final String author;

  /// Where its text is from.
  final String source;

  /// Stored in the app (`assets/data/tafsir/<id>.json.gz`); otherwise read
  /// from Quranpedia, ayah by ayah.
  final bool offline;
}

/// Tafsir of an ayah from several books, from the Quranpedia encyclopedia
/// (الموسوعة القرآنية): the short books are in the app (built by
/// `tool/build_tafsir.dart` from its official dumps), the long ones are read
/// online per ayah (its licence allows use inside apps) and kept for the
/// session.
class TafsirRepository {
  TafsirRepository({AssetBundle? bundle, http.Client? client})
    : _bundle = bundle ?? rootBundle,
      _client = client ?? http.Client();

  static const source = 'الموسوعة القرآنية quranpedia.net';

  static const books = [
    TafsirBook(2012, 'التفسير الميسر', 'مجمع الملك فهد', offline: true),
    TafsirBook(2003, 'المختصر في التفسير', 'مركز تفسير', offline: true),
    TafsirBook(3, 'تفسير السعدي', 'السعدي', offline: true),
    TafsirBook(272, 'تفسير الجلالين', 'المحلي والسيوطي', offline: true),
    TafsirBook(2013, 'معاني الكلمات', 'السراج في غريب القرآن', offline: true),
    TafsirBook(136, 'تفسير ابن كثير', 'ابن كثير'),
    TafsirBook(4, 'تفسير الطبري', 'الطبري'),
    TafsirBook(2, 'تفسير البغوي', 'البغوي'),
    TafsirBook(184, 'تفسير ابن عاشور', 'ابن عاشور'),
    TafsirBook(321, 'التفسير الوسيط', 'محمد سيد طنطاوي'),
    TafsirBook(340, 'زاد المسير', 'ابن الجوزي'),
    TafsirBook(350, 'المحرر الوجيز', 'ابن عطية'),
    TafsirBook(343, 'فتح القدير', 'الشوكاني'),
    TafsirBook(308, 'أضواء البيان', 'الشنقيطي'),
  ];

  /// The books of i'rab, read like the tafsir, ayah by ayah: al-Da'as's,
  /// word by word for the whole Quran, and al-Kharrat's short one in the app.
  static const e3rabBooks = [
    TafsirBook(316, 'إعراب القرآن', 'الدعاس', offline: true),
    TafsirBook(180, 'المجتبى من مشكل الإعراب', 'أحمد الخراط', offline: true),
    TafsirBook(309, 'التبيان في إعراب القرآن', 'العكبري'),
    TafsirBook(318, 'إعراب القرآن', 'ابن النحاس'),
  ];

  /// The books of the reasons of the readings (توجيه القراءات), in the app
  /// (built by `tool/build_tawjih.dart`).
  static const tawjihBooks = [
    TafsirBook(
      90001,
      'حجة القراءات',
      'ابن زنجلة',
      offline: true,
      source: 'مشروع OpenITI (نص المكتبة الشاملة)',
    ),
  ];

  /// The books of stopping and starting (الوقف والابتداء), in the app
  /// (built by `tool/build_waqf.dart`).
  static const waqfBooks = [
    TafsirBook(
      90002,
      'المكتفى في الوقف والابتدا',
      'أبو عمرو الداني',
      offline: true,
      source: 'مشروع OpenITI (نص المكتبة الشاملة)',
    ),
  ];

  static TafsirBook book(int id) => [
    ...books,
    ...e3rabBooks,
    ...tawjihBooks,
    ...waqfBooks,
  ].firstWhere((b) => b.id == id);

  final AssetBundle _bundle;
  final http.Client _client;

  /// Offline books, loaded on first use: text by surah * 1000 + ayah.
  final _offline = <int, Future<Map<int, String>>>{};
  final _online = <String, String?>{};

  /// The tafsir of the ayah in [book]; null when the book has none for it.
  /// Throws when an online book cannot be reached.
  Future<String?> text(TafsirBook book, int surah, int ayah) async {
    if (book.offline) {
      final texts = await _offline.putIfAbsent(book.id, () => _load(book.id));
      return texts[surah * 1000 + ayah];
    }
    final key = '${book.id}:$surah:$ayah';
    if (_online.containsKey(key)) return _online[key];
    final uri = Uri.parse(
      'https://api.quranpedia.net/v1/ayah/$surah/$ayah/book/${book.id}',
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return _online[key] = null;
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final text = [
      for (final c
          in (json is Map ? json['content'] as List? : null) ?? const [])
        tafsirText((c as Map)['text'] as String? ?? ''),
    ].where((t) => t.isNotEmpty).join('\n\n');
    return _online[key] = text.isEmpty ? null : text;
  }

  /// The book's texts of the ayahs [from] to [to] of [surah], each once and
  /// in order: a text the book gives to several ayahs together is one.
  Future<List<String>> textsOf(
    TafsirBook book,
    int surah,
    int from,
    int to,
  ) async {
    final texts = <String>[];
    for (var ayah = from; ayah <= to; ayah++) {
      final text = await this.text(book, surah, ayah);
      if (text != null && !texts.contains(text)) texts.add(text);
    }
    return texts;
  }

  Future<Map<int, String>> _load(int id) async {
    final data = await _bundle.load('assets/data/tafsir/$id.json.gz');
    return compute(
      _decode,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
}

Map<int, String> _decode(Uint8List bytes) {
  final json = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map;
  final texts = (json['texts'] as List).cast<String>();
  return {
    for (final a in json['ayahs'] as List)
      (a[0] as int) * 1000 + (a[1] as int): texts[a[2] as int],
  };
}
