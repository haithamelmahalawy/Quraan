import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/audio_numbering.dart';
import '../data/jam.dart';
import '../data/kharouf.dart';
import '../data/manzumat.dart';
import '../data/mutashabihat_repository.dart';
import '../data/quran_repository.dart';
import '../data/reading_comparison.dart';
import '../data/recitations.dart';
import '../data/usul_guide.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../services/ayah_player.dart';
import '../state/reader_settings.dart';
import 'mushaf_page.dart';
import 'page_slider.dart';
import 'quran_word_text.dart';
import 'reading_colors.dart';
import 'theme.dart';
import 'usul_labels.dart';

/// «الجمع للقراءات العشر»: each ayah of a page read by the twenty riwayat in
/// their order, each reading once; the riwayat that read it alike are named
/// with it in the hamesh with their witnesses, and the arrows go on to the
/// next reading, then to the next ayah. Played, it goes through them all by
/// itself, each reading with its sheikh. It reads the settings and changes
/// nothing of the reader.
class JamScreen extends StatefulWidget {
  const JamScreen({
    super.key,
    required this.quran,
    required this.variants,
    required this.page,
    this.settings,
    this.player,
    this.recitations,
    this.riwayat,
  });

  /// «جمع الروايات المختارة»: these riwayat alone, in the order of the ten;
  /// the twenty when null.
  final Set<String>? riwayat;

  final QuranRepository quran;
  final VariantRepository variants;
  final int page;

  /// For the sheikh chosen for a riwaya; read only.
  final ReaderSettings? settings;
  final AyahPlayer? player;
  final Recitations? recitations;

  @override
  State<JamScreen> createState() => _JamScreenState();
}

class _JamScreenState extends State<JamScreen> {
  /// The page gathered; at its end the next one, from its first ayah.
  late int _page = widget.page;
  late List<Ayah> _ayahs = widget.quran.page(_page);
  late final Future<void> _loading = Future.wait([
    widget.variants.ensureLoaded([
      for (final id in jamOrder)
        if (widget.variants.isAvailable(id)) id,
    ]),
    Manzumat.load().then((m) => _poems = m),
    Kharouf.load().then((k) => _book = k),
  ]);
  late final Future<Recitations> _recitations = widget.recitations != null
      ? Future.value(widget.recitations)
      : Recitations.load();
  Manzumat? _poems;
  Kharouf? _book;

  int _ayah = 0;
  int _reading = 0;
  final _byAyah = <int, List<JamReading>>{};

  /// The riwayat already read in this ayah, ticked on the board.
  final _read = <String>{};

  /// Going through the readings by itself, each heard to its end.
  bool _auto = false;

  /// A reading is being heard, its end awaited to go on.
  bool _awaiting = false;

  late final bool _wasContinuous;

  AyahPlayer get _player => widget.player ?? AyahPlayer.instance;

  @override
  void initState() {
    super.initState();
    // The ayah shown alone, not the ones after it.
    _wasContinuous = _player.continuous;
    _player.continuous = false;
    _player.addListener(_onPlayer);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayer);
    _awaiting = false;
    _player.stop();
    _player.continuous = _wasContinuous;
    super.dispose();
  }

  List<String> get _riwayat => [
    for (final id in jamOrder)
      if ((id == hafsId || widget.variants.isAvailable(id)) &&
          (widget.riwayat?.contains(id) ?? true))
        id,
  ];

  List<JamReading> _readingsOf(int i) =>
      _byAyah[i] ??= jamReadings(_ayahs[i], widget.variants, riwayat: _riwayat);

  JamReading get _current {
    final readings = _readingsOf(_ayah);
    return readings[_reading.clamp(0, readings.length - 1)];
  }

  bool get _atStart => _page == 1 && _ayah == 0 && _reading == 0;
  bool get _atEnd =>
      _page == widget.quran.pageCount &&
      _ayah == _ayahs.length - 1 &&
      _reading == _readingsOf(_ayah).length - 1;

  /// Turns to [page], at its first ayah, or its last reading when [last].
  void _turnTo(int page, {bool last = false}) => setState(() {
    _page = page;
    _ayahs = widget.quran.page(page);
    _byAyah.clear();
    _read.clear();
    _done.clear();
    _ayah = last ? _ayahs.length - 1 : 0;
    _reading = last ? _readingsOf(_ayah).length - 1 : 0;
    _read.addAll(_current.riwayat);
  });

  /// Shows the reading at [ayah], [reading], its riwayat ticked.
  void _show(int ayah, int reading) => setState(() {
    if (ayah != _ayah) {
      if (_read.containsAll(_riwayat)) _done.add(_ayah);
      _read.clear();
    }
    _ayah = ayah;
    _reading = reading;
    _read.addAll(_current.riwayat);
  });

  void _stepForward() {
    if (_reading < _readingsOf(_ayah).length - 1) {
      _show(_ayah, _reading + 1);
    } else if (_ayah < _ayahs.length - 1) {
      _show(_ayah + 1, 0);
    } else if (_page < widget.quran.pageCount) {
      _turnTo(_page + 1);
    }
  }

  void _stepBack() {
    if (_reading > 0) {
      _show(_ayah, _reading - 1);
    } else if (_ayah > 0) {
      _show(_ayah - 1, _readingsOf(_ayah - 1).length - 1);
    } else if (_page > 1) {
      _turnTo(_page - 1, last: true);
    }
  }

  /// By hand: the playing stops, the reading moves.
  void _manual(VoidCallback move) {
    _stopAuto();
    move();
  }

  void _stopAuto() {
    _auto = false;
    _awaiting = false;
    _player.stop();
  }

  /// Plays the reading shown; when it ends, [_onPlayer] goes on.
  Future<void> _playCurrent() async {
    final ayah = _ayahs[_ayah];
    final reciter = _reciterOf(_current.lead, await _recitations);
    if (!mounted) return;
    if (reciter == null) {
      // No sheikh for it: on to the next reading.
      if (_auto) scheduleMicrotask(_afterReading);
      return;
    }
    _awaiting = true;
    await _player.play(
      ayah.surah,
      ayah.number,
      reciter,
      selectionSystem: AudioNumbering.displaySystemFor(hafsId),
    );
  }

  void _onPlayer() {
    if (!_awaiting || _player.current != null) return;
    // The reading heard to its end.
    _awaiting = false;
    if (_auto) _afterReading();
    if (mounted) setState(() {});
  }

  void _afterReading() {
    if (!mounted || !_auto) return;
    if (_atEnd) {
      setState(() => _auto = false);
      return;
    }
    _stepForward();
    _playCurrent();
  }

  void _toggleAuto() {
    if (_auto) {
      setState(_stopAuto);
      return;
    }
    setState(() => _auto = true);
    _playCurrent();
  }

  Reciter? _reciterOf(String riwaya, Recitations all) {
    final list = all.of(riwaya);
    if (list.isEmpty) return null;
    final chosen = widget.settings?.reciterFor(riwaya);
    return list.where((r) => r.id == chosen).firstOrNull ?? list.first;
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: MushafColors.page,
      appBar: AppBar(
        title: Text(
          '${widget.riwayat == null ? 'الجمع للقراءات العشر' : 'جمع الروايات المختارة'}'
          ' • ص $_page',
        ),
      ),
      body: FutureBuilder(
        future: _loading,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_read.isEmpty) _read.addAll(_current.riwayat);
          final readings = _readingsOf(_ayah);
          final r = _current;
          // Turned on its side: the page beside the reading, not under it.
          final size = MediaQuery.sizeOf(context);
          if (size.width > size.height) return _landscape(r, readings);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ayahStrip(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The board and the ayah; below them the hamesh beside
                      // the small page, down to the player.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: box.maxHeight * .62,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _board(r, readings),
                              const SizedBox(height: 10),
                              _header(r, readings.length),
                              const SizedBox(height: 8),
                              // Whole: made smaller as much as it needs to fit.
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: math.max(
                                    80.0,
                                    box.maxHeight * .42 - 60,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: box.maxWidth - 24,
                                    child: _ayahText(r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                          child: LayoutBuilder(
                            builder: (context, row) => Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: _hamesh(r),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: math.min(
                                    row.maxHeight * _pageSize.aspectRatio,
                                    row.maxWidth * .45,
                                  ),
                                  child: _smallPage(r),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Any page of the mushaf, from its first ayah.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PageSlider(
                  key: const ValueKey('jam-page-slider'),
                  quran: widget.quran,
                  page: _page,
                  onGo: (page) {
                    if (page != _page) _manual(() => _turnTo(page));
                  },
                ),
              ),
              _controls(),
            ],
          );
        },
      ),
    ),
  );

  /// The riwayat on their board, in one row, its names read at their size,
  /// drawn aside to the qari read.
  Widget _board(JamReading r, List<JamReading> readings) => SizedBox(
    height: _QurraBoard.height,
    child: _QurraBoard(
      shown: _riwayat.toSet(),
      read: _read,
      current: r.riwayat.toSet(),
      onTap: (id) => _manual(() {
        final i = readings.indexWhere((x) => x.riwayat.contains(id));
        if (i >= 0) _show(_ayah, i);
      }),
    ),
  );

  /// The phone on its side: the reading (the board, the ayah, its hamesh)
  /// scrolled on one side, the page large on the other, scrolled down its
  /// length.
  Widget _landscape(JamReading r, List<JamReading> readings) => LayoutBuilder(
    builder: (context, box) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ayahStrip(),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('jam-landscape-reading'),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _board(r, readings),
                      const SizedBox(height: 10),
                      _header(r, readings.length),
                      const SizedBox(height: 8),
                      _ayahText(r),
                      const SizedBox(height: 10),
                      _hamesh(r),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PageSlider(
                  key: const ValueKey('jam-page-slider'),
                  quran: widget.quran,
                  page: _page,
                  onGo: (page) {
                    if (page != _page) _manual(() => _turnTo(page));
                  },
                ),
              ),
              _controls(),
            ],
          ),
        ),
        SizedBox(
          width: box.maxWidth * .42,
          child: SafeArea(
            left: false,
            child: SingleChildScrollView(
              key: const ValueKey('jam-landscape-page'),
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: AspectRatio(
                aspectRatio: _pageSize.aspectRatio,
                child: _smallPage(r),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// The page drawn at this size, then made small.
  static const _pageSize = Size(400, 660);

  /// The page's settings for each riwaya read: it is drawn as it reads.
  final _shownAs = <String, ReaderSettings>{};

  /// The ayahs of the page whose readings were all gone through.
  final _done = <int>{};

  /// The mushaf page as the riwaya read writes it, the ayah read shaded, and
  /// those gone through more lightly.
  Widget _smallPage(JamReading r) {
    final riwaya = r.riwayat.contains(hafsId) ? null : r.lead;
    final settings = _shownAs[r.lead] ??= ReaderSettings.showing(riwaya);
    final shown = {for (final (i, a) in _ayahs.indexed) (a.surah, a.number): i};
    // Swiped across, as the mushaf turns: to the right the next page, to the
    // left the one before, each from its first ayah.
    return GestureDetector(
      key: const ValueKey('jam-page-swipe'),
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < _swipeSpeed) return;
        final page = v > 0 ? _page + 1 : _page - 1;
        if (page < 1 || page > widget.quran.pageCount) return;
        _manual(() => _turnTo(page));
      },
      child: Container(
        key: const ValueKey('jam-page'),
        decoration: BoxDecoration(
          color: MushafColors.page,
          border: Border.all(color: MushafColors.gold.withAlpha(150)),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(
          alignment: Alignment.topCenter,
          child: SizedBox.fromSize(
            size: _pageSize,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(size: _pageSize, textScaler: TextScaler.noScaling),
              // An ayah touched: the jam' from it.
              child: MushafPage(
                key: ValueKey('jam-page-$_page-${r.lead}'),
                page: _page,
                quran: widget.quran,
                variants: widget.variants,
                mutashabihat: MutashabihatRepository.empty,
                settings: settings,
                onWordTap: (a, _) {
                  final i = shown[(a.surah, a.number)];
                  if (i != null) _manual(() => _show(i, 0));
                },
                showHamesh: false,
                ayahShade: (a) => switch (shown[(a.surah, a.number)]) {
                  final i? when i == _ayah => MushafColors.gold.withAlpha(110),
                  final i? when _done.contains(i) =>
                    MushafColors.green.withAlpha(40),
                  _ => null,
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How fast a swipe across the small page must go to turn it.
  static const _swipeSpeed = 200.0;

  /// [ayah]'s number as the riwaya read counts it (يونس: الشامي، المدني...):
  /// the number of the verse its first word is in.
  int _numberOf(Ayah ayah) {
    final system = AudioNumbering.displaySystemFor(_current.lead);
    if (system == 'kufi') return ayah.number;
    try {
      return widget.quran.numbering?.verseAt(
            system,
            ayah.surah,
            ayah.number,
            0,
          ) ??
          ayah.number;
    } on RangeError {
      return ayah.number;
    }
  }

  /// The ayahs of the page, the one read marked.
  Widget _ayahStrip() => SizedBox(
    height: 44,
    child: ListView(
      key: ValueKey('jam-strip-$_page'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        for (var i = 0; i < _ayahs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              key: ValueKey('jam-ayah-$i'),
              label: Text(
                '${widget.quran.surah(_ayahs[i].surah).nameAr} '
                '${_numberOf(_ayahs[i]) == 0 ? 'البسملة' : _numberOf(_ayahs[i])}',
              ),
              selected: i == _ayah,
              showCheckmark: false,
              onSelected: (_) => _manual(() => _show(i, 0)),
            ),
          ),
      ],
    ),
  );

  Widget _header(JamReading r, int count) {
    final q = qiraaOf(r.lead);
    return Row(
      children: [
        Expanded(
          child: Text(
            jamName(r.lead),
            key: const ValueKey('jam-lead'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: r.lead == hafsId ? MushafColors.green : q.color,
            ),
          ),
        ),
        Text(
          'القراءة ${_reading + 1} من $count',
          style: TextStyle(color: MushafColors.frame, fontSize: 13),
        ),
      ],
    );
  }

  /// The ayah as the reading writes it, drawn as the page draws its words
  /// (the font's marks set right), its differences from Hafs coloured.
  Widget _ayahText(JamReading r) {
    final ayah = _ayahs[_ayah];
    final numbers = _citations(r).numbers;
    // Smaller as the ayah is longer, so it is seen whole.
    final words = r.words.where((w) => w.isNotEmpty).length;
    final size = words <= 12
        ? 28.0
        : words <= 30
        ? 24.0
        : words <= 60
        ? 20.0
        : 16.0;
    return Container(
      key: const ValueKey('jam-ayah-text'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MushafColors.goldLight.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MushafColors.gold.withAlpha(150)),
      ),
      child: Wrap(
        textDirection: TextDirection.rtl,
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var w = 0; w < r.words.length; w++)
            if (r.words[w].isNotEmpty)
              _numbered(
                numbers[w],
                QuranWordText(
                  r.words[w],
                  key: ValueKey('jam-word-$w'),
                  style: TextStyle(
                    fontFamily: 'Hafs',
                    fontSize: size,
                    height: 1.9,
                    color: r.differences[w] == null
                        ? MushafColors.ink
                        : ReadingColors.of(r.differences[w]!.first),
                  ),
                ),
              ),
          Text(
            '﴿${_arabic(_numberOf(ayah))}﴾',
            style: TextStyle(
              fontFamily: 'Hafs',
              color: MushafColors.frame,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// [word] with its number over it, the number its witnesses are given by.
  Widget _numbered(int? n, Widget word) => n == null
      ? word
      : Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            word,
            Positioned(
              top: -2,
              child: Text(
                '(${_arabic(n)})',
                key: ValueKey('jam-number-$n'),
                style: TextStyle(
                  color: MushafColors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1,
                ),
              ),
            ),
          ],
        );

  /// The numbers of [words], as given before a witness: «(١، ٣) ».
  String _numbersOf(Iterable<int> words, Map<int, int> numbers) {
    final ns = [for (final w in words) ?numbers[w]]..sort();
    return ns.isEmpty ? '' : '(${ns.map(_arabic).join('، ')}) ';
  }

  /// Who read it alike, how its words differ from Hafs, and the witnesses.
  Widget _hamesh(JamReading r) {
    final style = TextStyle(color: MushafColors.ink, fontSize: 14, height: 1.6);
    return Column(
      key: const ValueKey('jam-hamesh'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'يوافقه: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: r.agreeing.isEmpty
                    ? 'لا أحد من الرواة'
                    : r.agreeing.map(jamName).join('، '),
              ),
            ],
          ),
          key: const ValueKey('jam-agreeing'),
          style: style,
        ),
        const SizedBox(height: 8),
        if (r.differences.isEmpty)
          Text('يقرأ الآية كحفص.', style: style)
        else ...[
          ..._farshOf(r, style),
          ..._usulOf(r, style),
        ],
        ..._witnesses(r),
      ],
    );
  }

  /// A word of the ayah and how [rows] read it: «(١) الكلمة: وصفها».
  Widget _told(int w, List<Variant> rows, JamReading r, TextStyle style) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _numbersOf([w], _citations(r).numbers),
                style: TextStyle(
                  color: MushafColors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: _ayahs[_ayah].words[w],
                style: const TextStyle(fontFamily: 'Hafs', fontSize: 18),
              ),
              const TextSpan(text: ': '),
              TextSpan(
                text: {
                  for (final v in rows)
                    if (v.shownDescription.isNotEmpty) v.shownDescription,
                }.join('؛ '),
              ),
            ],
          ),
          style: style,
        ),
      );

  /// A section's title in the hamesh: «الفرش»، «الأصول».
  Widget _section(String title, Key key) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: Text(
      title,
      style: TextStyle(
        color: MushafColors.green,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    ),
  );

  /// A row told in the farsh, as the mushaf tells it beside the page.
  static bool _isFarsh(Variant v) => v.inHamesh || !v.isUsul;

  /// The reading's farsh, word by word.
  List<Widget> _farshOf(JamReading r, TextStyle style) {
    final farsh = {
      for (final MapEntry(key: w, value: rows) in r.differences.entries)
        if (rows.any(_isFarsh)) w: rows.where(_isFarsh).toList(),
    };
    if (farsh.isEmpty) return const [];
    return [
      _section('الفرش', const ValueKey('jam-farsh')),
      for (final MapEntry(key: w, value: rows) in farsh.entries)
        _told(w, rows, r, style),
    ];
  }

  /// The chapters of the usul [v] is told under, as in the mushaf's key.
  static List<(String, Color)> _chaptersOf(Variant v) => [
    for (final (label, color) in usulKindsOf(v)) (usulGuideLabel(label), color),
  ];

  /// The reading's usul by their chapters, as in the mushaf; under each, shut
  /// until opened, how every riwaya of the jam' reads that asl in this ayah.
  List<Widget> _usulOf(JamReading r, TextStyle style) {
    final chapters = <String, ({Color color, Map<int, List<Variant>> words})>{};
    for (final MapEntry(key: w, value: rows) in r.differences.entries) {
      for (final v in rows) {
        if (_isFarsh(v)) continue;
        for (final (chapter, color) in _chaptersOf(v)) {
          final c = chapters[chapter] ??= (color: color, words: {});
          (c.words[w] ??= []).add(v);
        }
      }
    }
    if (chapters.isEmpty) return const [];
    return [
      _section('الأصول', const ValueKey('jam-usul')),
      for (final MapEntry(key: chapter, value: c) in chapters.entries)
        Container(
          key: ValueKey('jam-asl-$chapter'),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          decoration: BoxDecoration(
            color: MushafColors.page,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.color.withAlpha(140)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                chapter,
                style: TextStyle(
                  color: c.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              for (final MapEntry(key: w, value: rows) in c.words.entries)
                _told(w, rows, r, style),
              _manhaj(chapter, c.words.keys.toList(), r),
            ],
          ),
        ),
    ];
  }

  /// The rows of [chapter] at the word [w] of the ayah shown, of [ids].
  Iterable<Variant> _rowsOf(List<String> ids, String chapter, int w) {
    final ayah = _ayahs[_ayah];
    return widget.variants
        .at(ids, ayah.surah, ayah.number, w)
        .where(
          (v) =>
              v.word == w &&
              !v.stopOnly &&
              !_isFarsh(v) &&
              _chaptersOf(v).any((k) => k.$1 == chapter),
        );
  }

  /// How [id] reads [chapter] at [words] of the ayah shown: its faces, or
  /// Hafs's own way in that asl (التحقيق، الفتح...) where it reads as he does.
  String _faceOf(String id, String chapter, List<int> words) {
    final hows = <int, String>{};
    for (final w in words) {
      final faces = id == hafsId
          ? const <String>{}
          : {
              for (final v in _rowsOf([id], chapter, w))
                v.shownDescription.isEmpty ? v.text : v.shownDescription,
            };
      final how = faces.isEmpty ? _hafsWayAt(chapter, w) : faces.join('؛ ');
      hows[w] = how;
    }
    // Each way told once, without the words it is at: Warsh's silah before a
    // hamza and his mim quiet elsewhere, not word by word.
    return hows.values.toSet().join('\n');
  }

  /// The table's cell kept small where an asl comes at many words of the
  /// ayah (صلة ميم الجمع): the first four, then «...».
  static String _firstFour(Iterable<String> items, String separator) {
    final all = items.toList();
    return all.length <= 4
        ? all.join(separator)
        : '${all.take(4).join(separator)}$separator...';
  }

  /// Hafs's way in [chapter] at the word [w], by what the others read there.
  String _hafsWayAt(String chapter, int w) {
    final v = _rowsOf(_riwayat, chapter, w).firstOrNull;
    if (v == null) return 'على الأصل';
    final label = [
      for (final (l, _) in usulKindsOf(v))
        if (usulGuideLabel(l) == chapter) l,
    ].firstOrNull;
    return hafsWayIn(chapter, label ?? chapter, v, _ayahs[_ayah].words[w]) ??
        'على الأصل';
  }

  /// [words] of the ayah shown as [id] writes them, each once.
  Set<String> _wordList(String id, List<int> words) {
    final ayah = _ayahs[_ayah];
    return {
      for (final w in words)
        readingText(
          widget.variants,
          id,
          ayah,
          w,
          w + 1,
        ).replaceAll(RegExp('[ۖ-ۜ]'), ''),
    }.where((w) => w.isNotEmpty).toSet();
  }

  /// The riwayat of the jam' by how they read [chapter] at [words] and write
  /// them: those alike in one group, in the order of the first of each.
  Map<(String, String), List<String>> _groupsOf(
    String chapter,
    List<int> words,
  ) {
    // By the way alone: a word written otherwise for another asl (عَلَيۡهُمۡ)
    // is the same way in this one; its writings told side by side.
    final byFace = <String, List<String>>{};
    for (final id in _riwayat) {
      (byFace[_faceOf(id, chapter, words)] ??= []).add(id);
    }
    return {
      for (final MapEntry(key: face, value: ids) in byFace.entries)
        // A word to a line, the first four, then «...».
        (
          face,
          _firstFour({for (final id in ids) ..._wordList(id, words)}, '\n'),
        ): ids,
    };
  }

  /// [ids] named as the hamesh names them: a qari whose riwayat of the jam'
  /// are all among them by his name alone (عاصم for Hafs and Shu'bah), the
  /// others by their riwaya; each with the riwayat it stands for.
  List<(String, List<String>)> _namesOf(List<String> ids) {
    final named = <(String, List<String>)>[];
    final done = <String>{};
    for (final id in ids) {
      if (!done.add(id)) continue;
      final q = qiraaOf(id);
      final his = [
        for (final r in q.riwayat)
          if (_riwayat.contains(r.id)) r.id,
      ];
      if (his.length > 1 && his.every(ids.contains)) {
        done.addAll(his);
        named.add((q.shortAr, his));
      } else {
        named.add((jamName(id), [id]));
      }
    }
    return named;
  }

  /// «منهج الرواة في هذا الأصل»: shut, and opened a table of each riwaya of
  /// the jam' and how it reads [chapter] at [words] of the ayah; the riwayat
  /// of the reading shown marked.
  Widget _manhaj(String chapter, List<int> words, JamReading r) {
    const cell = EdgeInsets.symmetric(horizontal: 6, vertical: 4);
    final head = TextStyle(
      color: MushafColors.green,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
    // Its own surface, for its touch to be seen over the asl's box.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        // No lines of the tile's own above and below it.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('jam-manhaj-$_page-$_ayah-$chapter'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 6),
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            'منهج الرواة في هذا الأصل',
            style: TextStyle(color: MushafColors.frame, fontSize: 13),
          ),
          children: [
            Table(
              key: ValueKey('jam-manhaj-table-$chapter'),
              border: TableBorder.all(
                color: MushafColors.gold.withAlpha(200),
                width: .8,
              ),
              columnWidths: const {
                // The names together wrap within their share.
                0: FlexColumnWidth(7),
                1: IntrinsicColumnWidth(),
                2: FlexColumnWidth(6),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: MushafColors.goldLight.withAlpha(60),
                  ),
                  children: [
                    Padding(
                      padding: cell,
                      child: Text('الراوي', style: head),
                    ),
                    Padding(
                      padding: cell,
                      child: Text('الكلمة', style: head),
                    ),
                    Padding(
                      padding: cell,
                      child: Text('منهجه', style: head),
                    ),
                  ],
                ),
                // Those who read it alike told together, the way once.
                for (final MapEntry(key: (face, word), value: ids) in _groupsOf(
                  chapter,
                  words,
                ).entries)
                  TableRow(
                    decoration: ids.any(r.riwayat.contains)
                        ? BoxDecoration(color: MushafColors.gold.withAlpha(45))
                        : null,
                    children: [
                      Padding(
                        padding: cell,
                        child: Text.rich(
                          key: ValueKey(
                            'jam-manhaj-names-$chapter-${ids.join(',')}',
                          ),
                          TextSpan(
                            children: [
                              for (final (i, (name, of)) in _namesOf(
                                ids,
                              ).indexed) ...[
                                if (i > 0) const TextSpan(text: ' و'),
                                TextSpan(
                                  text: name,
                                  style: TextStyle(
                                    color: of.length == 1 && of[0] == hafsId
                                        ? MushafColors.green
                                        : qiraaOf(of[0]).color,
                                    fontWeight: of.any(r.riwayat.contains)
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          style: TextStyle(
                            color: MushafColors.ink,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Padding(
                        padding: cell,
                        // Each writing on its line.
                        child: Column(
                          key: ValueKey(
                            'jam-manhaj-word-$chapter-${ids.join(',')}',
                          ),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final line in word.split('\n'))
                              // «...» after the first four: the Quran's font
                              // has no dots, so in the page's own.
                              line == '...'
                                  ? Text(
                                      '...',
                                      key: const ValueKey('jam-manhaj-more'),
                                      style: TextStyle(
                                        color: MushafColors.ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : QuranWordText(
                                      line,
                                      style: TextStyle(
                                        fontFamily: 'Hafs',
                                        color: MushafColors.ink,
                                        fontSize: 17,
                                        height: 1.7,
                                      ),
                                    ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: cell,
                        child: Text(
                          face,
                          key: ValueKey(
                            'jam-manhaj-face-$chapter-${ids.join(',')}',
                          ),
                          style: TextStyle(
                            color: MushafColors.ink,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The witnesses of the reading from the Shatibiyya and the Durrah: of the
  /// one it is read with and of those who read it alike, named together
  /// where they share them.
  final _cited = <String, _Citations>{};

  /// The reading's witnesses: each riwaya's bayts with the words they are for,
  /// those who share them named together, and the words that have one
  /// numbered in their order.
  _Citations _citations(JamReading r) {
    final ayah = _ayahs[_ayah];
    final key =
        '$_page:${ayah.surah}:${ayah.number}:${r.lead}:${r.riwayat.join(',')}';
    final kept = _cited[key];
    if (kept != null) return kept;
    final poems = _poems, book = _book;
    if (poems == null || book == null || r.differences.isEmpty) {
      return (numbers: const <int, int>{}, groups: const []);
    }
    final names = [for (final s in widget.quran.surahs) s.nameAr];
    final byRiwaya = <String, List<_Cited>>{};
    for (final id in r.riwayat) {
      if (id == hafsId) continue;
      final bayts = <String, _Cited>{};
      for (final w in r.differences.keys) {
        for (final v in widget.variants.at([id], ayah.surah, ayah.number, w)) {
          if (v.word != w || v.stopOnly) continue;
          final ref = poems.referenceOf(
            v,
            ayah.words[w],
            ayah.surah,
            names,
            entries: book.at(ayah.surah, ayah.number, w),
          );
          // The Durrah's asl first, where it is silent on Abu Ja'far.
          for (final b in ref.asl) {
            (bayts['${Poem.durrah.name}:${b.n}'] ??= (
              poem: Poem.durrah,
              bayt: b,
              words: <int>{},
            )).words.add(w);
          }
          for (final b in ref.verses) {
            if (!ref.mention.contains(b.n)) continue;
            (bayts['${ref.poem.name}:${b.n}'] ??= (
              poem: ref.poem,
              bayt: b,
              words: <int>{},
            )).words.add(w);
          }
        }
      }
      if (bayts.isNotEmpty) byRiwaya[id] = bayts.values.toList();
    }
    final cited = {
      for (final bayts in byRiwaya.values)
        for (final b in bayts) ...b.words,
    }.toList()..sort();
    // The riwayat that share the same bayts, named together.
    final groups = <String, (List<String>, List<_Cited>)>{};
    for (final MapEntry(key: id, value: bayts) in byRiwaya.entries) {
      final same = bayts
          .map((b) => '${b.poem.name}:${b.bayt.n}:${b.words.join('.')}')
          .join(',');
      (groups[same] ??= (<String>[], bayts)).$1.add(id);
    }
    return _cited[key] = (
      numbers: {for (final (i, w) in cited.indexed) w: i + 1},
      groups: groups.values.toList(),
    );
  }

  /// The witnesses of the reading from the Shatibiyya and the Durrah: of the
  /// one it is read with and of those who read it alike, named together
  /// where they share them, each after the numbers of its words.
  List<Widget> _witnesses(JamReading r) {
    final (:numbers, :groups) = _citations(r);
    if (groups.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Text(
        'الأدلة',
        style: TextStyle(
          color: MushafColors.green,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      for (final (ids, bayts) in groups)
        Container(
          key: ValueKey('jam-witness-${ids.first}'),
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MushafColors.page,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MushafColors.gold.withAlpha(120)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ids.map(jamName).join('، '),
                style: TextStyle(
                  color: qiraaOf(ids.first).color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              for (final (:poem, bayt: b, :words) in bayts)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _numbersOf(words, numbers),
                          style: TextStyle(
                            color: MushafColors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${poem.nameAr} (${_arabic(b.n)}): '
                              '${b.sadr} ... ${b.ajz}',
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: MushafColors.ink,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _controls() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          // Right to left: the previous at the right, pointing out to it.
          IconButton.filledTonal(
            key: const ValueKey('jam-previous'),
            tooltip: 'القراءة السابقة',
            onPressed: _atStart ? null : () => _manual(_stepBack),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _player,
              builder: (context, _) => Center(
                child: FilledButton.icon(
                  key: const ValueKey('jam-play'),
                  onPressed: _toggleAuto,
                  icon: Icon(
                    _auto ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _auto
                        ? 'إيقاف • ${riwayaById(_current.lead).nameAr}'
                        : 'استماع الأوجه كلها',
                  ),
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            key: const ValueKey('jam-next'),
            tooltip: 'القراءة التالية',
            onPressed: _atEnd ? null : () => _manual(_stepForward),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          // Back to the mushaf, at the page read here.
          IconButton(
            key: const ValueKey('jam-to-mushaf'),
            tooltip: 'الانتقال إلى المصحف',
            onPressed: () => Navigator.of(context).pop(_page),
            icon: const Icon(Icons.menu_book_rounded),
          ),
        ],
      ),
    ),
  );

  static String _arabic(int n) =>
      n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();
}

/// The twenty, by their qurra, on a board set in depth: each riwaya with its
/// check box, ticked once its reading of the ayah is shown; the reading shown
/// raised. Tapped, a riwaya shows its reading.
class _QurraBoard extends StatefulWidget {
  const _QurraBoard({
    required this.shown,
    required this.read,
    required this.current,
    required this.onTap,
  });

  /// How tall the board stands: two rows of five, each a qari's name over
  /// his two riwayat.
  static const height = 176.0;

  /// The riwayat of the jam': the others are left off the board.
  final Set<String> shown;
  final Set<String> read;
  final Set<String> current;
  final ValueChanged<String> onTap;

  @override
  State<_QurraBoard> createState() => _QurraBoardState();
}

class _QurraBoardState extends State<_QurraBoard> {
  /// The qurra of the jam', in their order: five to a row.
  List<List<Qiraa>> get _rows {
    final shown = [
      for (final q in qiraat)
        if (q.riwayat.any((r) => widget.shown.contains(r.id))) q,
    ];
    return [
      for (var i = 0; i < shown.length; i += 5)
        shown.sublist(i, math.min(i + 5, shown.length)),
    ];
  }

  @override
  Widget build(BuildContext context) => Transform(
    key: const ValueKey('jam-board'),
    alignment: Alignment.bottomCenter,
    // Leaning back a little, as a board on a table.
    transform: Matrix4.identity()
      ..setEntry(3, 2, .0011)
      ..rotateX(-.12),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MushafColors.goldLight.withAlpha(90),
            MushafColors.gold.withAlpha(70),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      // All in sight, across the whole width: five and five.
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            for (final row in _rows)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: i < row.length
                            ? Padding(
                                padding: const EdgeInsets.all(2),
                                child: _qari(row[i]),
                              )
                            : const SizedBox(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _qari(Qiraa q) => Container(
    key: ValueKey('jam-qari-${q.id}'),
    padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
    decoration: BoxDecoration(
      color: MushafColors.page,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: q.color.withAlpha(
          q.riwayat.any((r) => widget.current.contains(r.id)) ? 255 : 170,
        ),
        width: q.riwayat.any((r) => widget.current.contains(r.id)) ? 2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: q.color.withAlpha(60),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Made smaller, never cut, where the card is narrow.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            q.shortAr,
            maxLines: 1,
            style: TextStyle(
              color: q.color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        for (final r in q.riwayat)
          if (widget.shown.contains(r.id)) _riwaya(r.id, q.color),
      ],
    ),
  );

  Widget _riwaya(String id, Color color) {
    final now = widget.current.contains(id);
    return InkWell(
      key: ValueKey('jam-board-$id'),
      onTap: () => widget.onTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: now ? color.withAlpha(40) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: Checkbox(
                key: ValueKey('jam-check-$id'),
                value: widget.read.contains(id),
                onChanged: (_) => widget.onTap(id),
                activeColor: color,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  riwayaById(id).nameAr,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: now ? FontWeight.bold : FontWeight.normal,
                    color: MushafColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bayt of a witness, with the words of the ayah it is for.
typedef _Cited = ({Poem poem, Bayt bayt, Set<int> words});

/// A reading's witnesses: the words numbered, the bayts by who shares them.
typedef _Citations = ({
  Map<int, int> numbers,
  List<(List<String>, List<_Cited>)> groups,
});
