import 'package:flutter/material.dart';

import '../data/manzumat.dart';
import 'theme.dart';

/// A verse: its number and its two halves, one under the other; marked when
/// it names the word.
class PoemVerse extends StatefulWidget {
  const PoemVerse({
    super.key,
    required this.bayt,
    required this.named,
    required this.explanation,
    required this.bookExplanation,
    this.fontSize = 16,
  });

  final Bayt bayt;
  final bool named;
  final BaytExplanation? explanation;
  final String bookExplanation;
  final double fontSize;

  @override
  State<PoemVerse> createState() => _PoemVerseState();
}

class _PoemVerseState extends State<PoemVerse> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bayt = widget.bayt;
    final named = widget.named;
    final explanation = widget.explanation;
    final style = TextStyle(
      fontSize: widget.fontSize,
      height: 1.8,
      color: MushafColors.ink,
      fontWeight: named ? FontWeight.w600 : FontWeight.normal,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: named ? MushafColors.goldLight.withAlpha(90) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    '${bayt.n}',
                    style: TextStyle(color: MushafColors.frame, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        bayt.sadr,
                        textDirection: TextDirection.rtl,
                        style: style,
                      ),
                      Text(
                        bayt.ajz,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.end,
                        style: style,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _expanded
                      ? 'إخفاء شرح البيت ${bayt.n}'
                      : 'شرح البيت ${bayt.n}',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.help_outline,
                    color: MushafColors.green,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(),
            if (widget.bookExplanation.isNotEmpty) ...[
              Text(
                'بيان القراءة في هذا الموضع — التسهيل لقراءات التنزيل',
                style: TextStyle(color: MushafColors.green, fontSize: 12),
              ),
              SelectableText(
                widget.bookExplanation,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
            ],
            if (explanation != null) ...[
              if (explanation.group.length > 1)
                Text(
                  'شرح مشترك للأبيات: ${explanation.group.join('، ')}',
                  style: TextStyle(color: MushafColors.frame, fontSize: 12),
                ),
              SelectableText(
                explanation.text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  height: 1.8,
                  color: MushafColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${explanation.source}\n${explanation.page}',
                style: TextStyle(color: MushafColors.frame, fontSize: 11),
              ),
            ] else if (widget.bookExplanation.isEmpty)
              const Text(
                'لا يتوفر شرح موثق لهذا البيت ضمن المصادر المحملة حاليًا.',
              ),
          ],
        ],
      ),
    );
  }
}
