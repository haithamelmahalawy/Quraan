import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/audio_numbering.dart';
import '../data/reading_comparison.dart';
import '../data/variant_repository.dart';
import '../data/recitations.dart';
import '../data/tafsir_repository.dart';
import '../models/qiraat_catalog.dart';
import '../models/quran.dart';
import '../services/ayah_player.dart';
import '../state/reader_settings.dart';
import 'raised.dart';
import 'recitation_player.dart';
import 'theme.dart';

/// An ayah: listen to it in a riwaya, by a sheikh of that riwaya, and read
/// its tafsir in several books.
class AyahSheet extends StatefulWidget {
  const AyahSheet({
    super.key,
    required this.ayah,
    required this.quran,
    required this.settings,
    this.word = 0,
    this.variants,
    this.player,
    this.recitations,
  });

  final Ayah ayah;
  final QuranRepository quran;
  final ReaderSettings settings;
  final int word;
  final VariantRepository? variants;
  final AyahPlayer? player;
  final Recitations? recitations;

  static final _recitations = Recitations.load();
  static final _tafsir = TafsirRepository();

  static Future<void> show(
    BuildContext context, {
    required Ayah ayah,
    required QuranRepository quran,
    required ReaderSettings settings,
    int word = 0,
    VariantRepository? variants,
    AyahPlayer? player,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MushafColors.paper,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => PrimaryScrollController(
        controller: controller,
        child: AyahSheet(
          ayah: ayah,
          quran: quran,
          settings: settings,
          word: word,
          variants: variants,
          player: player,
        ),
      ),
    ),
  );

  @override
  State<AyahSheet> createState() => _AyahSheetState();
}

class _AyahSheetState extends State<AyahSheet> {
  late Recitations? _recitations = widget.recitations;

  /// The ayah shown: the one opened, then each one the sheikh goes on to.
  late Ayah _ayah = widget.ayah;
  late int _word = widget.word;
  AyahPlayer get _player => widget.player ?? AyahPlayer.instance;
  String get _system => AudioNumbering.displaySystemFor(s.displayed ?? hafsId);
  int get _number =>
      widget.quran.numbering?.verseAt(
        _system,
        _ayah.surah,
        _ayah.number,
        _word,
      ) ??
      _ayah.number;

  String get _text {
    final map = widget.quran.numbering;
    final range = map?.span(_system, _ayah.surah, _number);
    final first = range?.first ?? (ayah: _ayah.number, word: 0);
    final last =
        range?.last ?? (ayah: _ayah.number, word: _ayah.words.length - 1);
    final parts = <String>[];
    for (var n = first.ayah; n <= last.ayah; n++) {
      final a = widget.quran.ayah(_ayah.surah, n);
      final from = n == first.ayah ? first.word : 0;
      final to = n == last.ayah ? last.word + 1 : a.words.length;
      parts.add(
        widget.variants == null
            ? a.words.sublist(from, to).join(' ')
            : readingText(widget.variants!, s.displayed, a, from, to),
      );
    }
    return parts.where((p) => p.isNotEmpty).join(' ');
  }

  /// The ayah playing when last seen.
  ({int surah, int ayah, int word})? _playing;

  @override
  void initState() {
    super.initState();
    if (_recitations == null) {
      AyahSheet._recitations.then((r) {
        if (mounted) setState(() => _recitations = r);
      });
    }
    final player = _player;
    player.ayahCounts = [for (final s in widget.quran.surahs) s.ayahCount];
    _playing = _now(player);
    player.addListener(_follow);
  }

  @override
  void dispose() {
    _player.removeListener(_follow);
    super.dispose();
  }

  static ({int surah, int ayah, int word})? _now(AyahPlayer player) {
    final c = player.current;
    return c == null
        ? null
        : (surah: c.surah, ayah: c.ayah, word: player.currentWord);
  }

  /// The recitation went on from the ayah shown to the next: show that one,
  /// with its tafsir.
  void _follow() {
    final now = _now(_player);
    final before = _playing;
    _playing = now;
    if (now == null || now == before) return;
    if (before?.surah == _ayah.surah && before?.ayah == _ayah.number) {
      setState(() {
        _ayah = widget.quran.ayah(now.surah, now.ayah);
        _word = now.word;
      });
    }
  }

  ReaderSettings get s => widget.settings;

  /// Hafs and the selected riwayat that have a recording.
  List<String> get _riwayat => [
    hafsId,
    for (final q in qiraat)
      for (final r in q.riwayat)
        if (s.selected.contains(r.id) &&
            (_recitations?.of(r.id).isNotEmpty ?? false))
          r.id,
  ];

  @override
  Widget build(BuildContext context) {
    final ayah = _ayah;
    final surah = widget.quran.surah(ayah.surah).nameAr;
    return ListenableBuilder(
      listenable: Listenable.merge([s, _player]),
      builder: (context, _) => ListView(
        controller: PrimaryScrollController.of(context),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Text(
            'سورة $surah • ${_number == 0 ? 'البسملة' : 'الآية $_number'}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MushafColors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _text,
            key: const ValueKey('selected-verse-text'),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Hafs',
              fontSize: 23,
              height: 1.9,
              color: MushafColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          _listen(),
          const SizedBox(height: 18),
          _Tafsir(ayah: ayah, settings: s),
        ],
      ),
    );
  }

  Widget _listen() {
    final recitations = _recitations;
    if (recitations == null) return const SizedBox(height: 60);
    final riwayat = _riwayat;
    final riwaya = riwayat.contains(s.listenRiwaya)
        ? s.listenRiwaya!
        : riwayat.contains(s.displayed)
        ? s.displayed!
        : riwayat[riwayat.length > 1 ? 1 : 0];
    final reciters = recitations.of(riwaya);
    final reciter = reciters.firstWhere(
      (r) => r.id == s.reciterFor(riwaya),
      orElse: () => reciters.first,
    );
    final player = _player;
    final ayah = _ayah;
    final c = player.current;
    final here =
        c != null &&
        c.surah == ayah.surah &&
        (widget.quran.numbering?.verseAt(
                  _system,
                  c.surah,
                  c.ayah,
                  player.currentWord,
                ) ??
                c.ayah) ==
            _number;
    final covered = player.clipVersesIn(_system);
    return Raised(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.headphones_rounded, color: MushafColors.green),
              const SizedBox(width: 8),
              Text(
                'الاستماع',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MushafColors.green,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Raised(
                circle: true,
                color: MushafColors.green,
                depth: 0.8,
                tooltip: here
                    ? (player.playbackRequested
                          ? 'إيقاف مؤقت'
                          : 'متابعة التلاوة')
                    : 'استماع',
                onTap: () => here
                    ? (player.playbackRequested
                          ? player.pause()
                          : player.resume())
                    : player.play(
                        ayah.surah,
                        ayah.number,
                        reciter,
                        selectionSystem: _system,
                        word: _word,
                      ),
                child: SizedBox.square(
                  dimension: 48,
                  child: here && player.loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          here && player.playbackRequested
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
              ),
              if (player.current != null)
                IconButton(
                  tooltip: 'إغلاق المشغّل',
                  onPressed: player.stop,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          if (player.current != null) RecitationSeekBar(player: player),
          // The riwaya, when there is a choice.
          if (riwayat.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in riwayat)
                  ChoiceChip(
                    label: Text('رواية ${riwayaById(id).nameAr}'),
                    selected: id == riwaya,
                    selectedColor: qiraaOf(id).color.withAlpha(90),
                    onSelected: (_) {
                      player.stop();
                      s.listenRiwaya = id;
                    },
                  ),
              ],
            ),
          ] else
            Text(
              'رواية ${riwayaById(riwaya).nameAr} عن ${qiraaOf(riwaya).shortAr}',
              style: TextStyle(color: MushafColors.frame),
            ),
          const SizedBox(height: 8),
          // The sheikh.
          DropdownButtonFormField<int>(
            initialValue: reciter.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'القارئ',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final r in reciters)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (id) {
              if (id == null) return;
              player.stop();
              s.setReciter(riwaya, id);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('متابعة الآيات التالية'),
            value: player.continuous,
            onChanged: (v) => setState(() => player.continuous = v),
          ),
          if (player.current != null && !here)
            Text(
              'يُتلى الآن: سورة ${widget.quran.surah(player.current!.surah).nameAr}، '
              'الآية ${player.nativeAyah} بحسب الرواية المسموعة',
              style: TextStyle(color: MushafColors.frame, fontSize: 12),
            ),
          if (covered.length > 1)
            Text(
              'يشمل هذا المقطع الآيات ${covered.first}–${covered.last} '
              'من الرواية المعروضة لاختلاف تقسيم الآيات.',
              style: TextStyle(color: MushafColors.frame, fontSize: 12),
            ),
          if (player.error != null)
            Text(
              'تعذر تشغيل التلاوة. تحقق من الاتصال بالإنترنت.',
              style: TextStyle(color: MushafColors.rose),
            ),
        ],
      ),
    );
  }
}

/// The tafsir of the ayah: a book to choose, and its text.
class _Tafsir extends StatefulWidget {
  const _Tafsir({required this.ayah, required this.settings});

  final Ayah ayah;
  final ReaderSettings settings;

  @override
  State<_Tafsir> createState() => _TafsirState();
}

class _TafsirState extends State<_Tafsir> {
  late Future<String?> _text = _load();
  late int _book = widget.settings.tafsirBook;

  @override
  void didUpdateWidget(_Tafsir old) {
    super.didUpdateWidget(old);
    // The sheikh went on to the next ayah: its tafsir.
    if (old.ayah != widget.ayah) _text = _load();
  }

  Future<String?> _load() => AyahSheet._tafsir.text(
    TafsirRepository.book(widget.settings.tafsirBook),
    widget.ayah.surah,
    widget.ayah.number,
  );

  void _choose(int id) {
    widget.settings.tafsirBook = id;
    setState(() {
      _book = id;
      _text = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = TafsirRepository.book(_book);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, color: MushafColors.green),
            const SizedBox(width: 8),
            Text(
              'التفسير',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: MushafColors.green,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final b in TafsirRepository.books)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    avatar: Icon(
                      b.offline
                          ? Icons.offline_pin_rounded
                          : Icons.cloud_rounded,
                      size: 16,
                    ),
                    label: Text(b.name),
                    selected: b.id == _book,
                    selectedColor: MushafColors.goldLight,
                    onSelected: (_) => _choose(b.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Raised(
          padding: const EdgeInsets.all(14),
          child: FutureBuilder<String?>(
            future: _text,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'تعذر تحميل ${book.name}: يحتاج هذا الكتاب إلى الإنترنت. '
                  'الكتب المحفوظة في التطبيق تعمل دون اتصال.',
                  style: TextStyle(color: MushafColors.rose),
                );
              }
              final text = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${book.name} — ${book.author}',
                    style: TextStyle(
                      color: MushafColors.frame,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (text == null)
                    const Text('لا يوجد في هذا الكتاب تفسير لهذه الآية.')
                  else
                    SelectableText.rich(
                      _styled(text),
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: MushafColors.ink,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'المصدر: ${TafsirRepository.source}',
                    style: TextStyle(color: MushafColors.frame, fontSize: 11),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// The ayahs the book quotes, in ﴿ ﴾, in the Quran's font and green.
  TextSpan _styled(String text) {
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in RegExp(r'﴿[^﴾]*﴾').allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(
        TextSpan(
          text: m[0],
          style: TextStyle(
            fontFamily: 'Hafs',
            fontSize: 18,
            color: MushafColors.green,
          ),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(children: spans);
  }
}
