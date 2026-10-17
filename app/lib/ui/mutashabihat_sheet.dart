import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import 'theme.dart';

/// Carousel of the places of a mutashabih: swipe between them, each card
/// shows the ayah with the shared words highlighted and can jump to it.
class MutashabihatSheet extends StatefulWidget {
  const MutashabihatSheet({
    super.key,
    required this.places,
    required this.quran,
    required this.onGo,
  });

  final List<MutashabihPlace> places;
  final QuranRepository quran;

  /// Opens the mushaf at a page.
  final ValueChanged<int> onGo;

  static Future<void> show(
    BuildContext context, {
    required List<MutashabihPlace> places,
    required QuranRepository quran,
    required ValueChanged<int> onGo,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: MushafColors.paper,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.82,
          child: MutashabihatSheet(places: places, quran: quran, onGo: onGo),
        ),
      );

  @override
  State<MutashabihatSheet> createState() => _MutashabihatSheetState();
}

class _MutashabihatSheetState extends State<MutashabihatSheet>
    with SingleTickerProviderStateMixin {
  final _pages = PageController(viewportFraction: 0.86);
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _goTo(int i) => _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.places.length;
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.1).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: MushafColors.green,
                  child: Text('🔁', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المتشابهات اللفظية',
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: MushafColors.green,
                            fontWeight: FontWeight.bold)),
                    Text('$count مواضع متشابهة • اسحب للتنقل بينها',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Cards
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _index = i);
            },
            itemBuilder: (context, i) => AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final page = _pages.hasClients && _pages.position.haveDimensions
                    ? _pages.page!
                    : _index.toDouble();
                final delta = (page - i).clamp(-1.0, 1.0);
                return Opacity(
                  opacity: 1 - delta.abs() * 0.35,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateY(delta * math.pi / 9)
                      ..scaleByDouble(1 - delta.abs() * 0.1,
                          1 - delta.abs() * 0.1, 1, 1),
                    child: child,
                  ),
                );
              },
              child: _PlaceCard(
                place: widget.places[i],
                quran: widget.quran,
                isHere: i == 0,
                number: i + 1,
                total: count,
                onGo: () {
                  final page = widget.quran
                      .ayah(widget.places[i].surah, widget.places[i].ayah)
                      .page;
                  Navigator.of(context).pop();
                  widget.onGo(page);
                },
              ),
            ),
          ),
        ),
        // Navigation: arrows, dots, counter
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'السابق',
                onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < count; i++)
                          GestureDetector(
                            onTap: () => _goTo(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              width: i == _index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? MushafColors.green
                                    : MushafColors.gold.withAlpha(140),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, a) =>
                          ScaleTransition(scale: a, child: child),
                      child: Text(
                        _index == count - 1 && count > 1
                            ? '🎉 الموضع ${_index + 1} من $count'
                            : 'الموضع ${_index + 1} من $count',
                        key: ValueKey(_index),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'التالي',
                onPressed: _index < count - 1 ? () => _goTo(_index + 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.quran,
    required this.isHere,
    required this.number,
    required this.total,
    required this.onGo,
  });

  final MutashabihPlace place;
  final QuranRepository quran;
  final bool isHere;
  final int number;
  final int total;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final first = quran.ayah(place.surah, place.ayah);
    final last = place.parts.last;
    final ayahLabel = place.parts.length == 1
        ? 'الآية ${place.ayah}'
        : 'الآيات ${place.ayah}–${last.ayah}';
    final accent = isHere ? MushafColors.green : MushafColors.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: accent.withAlpha(60),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isHere
                      ? const [MushafColors.green, Color(0xFF3F8A66)]
                      : const [Color(0xFFB8913A), MushafColors.gold],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text(isHere ? '📍' : '✨', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سورة ${quran.surah(place.surah).nameAr}',
                      style: const TextStyle(
                        fontFamily: 'Hafs',
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _Chip(ayahLabel),
                  const SizedBox(width: 6),
                  _Chip('ص ${first.page}'),
                ],
              ),
            ),
            if (isHere)
              Container(
                color: MushafColors.green.withAlpha(20),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Text(
                  'أنت هنا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: MushafColors.green, fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text.rich(
                  TextSpan(children: [
                    for (final part in place.parts) ...[
                      for (final (w, word)
                          in quran.ayah(part.surah, part.ayah).words.indexed)
                        TextSpan(
                          text: '$word ',
                          style: part.words.contains(w)
                              ? TextStyle(
                                  color: MushafColors.green,
                                  backgroundColor:
                                      MushafColors.gold.withAlpha(90),
                                )
                              : null,
                        ),
                      TextSpan(text: '${_digits(part.ayah)} '),
                    ],
                  ]),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: 24,
                    height: 2.0,
                    color: MushafColors.ink,
                  ),
                ),
              ),
            ),
            if (!isHere)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MushafColors.green,
                  ),
                  onPressed: onGo,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('انتقل إلى الموضع'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(60),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
}

String _digits(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();
