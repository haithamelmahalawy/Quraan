import 'package:flutter/material.dart';

import '../models/quran.dart';
import 'theme.dart';

class PartitionMarker extends StatelessWidget {
  const PartitionMarker({
    super.key,
    required this.ayah,
    required this.fontSize,
  });
  final Ayah ayah;
  final double fontSize;

  static String label(Ayah a) {
    final rub = a.rubStart;
    if (a.juzStart) return 'بداية الجزء ${a.juz}';
    if (rub == null) return '';
    final hizb = (rub - 1) ~/ 4 + 1;
    return switch ((rub - 1) % 4) {
      0 => 'بداية الحزب $hizb',
      1 => 'ربع الحزب $hizb',
      2 => 'نصف الحزب $hizb',
      _ => 'ثلاثة أرباع الحزب $hizb',
    };
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label(ayah),
    child: Semantics(
      label: label(ayah),
      excludeSemantics: true,
      child: Text(
        '۞',
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Hafs',
          fontSize: fontSize * .8,
          height: 1,
          color: MushafColors.green,
        ),
      ),
    ),
  );
}
