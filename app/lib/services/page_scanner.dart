import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

import '../data/page_matcher.dart';

/// Reads a photo of a printed mushaf page and finds the page it shows.
///
/// Text is recognised on the device with Tesseract (Arabic, tessdata_fast);
/// the recognition is imperfect for Uthmani script, so the page is found by
/// [PageMatcher] from the words it does read.
class PageScanner {
  PageScanner(this.matcher);

  final PageMatcher matcher;

  /// The page shown in the image at [path], or null if it is not clear.
  Future<({int page, double score})?> scan(String path) async {
    final text = await FlutterTesseractOcr.extractText(
      path,
      language: 'ara',
      args: {
        'psm': '4', // a single column of text of variable sizes
        'preserve_interword_spaces': '1',
      },
    );
    return matcher.match(text);
  }
}
