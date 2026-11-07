import 'dart:async';

import 'package:flutter/material.dart';

import '../data/audio_numbering.dart';
import '../data/jam.dart';
import '../data/kharouf.dart';
import '../data/manzumat.dart';
import '../data/quran_repository.dart';
import '../data/recitations.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../services/ayah_player.dart';
import '../state/reader_settings.dart';
import 'quran_word_text.dart';
import 'reading_colors.dart';
import 'theme.dart';

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
    _ayah = last ? _ayahs.length - 1 : 0;
    _reading = last ? _readingsOf(_ayah).length - 1 : 0;
    _read.addAll(_current.riwayat);
  });

  /// Shows the reading at [ayah], [reading], its riwayat ticked.
  void _show(int ayah, int reading) => setState(() {
    if (ayah != _ayah) _read.clear();
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ayahStrip(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  children: [
                    _QurraBoard(
                      shown: _riwayat.toSet(),
                      read: _read,
                      current: r.riwayat.toSet(),
                      onTap: (id) => _manual(() {
                        final i = readings.indexWhere(
                          (x) => x.riwayat.contains(id),
                        );
                        if (i >= 0) _show(_ayah, i);
                      }),
                    ),
                    const SizedBox(height: 10),
                    _header(r, readings.length),
                    const SizedBox(height: 8),
                    _ayahText(r),
                    const SizedBox(height: 12),
                    _hamesh(r),
                  ],
                ),
              ),
              _controls(),
            ],
          );
        },
      ),
    ),
  );

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
                '${_ayahs[i].number}',
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
    const size = 30.0;
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
          Text(
            '﴿${_arabic(ayah.number)}﴾',
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

  /// Who read it alike, how its words differ from Hafs, and the witnesses.
  Widget _hamesh(JamReading r) {
    final ayah = _ayahs[_ayah];
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
        else
          for (final MapEntry(key: w, value: rows) in r.differences.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: ayah.words[w],
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
            ),
        ..._witnesses(r),
      ],
    );
  }

  /// The witnesses of the reading from the Shatibiyya and the Durrah: of the
  /// one it is read with and of those who read it alike, named together
  /// where they share them.
  List<Widget> _witnesses(JamReading r) {
    final poems = _poems, book = _book;
    if (poems == null || book == null || r.differences.isEmpty) return const [];
    final ayah = _ayahs[_ayah];
    final names = [for (final s in widget.quran.surahs) s.nameAr];
    // Each riwaya's bayts, by the words the reading differs in.
    final byRiwaya = <String, List<(Poem, Bayt)>>{};
    for (final id in r.riwayat) {
      if (id == hafsId) continue;
      final bayts = <(Poem, Bayt)>[];
      final seen = <String>{};
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
          for (final b in ref.verses) {
            if (ref.mention.contains(b.n) &&
                seen.add('${ref.poem.name}:${b.n}')) {
              bayts.add((ref.poem, b));
            }
          }
        }
      }
      if (bayts.isNotEmpty) byRiwaya[id] = bayts;
    }
    if (byRiwaya.isEmpty) return const [];
    // The riwayat that share the same bayts, named together.
    final groups = <String, (List<String>, List<(Poem, Bayt)>)>{};
    for (final MapEntry(key: id, value: bayts) in byRiwaya.entries) {
      final key = bayts.map((b) => '${b.$1.name}:${b.$2.n}').join(',');
      (groups[key] ??= (<String>[], bayts)).$1.add(id);
    }
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
      for (final (ids, bayts) in groups.values)
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
              for (final (poem, b) in bayts)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${poem.nameAr} (${_arabic(b.n)}): ${b.sadr} ... ${b.ajz}',
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
class _QurraBoard extends StatelessWidget {
  const _QurraBoard({
    required this.shown,
    required this.read,
    required this.current,
    required this.onTap,
  });

  /// The riwayat of the jam': the others are left off the board.
  final Set<String> shown;
  final Set<String> read;
  final Set<String> current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Transform(
    key: const ValueKey('jam-board'),
    alignment: Alignment.bottomCenter,
    // Leaning back a little, as a board on a table.
    transform: Matrix4.identity()
      ..setEntry(3, 2, .0011)
      ..rotateX(-.28),
    child: Container(
      padding: const EdgeInsets.all(6),
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
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final q in qiraat)
            if (q.riwayat.any((r) => shown.contains(r.id))) _qari(q),
        ],
      ),
    ),
  );

  Widget _qari(Qiraa q) => Container(
    width: 104,
    padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
    decoration: BoxDecoration(
      color: MushafColors.page,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: q.color.withAlpha(170)),
      boxShadow: [
        BoxShadow(
          color: q.color.withAlpha(60),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          q.shortAr,
          style: TextStyle(
            color: q.color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        for (final r in q.riwayat)
          if (shown.contains(r.id)) _riwaya(r.id, q.color),
      ],
    ),
  );

  Widget _riwaya(String id, Color color) {
    final now = current.contains(id);
    return InkWell(
      key: ValueKey('jam-board-$id'),
      onTap: () => onTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        transform: now
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: now ? color.withAlpha(40) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 22,
              child: Checkbox(
                key: ValueKey('jam-check-$id'),
                value: read.contains(id),
                onChanged: (_) => onTap(id),
                activeColor: color,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Flexible(
              child: Text(
                riwayaById(id).nameAr,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: now ? FontWeight.bold : FontWeight.normal,
                  color: MushafColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
