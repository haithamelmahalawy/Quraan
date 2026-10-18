import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// The KFGQPC QCF V2 page fonts: the calligraphy of the printed Madinah
/// mushaf, one font per page in which every word is a single glyph.
///
/// A page's font is downloaded once (from the quran.com CDN, ~300–600 KB),
/// kept on the device and registered as `QCF_P<page>`. Pages whose font is
/// not available yet are drawn with the KFGQPC Hafs font.
class QcfFonts extends ChangeNotifier {
  QcfFonts._();

  static final instance = QcfFonts._();

  static String family(int page) => 'QCF_P$page';

  final _ready = <int>{};
  final _pending = <int, Future<void>>{};
  Directory? _dir;

  bool isReady(int page) => _ready.contains(page);

  /// Loads the fonts of [pages] (from disk, or downloads them); notifies
  /// listeners as each one becomes ready. Errors (offline) are ignored: the
  /// page keeps the Hafs font and is tried again next time.
  Future<void> ensure(Iterable<int> pages) => Future.wait([
        for (final p in pages)
          if (p >= 1 && p <= 604 && !_ready.contains(p))
            _pending.putIfAbsent(p, () => _load(p).whenComplete(() {
                  _pending.remove(p);
                })),
      ]);

  Future<void> _load(int page) async {
    try {
      _dir ??= Directory(
          '${(await getApplicationSupportDirectory()).path}/qcf_v2');
      final file = File('${_dir!.path}/p$page.ttf');
      if (!await file.exists()) {
        final response = await http
            .get(Uri.parse(
                'https://static.qurancdn.com/fonts/quran/hafs/v2/ttf/p$page.ttf'))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) return;
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      }
      final bytes = await file.readAsBytes();
      await (FontLoader(family(page))
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
      _ready.add(page);
      notifyListeners();
    } catch (e) {
      debugPrint('QCF font p$page: $e');
    }
  }
}
