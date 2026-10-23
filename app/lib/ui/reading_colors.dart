import 'package:flutter/material.dart';

import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import 'theme.dart';

/// Rule colours stay the same when the displayed/comparison riwaya changes.
/// Narrator colours identify lexical variants only.
abstract final class ReadingColors {
  static Color get naql => MushafColors.tone(const Color(0xFF1565C0));
  static Color get hamza => MushafColors.tone(const Color(0xFF7B1FA2));
  static Color get silah => MushafColors.tone(const Color(0xFFC62828));
  static Color get idgham => MushafColors.tone(const Color(0xFF546E7A));
  static Color get sakt => MushafColors.tone(const Color(0xFF795548));
  static Color get other => MushafColors.tone(const Color(0xFF455A64));

  static Color of(Variant v) {
    if (v.rule == 'ya_zaida') return MushafColors.green;
    if (v.isMarginNote) return MushafColors.ink;
    if (!v.isUsul) return qiraaOf(v.riwayaId).color;
    final d = v.description;
    if (v.rule == 'naql' || v.rule == 'naql_source' || d.contains('نقل')) {
      return naql;
    }
    if (v.isSakt) return sakt;
    if (v.isLinHamz) return MushafColors.green;
    if (const {
      'ibdal_waw',
      'ibdal_ya',
      'tasheel_pair',
      'tasheel_word',
      'ibdal_single',
      'ha_antum',
      'hamza_wasl',
    }.contains(v.rule)) {
      return hamza;
    }
    if (v.isBadal || v.isImala || v.isQasr) return MushafColors.green;
    if (v.isTarqiqOrTaghliz) return MushafColors.rule;
    if (RegExp('همز|إبدال|ابدال|تسهيل').hasMatch(d)) return hamza;
    if (d.contains('صلة')) return silah;
    if (RegExp('إدغام|ادغام').hasMatch(d)) return idgham;
    if (RegExp('المد|القصر|البدل').hasMatch(d)) return MushafColors.green;
    return other;
  }

  static Color forLabel(String label) {
    if (label == 'ياءات الزوائد') return MushafColors.green;
    if (label.contains('مد اللين المهموز')) return MushafColors.green;
    if (label == 'النقل') return naql;
    if (label.contains('السكت')) return sakt;
    if (label.contains('همز') || label == 'الإشمام') return hamza;
    if (label.contains('صلة')) return silah;
    if (label.contains('إدغام') || label.contains('الإدغام')) return idgham;
    if (label == 'ترقيق الراء' || label == 'تغليظ اللام') {
      return MushafColors.rule;
    }
    if (RegExp('المد|المنفصل|الإمالة|التقليل').hasMatch(label)) {
      return MushafColors.green;
    }
    return other;
  }

  static Color? ofReadings(List<Variant> readings) {
    readings = readings.where((v) => !v.isMarginNote).toList();
    if (readings.isEmpty) return null;
    final farsh = readings.where((v) => !v.isUsul).toList();
    final relevant = farsh.isEmpty ? readings : farsh;
    final colors = relevant.map(of).toSet();
    return colors.length == 1 ? colors.single : MushafColors.multi;
  }
}
