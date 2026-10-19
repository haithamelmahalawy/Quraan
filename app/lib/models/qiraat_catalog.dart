import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// One of the ten canonical qiraat.
class Qiraa {
  const Qiraa({
    required this.id,
    required this.nameAr,
    required this.shortAr,
    required this.nameEn,
    required this.baseColor,
    required this.riwayat,
  });

  final String id;
  final String nameAr;

  /// Name used in the hamesh, e.g. "نافع".
  final String shortAr;
  final String nameEn;

  /// The qiraa's colour on a light page.
  final Color baseColor;

  /// The qiraa's colour, toned for the current (light / dark) page.
  Color get color => MushafColors.tone(baseColor);
  final List<Riwaya> riwayat;
}

/// A riwaya (transmission) of a qiraa. Its variants are loaded from
/// `assets/data/qiraat/<id>.json` when that file exists.
class Riwaya {
  const Riwaya({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.fontFamily,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  /// Font of the text; the readings of every riwaya are drawn in the Hafs
  /// font, in the script of the Madinah mushaf.
  final String? fontFamily;
}

const hafsId = 'hafs';

const qiraat = <Qiraa>[
  Qiraa(
    id: 'nafi',
    nameAr: 'نافع المدني',
    shortAr: 'نافع',
    nameEn: "Nafi' al-Madani",
    baseColor: Color(0xFFC62828),
    riwayat: [
      Riwaya(id: 'qalun', nameAr: 'قالون', nameEn: 'Qalun'),
      Riwaya(id: 'warsh', nameAr: 'ورش', nameEn: 'Warsh'),
    ],
  ),
  Qiraa(
    id: 'ibn_kathir',
    nameAr: 'ابن كثير المكي',
    shortAr: 'ابن كثير',
    nameEn: 'Ibn Kathir al-Makki',
    baseColor: Color(0xFF1565C0),
    riwayat: [
      Riwaya(id: 'bazzi', nameAr: 'البزي', nameEn: 'al-Bazzi'),
      Riwaya(id: 'qunbul', nameAr: 'قنبل', nameEn: 'Qunbul'),
    ],
  ),
  Qiraa(
    id: 'abu_amr',
    nameAr: 'أبو عمرو البصري',
    shortAr: 'أبو عمرو',
    nameEn: "Abu 'Amr al-Basri",
    baseColor: Color(0xFF2E7D32),
    riwayat: [
      Riwaya(id: 'duri_abuamr', nameAr: 'الدوري', nameEn: 'al-Duri'),
      Riwaya(id: 'susi', nameAr: 'السوسي', nameEn: 'al-Susi'),
    ],
  ),
  Qiraa(
    id: 'ibn_amir',
    nameAr: 'ابن عامر الشامي',
    shortAr: 'ابن عامر',
    nameEn: "Ibn 'Amir al-Shami",
    baseColor: Color(0xFF6A1B9A),
    riwayat: [
      Riwaya(id: 'hisham', nameAr: 'هشام', nameEn: 'Hisham'),
      Riwaya(id: 'ibn_dhakwan', nameAr: 'ابن ذكوان', nameEn: 'Ibn Dhakwan'),
    ],
  ),
  Qiraa(
    id: 'asim',
    nameAr: 'عاصم الكوفي',
    shortAr: 'عاصم',
    nameEn: "'Asim al-Kufi",
    baseColor: Color(0xFF00838F),
    riwayat: [
      Riwaya(id: 'shubah', nameAr: 'شعبة', nameEn: "Shu'bah"),
      Riwaya(id: hafsId, nameAr: 'حفص', nameEn: 'Hafs', fontFamily: 'Hafs'),
    ],
  ),
  Qiraa(
    id: 'hamzah',
    nameAr: 'حمزة الكوفي',
    shortAr: 'حمزة',
    nameEn: 'Hamzah al-Kufi',
    baseColor: Color(0xFFEF6C00),
    riwayat: [
      Riwaya(id: 'khalaf_hamzah', nameAr: 'خلف', nameEn: 'Khalaf'),
      Riwaya(id: 'khallad', nameAr: 'خلاد', nameEn: 'Khallad'),
    ],
  ),
  Qiraa(
    id: 'kisai',
    nameAr: 'الكسائي الكوفي',
    shortAr: 'الكسائي',
    nameEn: "al-Kisa'i al-Kufi",
    baseColor: Color(0xFFAD1457),
    riwayat: [
      Riwaya(id: 'abul_harith', nameAr: 'أبو الحارث', nameEn: 'Abu al-Harith'),
      Riwaya(id: 'duri_kisai', nameAr: 'الدوري', nameEn: 'al-Duri'),
    ],
  ),
  Qiraa(
    id: 'abu_jafar',
    nameAr: 'أبو جعفر المدني',
    shortAr: 'أبو جعفر',
    nameEn: "Abu Ja'far al-Madani",
    baseColor: Color(0xFF6D4C41),
    riwayat: [
      Riwaya(id: 'ibn_wardan', nameAr: 'ابن وردان', nameEn: 'Ibn Wardan'),
      Riwaya(id: 'ibn_jammaz', nameAr: 'ابن جماز', nameEn: 'Ibn Jammaz'),
    ],
  ),
  Qiraa(
    id: 'yaqub',
    nameAr: 'يعقوب الحضرمي',
    shortAr: 'يعقوب',
    nameEn: "Ya'qub al-Hadrami",
    baseColor: Color(0xFF283593),
    riwayat: [
      Riwaya(id: 'ruways', nameAr: 'رويس', nameEn: 'Ruways'),
      Riwaya(id: 'rawh', nameAr: 'روح', nameEn: 'Rawh'),
    ],
  ),
  Qiraa(
    id: 'khalaf',
    nameAr: 'خلف العاشر',
    shortAr: 'خلف',
    nameEn: 'Khalaf al-Ashir',
    baseColor: Color(0xFF827717),
    riwayat: [
      Riwaya(id: 'ishaq', nameAr: 'إسحاق', nameEn: 'Ishaq'),
      Riwaya(id: 'idris', nameAr: 'إدريس', nameEn: 'Idris'),
    ],
  ),
];

final _byRiwaya = {
  for (final q in qiraat)
    for (final r in q.riwayat) r.id: (qiraa: q, riwaya: r),
};

Riwaya riwayaById(String id) => _byRiwaya[id]!.riwaya;

Qiraa qiraaOf(String riwayaId) => _byRiwaya[riwayaId]!.qiraa;
