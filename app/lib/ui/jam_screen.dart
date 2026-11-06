import 'package:flutter/material.dart';

import '../data/audio_numbering.dart';
import '../data/jam.dart';
import '../data/quran_repository.dart';
import '../data/recitations.dart';
import '../data/variant_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../services/ayah_player.dart';
import '../state/reader_settings.dart';
import 'reading_colors.dart';
import 'theme.dart';

/// «الجمع للقراءات العشر»: each ayah of a page read by the twenty riwayat in
/// their order, each reading once; the riwayat that read it alike are named
/// with it in the hamesh, and the arrows go on to the next reading, then to
/// the next ayah. It reads the settings and changes nothing of the reader.
class JamScreen extends StatefulWidget {
  const JamScreen({
    super.key,
    required this.quran,
    required this.variants,
    required this.page,
    this.settings,
    this.player,
    this.recitations,
  });

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
  late final List<Ayah> _ayahs = widget.quran.page(widget.page);
  late final Future<void> _loading = widget.variants.ensureLoaded([
    for (final id in jamOrder)
      if (widget.variants.isAvailable(id)) id,
  ]);
  late final Future<Recitations> _recitations = widget.recitations != null
      ? Future.value(widget.recitations)
      : Recitations.load();

  int _ayah = 0;
  int _reading = 0;
  final _byAyah = <int, List<JamReading>>{};

  AyahPlayer get _player => widget.player ?? AyahPlayer.instance;

  List<String> get _riwayat => [
    for (final id in jamOrder)
      if (id == hafsId || widget.variants.isAvailable(id)) id,
  ];

  List<JamReading> _readingsOf(int i) =>
      _byAyah[i] ??= jamReadings(_ayahs[i], widget.variants, riwayat: _riwayat);

  bool get _atStart => _ayah == 0 && _reading == 0;
  bool get _atEnd =>
      _ayah == _ayahs.length - 1 && _reading == _readingsOf(_ayah).length - 1;

  void _next() {
    _player.stop();
    setState(() {
      if (_reading < _readingsOf(_ayah).length - 1) {
        _reading++;
      } else if (_ayah < _ayahs.length - 1) {
        _ayah++;
        _reading = 0;
      }
    });
  }

  void _previous() {
    _player.stop();
    setState(() {
      if (_reading > 0) {
        _reading--;
      } else if (_ayah > 0) {
        _ayah--;
        _reading = _readingsOf(_ayah).length - 1;
      }
    });
  }

  void _goToAyah(int i) {
    _player.stop();
    setState(() {
      _ayah = i;
      _reading = 0;
    });
  }

  Future<void> _play(JamReading r) async {
    final ayah = _ayahs[_ayah];
    if (_player.isPlaying(ayah.surah, ayah.number) &&
        _player.current?.reciter.id ==
            _reciterOf(r.lead, await _recitations)?.id &&
        _player.playing) {
      await _player.pause();
      return;
    }
    final reciter = _reciterOf(r.lead, await _recitations);
    if (reciter == null) return;
    await _player.play(
      ayah.surah,
      ayah.number,
      reciter,
      selectionSystem: AudioNumbering.displaySystemFor(hafsId),
    );
  }

  Reciter? _reciterOf(String riwaya, Recitations all) {
    final list = all.of(riwaya);
    if (list.isEmpty) return null;
    final chosen = widget.settings?.reciterFor(riwaya);
    return list.where((r) => r.id == chosen).firstOrNull ?? list.first;
  }

  @override
  void dispose() {
    _player.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: MushafColors.page,
      appBar: AppBar(title: Text('الجمع للقراءات العشر • ص ${widget.page}')),
      body: FutureBuilder(
        future: _loading,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final readings = _readingsOf(_ayah);
          final r = readings[_reading.clamp(0, readings.length - 1)];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ayahStrip(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _header(r, readings.length),
                    const SizedBox(height: 8),
                    _ayahText(r),
                    const SizedBox(height: 12),
                    _hamesh(r),
                  ],
                ),
              ),
              _controls(r),
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
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        for (var i = 0; i < _ayahs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              key: ValueKey('jam-ayah-$i'),
              label: Text(
                '${widget.quran.surah(_ayahs[i].surah).nameAr} ${_ayahs[i].number}',
              ),
              selected: i == _ayah,
              showCheckmark: false,
              onSelected: (_) => _goToAyah(i),
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

  /// The ayah as the reading writes it, its differences from Hafs coloured.
  Widget _ayahText(JamReading r) {
    final ayah = _ayahs[_ayah];
    return Container(
      key: const ValueKey('jam-ayah-text'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MushafColors.goldLight.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MushafColors.gold.withAlpha(150)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            for (var w = 0; w < r.words.length; w++) ...[
              TextSpan(
                text: r.words[w],
                style: TextStyle(
                  color: r.differences[w] == null
                      ? MushafColors.ink
                      : ReadingColors.of(r.differences[w]!.first),
                ),
              ),
              const TextSpan(text: ' '),
            ],
            TextSpan(
              text: '﴿${_arabic(ayah.number)}﴾',
              style: TextStyle(color: MushafColors.frame, fontSize: 22),
            ),
          ],
        ),
        textAlign: TextAlign.justify,
        style: TextStyle(fontFamily: 'Hafs', fontSize: 30, height: 1.9),
      ),
    );
  }

  /// Who read it alike, and how its words differ from Hafs.
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
      ],
    );
  }

  Widget _controls(JamReading r) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            key: const ValueKey('jam-previous'),
            tooltip: 'القراءة السابقة',
            onPressed: _atStart ? null : _previous,
            // Right to left: the previous at the right.
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _player,
              builder: (context, _) {
                final ayah = _ayahs[_ayah];
                final playing =
                    _player.playing &&
                    _player.isPlaying(ayah.surah, ayah.number);
                return Center(
                  child: FilledButton.icon(
                    key: const ValueKey('jam-play'),
                    onPressed: () => _play(r),
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text('استماع برواية ${riwayaById(r.lead).nameAr}'),
                  ),
                );
              },
            ),
          ),
          IconButton.filledTonal(
            key: const ValueKey('jam-next'),
            tooltip: 'القراءة التالية',
            onPressed: _atEnd ? null : _next,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ],
      ),
    ),
  );

  static String _arabic(int n) =>
      n.toString().split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();
}
