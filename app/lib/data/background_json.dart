import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// A big book's JSON decoded off the thread that draws the pages, so its
/// first reading does not hold them; handed back whole, not copied. In tests,
/// on the same thread.
Future<Object?> decodeJsonApart(String raw) =>
    kIsWeb || _inTest ? Future.value(jsonDecode(raw)) : compute(_decode, raw);

Object? _decode(String raw) => jsonDecode(raw);

final _inTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Whether the app runs under the tests: no work begun ahead there.
bool get runningTests => _inTest;
