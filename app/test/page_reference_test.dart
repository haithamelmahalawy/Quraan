import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';

void main() {
  test('the book\'s references to its own pages are left out', () {
    expect(
      withoutPageReference(
        'بالتحقيق، ولا خلاف بينهم في تحقيق الثانية إذا بدؤوا بها، انظر ص ٣٣٢',
      ),
      'بالتحقيق، ولا خلاف بينهم في تحقيق الثانية إذا بدؤوا بها',
    );
    expect(withoutPageReference('عند البدء بها، وانظر ص٢٢'), 'عند البدء بها');
    expect(withoutPageReference('انظر ص ١٠'), isEmpty);
  });

  test('no reading tells its word by another page', () {
    for (final file in Directory('assets/data/qiraat').listSync()) {
      if (!file.path.endsWith('.json')) continue;
      final json = jsonDecode(File(file.path).readAsStringSync()) as Map;
      for (final v in (json['variants'] as List).cast<List>()) {
        expect(
          '${v.length > 6 ? v[6] : ''}',
          isNot(contains('انظر ص')),
          reason: '${file.path} ${v.take(4).join(':')}',
        );
      }
    }
  });
}
