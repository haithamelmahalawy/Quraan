import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// The KFGQPC QCF V1 page fonts: the calligraphy of the printed Madinah
/// mushaf (1405H, the print of assets/data/layout.json and qcf.json), one font per page in which every word is a single glyph.
///
/// A page's font is downloaded once (from the quran.com CDN, ~300–600 KB),
/// kept on the device and registered as `QCF_P<page>`. Pages whose font is
/// not available yet are drawn with the KFGQPC Hafs font.
class QcfFonts extends ChangeNotifier {
  QcfFonts._();

  static final instance = QcfFonts._();

  static String family(int page) => 'QCF_P$page';

  /// The print of the glyph codes in assets/data/qcf.json.
  static const version = 'v1';

  final _ready = <int>{};
  final _pending = <int>{};
  Directory? _dir;

  bool isReady(int page) => _ready.contains(page);

  /// Loads the fonts of [pages] (from disk, or downloads them), all
  /// registered together and told once: registering a font lays out every
  /// text of the app again, a long frame on a weak phone, so it is done
  /// once a batch, not once a page. Errors (offline) are ignored: the page
  /// keeps the Hafs font and is tried again next time.
  Future<void> ensure(Iterable<int> pages) async {
    final todo = [
      for (final p in pages.toSet())
        if (p >= 1 && p <= 604 && !_ready.contains(p) && !_pending.contains(p))
          p,
    ];
    if (todo.isEmpty) return;
    _pending.addAll(todo);
    try {
      final bytes = await Future.wait(todo.map(_bytes));
      final loaded = <int>[];
      await Future.wait([
        for (final (i, b) in bytes.indexed)
          if (b != null)
            (FontLoader(family(todo[i]))..addFont(Future.value(b)))
                .load()
                .then((_) => loaded.add(todo[i]))
                .catchError(
                  (Object e) => debugPrint('QCF font p${todo[i]}: $e'),
                ),
      ]);
      if (loaded.isEmpty) return;
      _ready.addAll(loaded);
      notifyListeners();
    } finally {
      _pending.removeAll(todo);
    }
  }

  /// A page's font, read from the device or downloaded once; null when it
  /// cannot be had (offline).
  Future<ByteData?> _bytes(int page) async {
    try {
      _dir ??= Directory(
        '${(await getApplicationSupportDirectory()).path}/qcf_$version',
      );
      final file = File('${_dir!.path}/p$page.ttf');
      if (!await file.exists()) {
        final response = await http
            .get(
              Uri.parse(
                'https://static.qurancdn.com/fonts/quran/hafs/$version/ttf/p$page.ttf',
              ),
            )
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) return null;
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      }
      return ByteData.sublistView(await file.readAsBytes());
    } catch (e) {
      debugPrint('QCF font p$page: $e');
      return null;
    }
  }
}
