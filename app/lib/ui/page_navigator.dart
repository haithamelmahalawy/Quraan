import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/quran_repository.dart';
import 'mushaf_page.dart' show arabicDigits;
import 'theme.dart';

/// Two wheels over the mushaf, one of the surahs and one of the pages,
/// shown by a touch on the page where no word is (the user, 2026-11-14).
/// Each follows the other: a surah turned to brings its first page, a page
/// its surah; the mushaf goes there at once, a tick felt and heard at each.
class PageNavigator extends StatefulWidget {
  const PageNavigator({
    super.key,
    required this.quran,
    required this.page,
    required this.onGo,
  });

  final QuranRepository quran;

  /// The page read when it opens.
  final int page;

  /// The mushaf taken to a page.
  final ValueChanged<int> onGo;

  /// Its height.
  static const height = 226.0;

  @override
  State<PageNavigator> createState() => _PageNavigatorState();
}

class _PageNavigatorState extends State<PageNavigator> {
  late int _page = widget.page;
  late final _surahs = FixedExtentScrollController(
    initialItem: _surahOf(widget.page) - 1,
  );
  late final _pages = FixedExtentScrollController(
    initialItem: widget.page - widget.quran.firstPage,
  );

  /// One wheel turned by the other's choice: not a choice of its own.
  bool _following = false;

  @override
  void dispose() {
    _surahs.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// The surah a page begins in (its first ayah's).
  int _surahOf(int page) => widget.quran.page(page).first.surah;

  /// A tick felt and heard: a page or surah turned to.
  void _tick() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  void _go(int page) {
    if (page == _page) return;
    _page = page;
    widget.onGo(page);
  }

  void _surahChosen(int i) {
    _tick();
    if (_following) return;
    final page = widget.quran.surah(i + 1).startPage;
    _go(page);
    _follow(_pages, page - widget.quran.firstPage);
  }

  void _pageChosen(int i) {
    _tick();
    if (_following) return;
    final page = widget.quran.firstPage + i;
    _go(page);
    _follow(_surahs, _surahOf(page) - 1);
  }

  /// [wheel] brought to [item], its own choosing held back meanwhile.
  Future<void> _follow(FixedExtentScrollController wheel, int item) async {
    if (wheel.selectedItem == item) return;
    _following = true;
    await wheel.animateToItem(
      item,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
    _following = false;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quran;
    Widget wheel({
      required Key key,
      required FixedExtentScrollController controller,
      required int count,
      required ValueChanged<int> onChanged,
      required String Function(int) label,
      required TextStyle style,
    }) => ListWheelScrollView.useDelegate(
      key: key,
      controller: controller,
      itemExtent: 38,
      diameterRatio: 1.5,
      perspective: .004,
      useMagnifier: true,
      magnification: 1.15,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Center(child: Text(label(i), style: style)),
      ),
    );
    return Material(
      key: const ValueKey('page-navigator'),
      color: MushafColors.page.withAlpha(245),
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: PageNavigator.height,
        child: Stack(
          children: [
            // Which wheel is which, above them.
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  for (final (name, flex) in const [
                    ('السورة', 3),
                    ('الصفحة', 2),
                  ])
                    Expanded(
                      flex: flex,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: MushafColors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // The band the chosen ones stand in.
            Center(
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MushafColors.goldLight.withAlpha(150),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MushafColors.gold, width: 1.2),
                ),
              ),
            ),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  flex: 3,
                  child: wheel(
                    key: const ValueKey('surah-wheel'),
                    controller: _surahs,
                    count: q.surahs.length,
                    onChanged: _surahChosen,
                    label: (i) => 'سورة ${q.surahs[i].nameAr}',
                    style: TextStyle(
                      fontFamily: 'Hafs',
                      fontSize: 19,
                      color: MushafColors.ink,
                    ),
                  ),
                ),
                Container(width: 1, height: 150, color: MushafColors.gold),
                Expanded(
                  flex: 2,
                  child: wheel(
                    key: const ValueKey('page-wheel'),
                    controller: _pages,
                    count: q.lastPage - q.firstPage + 1,
                    onChanged: _pageChosen,
                    label: (i) => arabicDigits(q.firstPage + i),
                    // In the system's letters: Hafs's digits are small, and
                    // joined they are an ayah's ornament.
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: MushafColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
