import 'dart:convert';

import 'package:flutter/services.dart';

/// A note of the book without its references to its own pages («انظر ص
/// ٣٣٢»): the margin tells each word itself, not where else to look.
String withoutPageReference(String note) =>
    note.replaceAll(RegExp(r'[،,]?\s*و?انظر ص\s*[٠-٩0-9]+[.،]?'), '').trim();

/// One way a word is read, as «التسهيل لقراءات التنزيل» states it.
class KharoufReading {
  const KharoufReading({
    required this.text,
    required this.riwayat,
    required this.disputed,
    required this.how,
    required this.stopOnly,
    required this.taqlil,
    this.notes = const [],
  });

  /// The reading as the book quotes it; empty when only described.
  final String text;

  /// Riwayat that read it (ids of the catalog), and those that read it
  /// with a dispute (بخلف).
  final List<String> riwayat;
  final List<String> disputed;

  /// Short technical wording of how it is read (بتسهيل الهمزة الثانية).
  final String how;

  /// When stopping on the word only (وقفاً).
  final bool stopOnly;

  /// Taqlil rather than full imala (in the الممال section).
  final bool taqlil;

  /// What the book adds on other readers (ووقف حمزة بالتسهيل، ولورش ثلاثة
  /// البدل), each with the riwayat it names: told only where they are read.
  final List<(String, List<String>)> notes;

  bool get readsAsHafs => riwayat.contains('hafs');
}

/// The book's note on a Hafs word: its readings and the verses of the
/// Shatibiyya and the Durrah it cites.
class KharoufEntry {
  const KharoufEntry({
    required this.surah,
    required this.ayah,
    required this.word,
    required this.count,
    required this.section,
    required this.readings,
    required this.verses,
  });

  final int surah, ayah, word, count;

  /// farsh, mumal (imala), mudgham (idgham).
  final String section;
  final List<KharoufReading> readings;
  final List<String> verses;

  String get sectionAr => switch (section) {
    'mumal' => 'الممال',
    'mudgham' => 'المدغم',
    _ => 'الفرش',
  };
}

/// The certified source of who reads what: Kharouf's «التسهيل لقراءات
/// التنزيل من الشاطبية والدرة», reviewed by Sheikh Karim Rajih
/// (assets/data/kharouf.json, built by tool/build_kharouf.dart).
class Kharouf {
  Kharouf._(this.source, this.entries, this._index);

  final String source;

  /// Each transcribed note once, in Quran order, for browsing the source.
  final List<KharoufEntry> entries;
  final Map<int, List<KharoufEntry>> _index;

  static Future<Kharouf>? _loading;

  static Future<Kharouf> load([AssetBundle? bundle]) => _loading ??= () async {
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/data/kharouf.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final index = <int, List<KharoufEntry>>{};
    final entries = <KharoufEntry>[];
    for (final e in json['entries'] as List) {
      final entry = KharoufEntry(
        surah: e[0] as int,
        ayah: e[1] as int,
        word: e[2] as int,
        count: e[3] as int,
        section: e[4] as String,
        readings: [
          for (final g in e[5] as List)
            ..._stopApart(
              KharoufReading(
                text: g[0] as String,
                riwayat: (g[1] as List).cast<String>(),
                disputed: (g[2] as List).cast<String>(),
                how: withoutPageReference(g[3] as String),
                stopOnly: g[4] as bool,
                taqlil: g.length > 5 && g[5] == true,
                notes: [
                  if (g.length > 6)
                    for (final n in g[6] as List)
                      (
                        withoutPageReference(n[0] as String),
                        (n[1] as List).cast<String>(),
                      ),
                ],
              ),
            ),
        ],
        verses: (e[6] as List).cast<String>(),
      );
      entries.add(entry);
      for (var w = entry.word; w < entry.word + entry.count; w++) {
        (index[_key(entry.surah, entry.ayah, w)] ??= []).add(entry);
      }
    }
    entries.sort((a, b) {
      final location = _key(
        a.surah,
        a.ayah,
        a.word,
      ).compareTo(_key(b.surah, b.ayah, b.word));
      return location != 0 ? location : a.section.compareTo(b.section);
    });
    return Kharouf._(
      json['source'] as String,
      List.unmodifiable(entries),
      index,
    );
  }();

  /// Hamzah's narrators, and Hisham with them, change the hamza when stopping
  /// only. The book tells them with those who read it so in wasl too
  /// («يستهزُون» of Abu Ja'far، «وبيس» of Warsh and al-Susi), marked «وقفاً» as
  /// a whole: the mark is theirs alone.
  static const _hamzaStop = {'khalaf_hamzah', 'khallad', 'hisham'};

  static List<KharoufReading> _stopApart(KharoufReading r) {
    if (!r.stopOnly ||
        !r.riwayat.any(const {'khalaf_hamzah', 'khallad'}.contains)) {
      return [r];
    }
    KharoufReading part(bool stop) => KharoufReading(
      text: r.text,
      riwayat: [
        for (final id in r.riwayat)
          if (_hamzaStop.contains(id) == stop) id,
      ],
      disputed: [
        for (final id in r.disputed)
          if (_hamzaStop.contains(id) == stop) id,
      ],
      how: r.how,
      stopOnly: stop,
      taqlil: r.taqlil,
      notes: r.notes,
    );
    final always = part(false);
    return [
      if (always.riwayat.isNotEmpty || always.disputed.isNotEmpty) always,
      part(true),
    ];
  }

  static int _key(int surah, int ayah, int word) =>
      surah * 1000000 + ayah * 1000 + word;

  /// The book's notes on the Hafs word [word] of [surah]:[ayah].
  List<KharoufEntry> at(int surah, int ayah, int word) =>
      _index[_key(surah, ayah, word)] ?? const [];
}
