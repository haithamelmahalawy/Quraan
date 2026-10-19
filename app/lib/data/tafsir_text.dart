/// A tafsir book's HTML as text: line breaks kept, the ayahs it quotes kept
/// in their ﴿ ﴾, every other tag dropped.
String tafsirText(String html) => html
    .replaceAll('\r', '')
    .replaceAll(
      RegExp(r'<br\s*/?>|</p>|</div>|</tr>', caseSensitive: false),
      '\n',
    )
    .replaceAll(RegExp(r'</td>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r' *\n *'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
