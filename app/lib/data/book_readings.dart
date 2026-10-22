/// Source notes can split an identical reading into several reader groups.
/// Keep exact spelling and pronunciation notes: bare-letter comparison would
/// wrongly merge a vowel change or an imala with Hafs.
bool bookReadingAsHafs(List group, Iterable<List> readings) {
  if ((group[1] as List).contains('hafs')) return true;
  if ((group[0] as String).isEmpty) return false;
  bool hasNotes(List g) => g.length > 6 && (g[6] as List).isNotEmpty;
  if (hasNotes(group)) return false;
  return readings.any(
    (hafs) =>
        (hafs[1] as List).contains('hafs') &&
        !hasNotes(hafs) &&
        group[0] == hafs[0] &&
        group[3] == hafs[3] &&
        group[4] == hafs[4] &&
        (group.length > 5 && group[5] == true) ==
            (hafs.length > 5 && hafs[5] == true),
  );
}
