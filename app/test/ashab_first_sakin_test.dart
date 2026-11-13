import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «التقاء الساكنين»: al-Kisa'i and Khalaf al-'Ashir with Nafi', Ibn Kathir,
/// Hisham and Abu Ja'far in all its places, one wording for them all: the
/// tanween «بضم التنوين وصلًا», the letters «بضم النون وصلًا» and the like
/// (the user, 2026-11-14).
void main() {
  test('al-Kisai and Khalaf read the first sakin with a damma everywhere', () {
    Map<String, String> of(String id) => {
      for (final v
          in ((jsonDecode(
                    File('assets/data/qiraat/$id.json').readAsStringSync(),
                  ) as Map)['variants']
                  as List)
              .cast<List>())
        if (v.length > 7 && v[7] == 'first_sakin')
          '${v[0]}:${v[1]}:${v[2]}': '${v[6]}',
    };
    final hisham = of('hisham');
    expect(hisham, hasLength(40));
    for (final id in const [
      'qalun',
      'warsh',
      'bazzi',
      'qunbul',
      'ibn_wardan',
      'ibn_jammaz',
      'abul_harith',
      'duri_kisai',
      'ishaq',
      'idris',
    ]) {
      expect(of(id), hisham, reason: id);
    }
    expect(hisham['4:49:13'], 'بضم التنوين وصلًا لالتقاء الساكنين');
    expect(hisham['23:32:4'], 'بضم النون وصلًا لالتقاء الساكنين');
    expect(hisham['17:110:3'], 'بضم الواو وصلًا لالتقاء الساكنين');
  });
}
