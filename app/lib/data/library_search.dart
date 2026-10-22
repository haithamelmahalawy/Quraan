/// Search Arabic prose and verse numbers without requiring diacritics or
/// a particular keyboard's alef, ya, or digit forms.
String librarySearchText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
      final code = m[0]!.codeUnitAt(0);
      return '${code - (code >= 0x06f0 ? 0x06f0 : 0x0660)}';
    });

bool librarySearchMatches(String query, String normalizedText) =>
    librarySearchText(query)
        .trim()
        .split(RegExp(r'\s+'))
        .every(normalizedText.contains);
