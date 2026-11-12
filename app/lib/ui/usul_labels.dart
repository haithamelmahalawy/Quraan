import 'package:flutter/material.dart';

import '../data/lin_hamz.dart';
import '../data/usul_guide.dart';
import '../data/waqf_hamza.dart';
import '../models/quran.dart';
import 'reading_colors.dart';
import 'theme.dart';

const _singleHamzaIbdal = 'الهمز المفرد (إبدال الهمز)';

/// The labels a general rule is told under in the page's key, with their
/// colours: «مد البدل»، «النقل»، «التقليل»...
List<(String, Color)> usulKindsOf(Variant v) {
  final own = ReadingColors.of(v);
  return v.isBadal
      ? [('مد البدل', MushafColors.green)]
      : v.rule == 'tarqiq'
      ? [('ترقيق الراء', MushafColors.rule)]
      : v.rule == 'taghliz'
      ? [('تغليظ اللام', MushafColors.rule)]
      : v.isSakt
      ? [('السكت قبل الهمز', own)]
      : v.readsAsHafs
      ? [('الإدغام بلا غنة', own)]
      : v.isQasr
      ? [('قصر المنفصل', own)]
      : [
          if (v.isImala)
            // Warsh has no imala of his own: taqlil only.
            v.riwayaId == 'warsh' || RegExp('تقليل|بين').hasMatch(v.description)
                ? ('التقليل', MushafColors.green)
                : ('الإمالة', MushafColors.green),
          for (final l in usulOf(v))
            if (!v.isImala || l != 'المدود') (l, own),
          if (!v.isImala && usulOf(v).isEmpty) ('أصول أخرى', own),
        ];
}

/// The usul a reading applies, by its description: the key's wording.
List<String> usulOf(Variant v) {
  // «الوقف على الهمز» by its kinds, Hamza's and Hisham's alike.
  if (v.rule == 'hisham_waqf') {
    final kind = v.usulKind.isNotEmpty
        ? v.usulKind
        : v.riwayaId == 'hisham'
        ? waqfHamzaKindOfFinal(v.usulText)
        : null;
    if (kind != null) return ['الوقف على الهمز ($kind)'];
  }
  final typed = ReadingColors.labelForRule(v.rule);
  if (typed != null) return [typed];
  final d = v.description;
  if (v.rule == 'ya_zaida') return ['ياءات الزوائد'];
  if (v.isLinHamz) {
    return [LinHamz.values.singleWhere((kind) => kind.rule == v.rule).label];
  }
  final unified = usulUnifiedRiwayat.contains(v.riwayaId);
  if (isMaddFarq(v)) {
    return ['الهمزتان من كلمة (مد الفرق)', if (d.contains('نقل')) 'النقل'];
  }
  // أَذۡهَبۡتُمۡ: its two open hamzas told without a rule of their own.
  if (unified && d.contains('بهمزتين مفتوحتين')) {
    return ['الهمزتان من كلمة (${twoHamzasKind(v)})'];
  }
  if (v.rule == 'tasheel_word' && unified) {
    return [
      'الهمزتان من كلمة (${twoHamzasKind(v)})',
      if (d.contains('صلة ميم الجمع')) 'صلة ميم الجمع',
    ];
  }
  if (v.rule == 'tasheel_word') {
    if (v.description.contains('تحقيق') && !v.description.contains('تسهيل')) {
      return ['الهمزتان في كلمة'];
    }
    // Named by the vowel of the second hamza of the word (ءَأَنذَرۡتَهُمۡ،
    // أَئِنَّكُمۡ، أَءُنزِلَ).
    // (Ibn 'Amir's readings; the others keep their own names.)
    final match = RegExp('[ءأإئؤ][ً-ٰٟ]*[^ءأإئؤ]{0,2}?[ءأإئؤ]([ً-ٰٟ]*)')
        .firstMatch(v.usulText);
    final second = const {'hisham', 'ibn_dhakwan'}.contains(v.riwayaId)
        ? match?.group(1)
        : null;
    return [
      second == null
          ? v.usulWays.length > 1
                ? 'الهمزتان المفتوحتان في كلمة'
                : 'تسهيل الهمزتين في كلمة'
          : second.contains('ِ')
          ? 'الهمزتان المفتوحة والمكسورة في كلمة'
          : second.contains('ُ')
          ? 'الهمزتان المفتوحة والمضمومة في كلمة'
          : 'الهمزتان المفتوحتان في كلمة',
      if (d.contains('صلة ميم الجمع')) 'صلة ميم الجمع',
    ];
  }
  if (v.rule == 'tasheel_pair' ||
      v.rule == 'tasheel_pair_first' ||
      (v.rule == 'ibdal_waw' && v.usulWays.length > 1) ||
      (unified &&
          (d.contains('إبدال الهمزة الثانية') ||
              d.startsWith('تحقيق الهمزتين')))) {
    return [
      unified
          ? 'الهمزتان من كلمتين (${twoWordsKind(v)})'
          : 'الهمزتان من كلمتين',
      if (d.contains('صلة ميم الجمع')) 'صلة ميم الجمع',
    ];
  }
  if (v.rule == 'ha_antum') return ['الهمز المفرد (الهمز المتحرك)'];
  // «ٱلَّٰٓـِٔي»: its last hamza, with the ya after it or without.
  if (v.rule == 'hamza_mutatarrif') return ['الهمز المفرد (الهمز المتطرف)'];
  if (v.rule == 'hamza_hadhf') return ['الهمز المفرد (حذف الهمزة)'];
  // «ٱلنَّبِيٓءُ» and its bab, for Warsh as for Qalun.
  if (v.rule == 'hamza_zaida') {
    return [
      'الهمز المفرد (زيادة الهمزة)',
      if (d.contains('صلة ميم الجمع')) 'صلة ميم الجمع',
    ];
  }
  if (isWarshHamzaNaql(v)) return ['النقل'];
  if (unified &&
      RegExp('صلة الهاء|الهاء مع الصلة|هاء مضمومة دون صلة').hasMatch(d)) {
    return ['هاء الكناية'];
  }
  if (v.riwayaId == 'warsh') {
    if (d == 'بتخفيف الهمزة') return [_singleHamzaIbdal];
    if (isWarshRabbahuMadd(v)) return ['المد المنفصل'];
    if (isWarshAnaMadd(v)) return ['مد أنا'];
  }
  // What the sources of Qalun, Ibn Kathir and Abu Ja'far tell without a rule.
  if (unified && v.riwayaId != 'warsh' && v.rule.isEmpty) {
    if (d.startsWith('بفتح الراء وحذف الهمزة') ||
        d == 'بالسين' ||
        // «وَسَلِ»، «فَسَلُواْ»: Ibn Kathir's naql of the hamza to the sin.
        d.startsWith('بنقل حركة الهمزة')) {
      return ['النقل'];
    }
    // «فَٱسۡرِ»: its hamza eased, told as its qat' made a wasl.
    if (d.startsWith('بتخفيف الهمزة - ')) {
      return ['الهمز المفرد (تخفيف الهمزة)'];
    }
    if (!d.contains('إبدال')) {
      if (RegExp('زيادة الهمزة|^بالهمز').hasMatch(d)) {
        return ['الهمز المفرد (زيادة الهمزة)'];
      }
      if (d.contains('حذف الهمزة') && d.contains('تشديد')) {
        return ['الهمز المفرد (إدغام الهمزة)'];
      }
      if (RegExp(r'حذف الهمزة|^بالباء$|^بالهاء$').hasMatch(d)) {
        return ['الهمز المفرد (حذف الهمزة)'];
      }
      if (d.contains('تخفيف الهمز')) return ['الهمز المفرد (تخفيف الهمزة)'];
      if (d.contains('تسهيل')) return ['الهمز المفرد (تسهيل الهمزة)'];
    }
  }
  // Ya'qub's naql (عَادٗا ٱلُّاولَىٰ) is told in its own chapter only, though its
  // note names the merged tanween; so Ibn Wardan's, «مِلُ» «بضم اللام وحذف الهمزة».
  if (v.rule == 'naql' &&
      const {
        'ruways',
        'rawh',
        'ibn_wardan',
        'ibn_jammaz',
      }.contains(v.riwayaId)) {
    return ['النقل'];
  }
  if (v.rule == 'hamza_wasl') {
    return ['همزة الاستفهام مع همزة الوصل', if (d.contains('نقل')) 'النقل'];
  }
  return [
    if (RegExp('صلة (ال)?ميم|وصلة الميم|صلة الميم').hasMatch(d))
      'صلة ميم الجمع',
    if (RegExp('صلة (ال)?هاء|بصلة الهاء|ترك صلة').hasMatch(d)) 'صلة هاء الضمير',
    if (RegExp('إدغام|ادغام|الإدغام').hasMatch(d)) 'الإدغام',
    if (RegExp(r'نقل').hasMatch(d)) 'النقل',
    if (RegExp('إبدال|ابدال').hasMatch(d))
      unified ? _singleHamzaIbdal : 'إبدال الهمز',
    if (RegExp('تسهيل').hasMatch(d)) 'تسهيل الهمز',
    if (RegExp('تخفيف الهمز|حذف الهمزة').hasMatch(d) && !d.contains('تسهيل'))
      'الهمزات',
    if (RegExp('تحقيق الهمز').hasMatch(d)) 'تحقيق الهمز',
    if (d.contains('البدل')) 'مد البدل',
    // Ya'qub's madd is known of the riwaya, not told at each word.
    if (!const {'ruways', 'rawh'}.contains(v.riwayaId) &&
        RegExp(r'(^|\s)(ب|و)?(ال)?مد|ومدها|القصر').hasMatch(d) &&
        !v.isQasr &&
        !d.contains('البدل') &&
        !RegExp('المتصل|المنفصل').hasMatch(d))
      'المدود',
    if (RegExp('إشمام|الإشمام').hasMatch(d)) 'الإشمام',
    if (RegExp('سكت').hasMatch(d) && !d.contains('دون سكت')) 'السكت',
  ];
}
