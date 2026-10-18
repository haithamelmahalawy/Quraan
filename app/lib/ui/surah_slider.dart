import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import 'theme.dart';

/// A slider over the 114 surahs below the page: dragging shows the surah's
/// name, letting go opens its first page.
class SurahSlider extends StatefulWidget {
  const SurahSlider({
    super.key,
    required this.quran,
    required this.page,
    required this.onGo,
  });

  final QuranRepository quran;

  /// The page shown, whose surah the slider rests on.
  final int page;

  /// Opens a page.
  final ValueChanged<int> onGo;

  @override
  State<SurahSlider> createState() => _SurahSliderState();
}

class _SurahSliderState extends State<SurahSlider> {
  /// The surah under the thumb while dragging.
  int? _dragged;

  @override
  Widget build(BuildContext context) {
    final current = widget.quran.page(widget.page).first.surah;
    final surah = widget.quran.surah(_dragged ?? current);
    final name = 'سورة ${surah.nameAr}';
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Hafs',
                fontSize: 17,
                color: MushafColors.green,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                showValueIndicator: ShowValueIndicator.onDrag,
                valueIndicatorTextStyle: const TextStyle(
                  fontFamily: 'Hafs',
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              // Surah 1 on the right, as the mushaf is read.
              child: Slider(
                min: 1,
                max: widget.quran.surahs.length.toDouble(),
                divisions: widget.quran.surahs.length - 1,
                value: surah.number.toDouble(),
                label: '${surah.number}. $name',
                activeColor: MushafColors.green,
                onChanged: (v) {
                  if (v.round() != _dragged) {
                    setState(() => _dragged = v.round());
                  }
                },
                onChangeEnd: (v) {
                  setState(() => _dragged = null);
                  final target = widget.quran.surah(v.round());
                  if (target.number != current) widget.onGo(target.startPage);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
