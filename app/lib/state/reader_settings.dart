import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/quran_repository.dart';
import '../models/quran.dart';

enum DisplayMode {
  /// Clean Hafs text with numbered markers; the readings are listed in the
  /// hamesh (margin) outside the page, per qiraa.
  hamesh('الأصل حفص والخلاف في الهامش'),

  /// Hafs text; words read differently are coloured, tap for details.
  highlight('تلوين المواضع'),

  /// Hafs text with each selected reading written after the word.
  inline('إظهار القراءة بجانب الكلمة'),

  /// The page is rewritten in the (single) selected riwaya.
  replace('عرض النص بالرواية المختارة');

  const DisplayMode(this.labelAr);
  final String labelAr;
}

enum MarginLayout {
  organized('عرض تنظيمي'),
  sequential('عرض تسلسلي');

  const MarginLayout(this.labelAr);
  final String labelAr;
}

/// What the reader shows. Persisted between launches.
class ReaderSettings extends ChangeNotifier {
  ReaderSettings._(this._prefs);

  final SharedPreferences? _prefs;

  Set<String> _selected = {};
  Set<VariantKind> _kinds = VariantKind.values.toSet();
  DisplayMode _mode = DisplayMode.hamesh;
  double _fontSize = 24;
  int _page = 1;
  bool _showMutashabihat = true;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _blinkToOpen = false;
  bool _twoPages = false;
  bool _qcfFont = true;

  /// Selected riwayat (Hafs is always the base text and never listed here).
  Set<String> get selected => _selected;
  Set<VariantKind> get kinds => _kinds;
  double get fontSize => _fontSize;

  /// The page read, in the mushaf open ([edition]).
  int get page => edition == MushafEdition.madani
      ? _page
      : _get('page.${edition.name}') as int? ?? 2;

  /// Highlight words shared with similar ayahs (mutashabihat).
  bool get showMutashabihat => _showMutashabihat;

  /// Choices kept without [SharedPreferences] (tests).
  final _memory = <String, Object>{};

  Object? _get(String key) => _prefs?.get(key) ?? _memory[key];

  void _set(String key, Object value) {
    _memory[key] = value;
    switch (value) {
      case int v:
        _prefs?.setInt(key, v);
      case String v:
        _prefs?.setString(key, v);
      case bool v:
        _prefs?.setBool(key, v);
      case double v:
        _prefs?.setDouble(key, v);
    }
    notifyListeners();
  }

  MarginLayout get marginLayout =>
      MarginLayout.values.asNameMap()[_get('marginLayout')] ??
      MarginLayout.organized;
  set marginLayout(MarginLayout value) => _set('marginLayout', value.name);

  /// The sheikh chosen for a riwaya (a reciter id), null for the first.
  int? reciterFor(String riwaya) => _get('reciter.$riwaya') as int?;
  void setReciter(String riwaya, int id) => _set('reciter.$riwaya', id);

  /// The tafsir book shown first (a Quranpedia book id): al-Muyassar.
  int get tafsirBook => _get('tafsir') as int? ?? 2012;
  set tafsirBook(int id) => _set('tafsir', id);

  /// The book of i'rab shown first (a Quranpedia book id): al-Da'as's.
  int get e3rabBook => _get('e3rab') as int? ?? 316;
  set e3rabBook(int id) => _set('e3rab', id);

  /// Beside the ayah: its tafsir, its i'rab, or the reasons of its readings.
  BesideAyah get besideAyah =>
      BesideAyah.values.asNameMap()[_get('beside')] ??
      (_get('showE3rab') == true ? BesideAyah.e3rab : BesideAyah.tafsir);
  set besideAyah(BesideAyah value) => _set('beside', value.name);

  /// The i'rab shown beside the ayah.
  bool get showE3rab => besideAyah == BesideAyah.e3rab;
  set showE3rab(bool value) =>
      besideAyah = value ? BesideAyah.e3rab : BesideAyah.tafsir;

  /// The riwaya whose text the mushaf shows, when not Hafs: one of the
  /// selected riwayat (chosen in the riwayat menu), or the single one in
  /// the "replace" mode. The other selected riwayat are compared with it.
  String? get displayed {
    final base = _get('base') as String?;
    // Hafs chosen.
    if (base == 'hafs') return null;
    if (base != null && _selected.contains(base)) return base;
    if (mode == DisplayMode.replace && _selected.length == 1) {
      return _selected.single;
    }
    return null;
  }

  /// Shows the mushaf in [riwaya] (a selected riwaya), or Hafs (null).
  set displayed(String? riwaya) => _set('base', riwaya ?? 'hafs');

  /// Hafs among the riwayat compared with the one the mushaf shows: where
  /// that riwaya differs from Hafs, the hamesh gives Hafs's reading.
  bool get compareHafs => _get('compareHafs') as bool? ?? false;
  set compareHafs(bool on) => _set('compareHafs', on);

  /// «تنبيه الاختلافات»: how the words that differ from Hafs (farsh or
  /// usul) move to catch the eye; off when null.
  DiffAlert? get diffAlert =>
      DiffAlert.values.asNameMap()[_get('diffAlert') as String? ?? ''];
  set diffAlert(DiffAlert? style) => _set('diffAlert', style?.name ?? '');

  /// Where the lamp of «تنبيه الاختلافات» stands over the page, as
  /// fractions of its width and height: beside the hamesh at first.
  Offset get lampAt => Offset(
    (_get('lampX') as num?)?.toDouble() ?? 0.94,
    (_get('lampY') as num?)?.toDouble() ?? 0.55,
  );
  set lampAt(Offset at) {
    _memory['lampX'] = at.dx;
    _memory['lampY'] = at.dy;
    _prefs?.setDouble('lampX', at.dx);
    _set('lampY', at.dy);
  }

  /// The riwaya last listened to.
  String? get listenRiwaya => _get('listenRiwaya') as String?;
  set listenRiwaya(String? id) => _set('listenRiwaya', id ?? 'hafs');

  /// Dark by default; light or following the system on request.
  ThemeMode get themeMode => _themeMode;

  /// Turn to the next page with a double blink (front camera, on device).
  bool get blinkToOpen => _blinkToOpen;

  /// Two facing pages at once, as the mushaf lies open (right page odd).
  bool get twoPages => _twoPages;

  /// Draw pages with the calligraphy of the printed Madinah mushaf (QCF V2
  /// page fonts, downloaded once per page).
  bool get qcfFont => _qcfFont;

  /// The replace mode only makes sense for a single riwaya, and not when
  /// Hafs is chosen as the mushaf shown: then its readings go to the hamesh.
  DisplayMode get mode =>
      _mode == DisplayMode.replace &&
          (_selected.length != 1 || _get('base') == 'hafs')
      ? DisplayMode.hamesh
      : _mode;

  static Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Ayahs cached by the former online qiraat; the riwayat are now offline.
    for (final key in [...prefs.getKeys().where((k) => k.startsWith('qp1:'))]) {
      await prefs.remove(key);
    }
    final s = ReaderSettings._(prefs);
    s._selected = (prefs.getStringList('selected') ?? const []).toSet();
    final kinds = prefs.getStringList('kinds');
    if (kinds != null) {
      s._kinds = kinds.map(VariantKind.fromCode).toSet();
    }
    s._mode =
        DisplayMode.values.asNameMap()[prefs.getString('mode')] ??
        DisplayMode.hamesh;
    s._fontSize = prefs.getDouble('fontSize') ?? 24;
    s._page = prefs.getInt('page') ?? 1;
    s._showMutashabihat = prefs.getBool('mutashabihat') ?? true;
    s._blinkToOpen = prefs.getBool('blink') ?? false;
    s._twoPages = prefs.getBool('twoPages') ?? false;
    s._qcfFont = prefs.getBool('qcf') ?? true;
    s._themeMode =
        ThemeMode.values.asNameMap()[prefs.getString('theme')] ??
        ThemeMode.dark;
    return s;
  }

  /// In-memory settings (tests).
  @visibleForTesting
  factory ReaderSettings.memory({
    Set<String> selected = const {},
    DisplayMode mode = DisplayMode.hamesh,
  }) => ReaderSettings._(null)
    .._selected = {...selected}
    .._mode = mode;

  void setSelected(Set<String> ids) {
    _selected = {...ids};
    _prefs?.setStringList('selected', _selected.toList());
    notifyListeners();
  }

  void toggleKind(VariantKind kind, bool on) {
    _kinds = {..._kinds};
    on ? _kinds.add(kind) : _kinds.remove(kind);
    _prefs?.setStringList('kinds', _kinds.map((k) => k.code).toList());
    notifyListeners();
  }

  set mode(DisplayMode value) {
    _mode = value;
    _prefs?.setString('mode', value.name);
    notifyListeners();
  }

  set fontSize(double value) {
    _fontSize = value;
    _prefs?.setDouble('fontSize', value);
    notifyListeners();
  }

  set showMutashabihat(bool value) {
    _showMutashabihat = value;
    _prefs?.setBool('mutashabihat', value);
    notifyListeners();
  }

  set qcfFont(bool value) {
    _qcfFont = value;
    _prefs?.setBool('qcf', value);
    notifyListeners();
  }

  set twoPages(bool value) {
    _twoPages = value;
    _prefs?.setBool('twoPages', value);
    notifyListeners();
  }

  set blinkToOpen(bool value) {
    _blinkToOpen = value;
    _prefs?.setBool('blink', value);
    notifyListeners();
  }

  set themeMode(ThemeMode value) {
    _themeMode = value;
    _prefs?.setString('theme', value.name);
    notifyListeners();
  }

  /// Remembers the page (of the mushaf open) without rebuilding listeners.
  set page(int value) {
    if (edition == MushafEdition.madani) {
      _page = value;
      _prefs?.setInt('page', value);
    } else {
      _memory['page.${edition.name}'] = value;
      _prefs?.setInt('page.${edition.name}', value);
    }
  }

  /// The printed mushaf whose pages are shown.
  MushafEdition get edition =>
      MushafEdition.values.asNameMap()[_get('edition')] ?? MushafEdition.madani;

  /// Opens [value] at [page] (its page holding the place read).
  void openEdition(MushafEdition value, int page) {
    _memory['edition'] = value.name;
    _prefs?.setString('edition', value.name);
    this.page = page;
    notifyListeners();
  }
}

/// What the ayah sheet shows beside the ayah.
enum BesideAyah { tafsir, e3rab, tawjih, waqf }

/// «تنبيه الاختلافات»: the words that differ from Hafs glow, still.
enum DiffAlert {
  glow('توهج حول الكلمة');

  const DiffAlert(this.labelAr);

  final String labelAr;
}
