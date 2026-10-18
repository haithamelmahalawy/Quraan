import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int get page => _page;

  /// Underline words shared with similar ayahs (mutashabihat).
  bool get showMutashabihat => _showMutashabihat;

  /// Dark by default; light or following the system on request.
  ThemeMode get themeMode => _themeMode;

  /// Turn to the next page with a double blink (front camera, on device).
  bool get blinkToOpen => _blinkToOpen;

  /// Two facing pages at once, as the mushaf lies open (right page odd).
  bool get twoPages => _twoPages;

  /// Draw pages with the calligraphy of the printed Madinah mushaf (QCF V2
  /// page fonts, downloaded once per page).
  bool get qcfFont => _qcfFont;

  /// The replace mode only makes sense for a single riwaya.
  DisplayMode get mode => _mode == DisplayMode.replace && _selected.length != 1
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

  /// Remembers the page without rebuilding listeners.
  set page(int value) {
    _page = value;
    _prefs?.setInt('page', value);
  }
}
