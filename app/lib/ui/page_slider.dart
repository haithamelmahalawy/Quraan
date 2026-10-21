import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import 'theme.dart';

/// A slider over the printed pages: dragging previews the page's surah and
/// number, letting go opens that page.
class PageSlider extends StatefulWidget {
  const PageSlider({
    super.key,
    required this.quran,
    required this.page,
    required this.onGo,
  });

  final QuranRepository quran;

  /// The printed page shown, where the slider rests.
  final int page;

  /// Opens a page.
  final ValueChanged<int> onGo;

  @override
  State<PageSlider> createState() => _PageSliderState();
}

class _PageSliderState extends State<PageSlider> {
  /// The printed page under the thumb while dragging.
  int? _dragged;

  @override
  void didUpdateWidget(PageSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quran != widget.quran) _dragged = null;
  }

  @override
  Widget build(BuildContext context) {
    final page = (_dragged ?? widget.page).clamp(
      widget.quran.firstPage,
      widget.quran.lastPage,
    );
    final surah = widget.quran.surah(widget.quran.page(page).first.surah);
    final name = 'سورة ${surah.nameAr}';
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: 17,
                    height: 1.1,
                    color: MushafColors.green,
                  ),
                ),
                Text('ص $page', style: const TextStyle(fontSize: 12)),
              ],
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
              // The first page on the right, as the mushaf is read.
              child: Slider(
                min: widget.quran.firstPage.toDouble(),
                max: widget.quran.lastPage.toDouble(),
                divisions: widget.quran.pageCount - 1,
                value: page.toDouble(),
                label: '$name ـ ص $page',
                semanticFormatterCallback: (value) {
                  final number = value.round();
                  final surah = widget.quran.surah(
                    widget.quran.page(number).first.surah,
                  );
                  return 'سورة ${surah.nameAr}، صفحة $number';
                },
                activeColor: MushafColors.green,
                onChanged: (v) {
                  if (v.round() != _dragged) {
                    setState(() => _dragged = v.round());
                  }
                },
                onChangeEnd: (v) {
                  setState(() => _dragged = null);
                  final target = v.round();
                  if (target != widget.page) widget.onGo(target);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
