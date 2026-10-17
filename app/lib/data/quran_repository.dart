import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quran.dart';

/// Hafs base text, organised by mushaf page (Madinah mushaf, 604 pages).
class QuranRepository {
  QuranRepository._(this.surahs, this._pages);

  static const pageCount = 604;

  final List<Surah> surahs;
  final List<List<Ayah>> _pages;

  /// Ayahs on [page] (1-based).
  List<Ayah> page(int page) => _pages[page - 1];

  Surah surah(int number) => surahs[number - 1];

  /// The basmala as written at the start of Al-Fatiha.
  String get basmala => _pages[0].first.words.join(' ');

  static Future<QuranRepository> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/data/quran.json');
    return parse(raw);
  }

  static QuranRepository parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final surahs = [
      for (final s in json['surahs'] as List)
        Surah(
          number: s['n'] as int,
          nameAr: s['ar'] as String,
          nameEn: s['en'] as String,
          ayahCount: s['ayahs'] as int,
          startPage: s['page'] as int,
        ),
    ];
    final pages = List.generate(pageCount, (_) => <Ayah>[]);
    for (final a in json['ayahs'] as List) {
      final ayah = Ayah(
        surah: a[0] as int,
        number: a[1] as int,
        page: a[2] as int,
        juz: a[3] as int,
        words: (a[4] as String).split(' '),
      );
      pages[ayah.page - 1].add(ayah);
    }
    return QuranRepository._(surahs, pages);
  }
}
