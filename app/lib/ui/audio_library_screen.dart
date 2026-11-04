import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../data/recitations.dart';
import '../models/qiraat_catalog.dart';
import '../services/audio_library.dart';
import '../services/ayah_player.dart';
import 'theme.dart';

/// The recitations: every qari, his riwayat and their sheikhs. Each can be heard
/// from any surah, or kept whole on the device to be heard with no connection.
class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({
    super.key,
    required this.quran,
    this.library,
    this.player,
    this.recitations,
  });

  final QuranRepository quran;
  final AudioLibrary? library;
  final AyahPlayer? player;
  final Recitations? recitations;

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  late final AudioLibrary _library = widget.library ?? AudioLibrary.instance;
  late final AyahPlayer _player = widget.player ?? AyahPlayer.instance;
  Recitations? _recitations;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final recitations = widget.recitations ?? await Recitations.load();
      if (!mounted) return;
      setState(() => _recitations = recitations);
      // What is on the device already, shown on each line.
      for (final q in qiraat) {
        for (final r in q.riwayat) {
          for (final reciter in recitations.of(r.id)) {
            await _library.scan(reciter);
            if (!mounted) return;
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  static String size(int bytes) => bytes >= 1 << 30
      ? '${(bytes / (1 << 30)).toStringAsFixed(1)} جيجابايت'
      : '${(bytes / (1 << 20)).toStringAsFixed(0)} ميجابايت';

  Future<void> _startDownload(Reciter reciter) async {
    final estimate = await _library.estimateBytes(reciter);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحميل تلاوة ${reciter.name}'),
        content: Text(
          '${estimate == null ? 'الحجم غير معروف، وقد يتجاوز جيجابايت.' : 'الحجم نحو ${size(estimate)}.'}\n'
          'يُفضَّل استخدام Wi-Fi. يستمر التحميل والتطبيق مفتوح، وإذا توقف '
          'يكمل من حيث انتهى.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey('audio-download-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تحميل'),
          ),
        ],
      ),
    );
    if (ok == true) await _library.download(reciter);
  }

  Future<void> _delete(Reciter reciter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التلاوة من الجهاز؟'),
        content: Text(
          'ستُحذف ملفات ${reciter.name} ويمكن تحميلها أو سماعها عبر الإنترنت لاحقًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) await _library.delete(reciter);
  }

  void _pickSurah(Reciter reciter) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      builder: (context, controller) => ListView.builder(
        controller: controller,
        itemCount: widget.quran.surahs.length,
        itemBuilder: (context, i) => ListenableBuilder(
          listenable: _library,
          builder: (context, _) => _surahTile(context, reciter, i + 1),
        ),
      ),
    ),
  );

  /// A surah: tapped to hear it, with its own download beside it.
  Widget _surahTile(BuildContext context, Reciter reciter, int surah) {
    final (:done, :total) = _library.surahProgress(reciter, surah);
    final running = _library.isSurahRunning(reciter, surah);
    final complete = total > 0 && done >= total;
    final name = widget.quran.surah(surah).nameAr;
    return ListTile(
      key: ValueKey('audio-surah-$surah'),
      leading: CircleAvatar(radius: 15, child: Text('$surah')),
      title: Text('سورة $name'),
      subtitle: complete
          ? const Text('على الجهاز')
          : running || done > 0
          ? Text('$done من $total آية')
          : null,
      onTap: () {
        Navigator.pop(context);
        _player.continuous = true;
        _player.play(surah, 1, reciter);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded),
          if (complete)
            IconButton(
              key: ValueKey('audio-surah-delete-$surah'),
              tooltip: 'حذف السورة من الجهاز',
              onPressed: () => _deleteSurah(reciter, surah, name),
              icon: Icon(
                Icons.download_done_rounded,
                color: MushafColors.green,
              ),
            )
          else if (running)
            IconButton(
              key: ValueKey('audio-surah-pause-$surah'),
              tooltip: 'إيقاف التحميل مؤقتًا',
              // The whole's download is stopped from the reciter's line.
              onPressed: _library.isRunning(reciter)
                  ? null
                  : () => _library.pause(reciter, surah: surah),
              icon: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: total == 0 ? null : done / total,
                ),
              ),
            )
          else
            IconButton(
              key: ValueKey('audio-surah-download-$surah'),
              tooltip: 'تحميل السورة',
              onPressed: () => _library.download(reciter, surah: surah),
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteSurah(Reciter reciter, int surah, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف سورة $name من الجهاز؟'),
        content: Text('ويمكن تحميلها أو سماعها بصوت ${reciter.name} لاحقًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) await _library.deleteSurah(reciter, surah);
  }

  Widget _reciterTile(Reciter reciter) => ListenableBuilder(
    listenable: _library,
    builder: (context, _) {
      final state = _library.stateOf(reciter);
      final running = _library.isRunning(reciter);
      final percent = (state.progress * 100).floor();
      final note = switch (state.status) {
        DownloadStatus.notStarted => 'عبر الإنترنت',
        DownloadStatus.complete => 'على الجهاز • ${size(state.bytes)}',
        _ when running => 'جارٍ التحميل $percent٪ • ${size(state.bytes)}',
        _ => 'محمَّل منها $percent٪ • ${size(state.bytes)}',
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: ValueKey('audio-reciter-${reciter.id}'),
            dense: true,
            title: Text(reciter.name),
            subtitle: Text(
              state.error ??
                  (state.failed > 0 && !running
                      ? '$note • ${state.failed} لم يكتمل'
                      : note),
              style: state.error == null
                  ? null
                  : TextStyle(color: MushafColors.rose),
            ),
            onTap: () => _pickSurah(reciter),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'استماع',
                  onPressed: () => _pickSurah(reciter),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                ),
                if (running)
                  IconButton(
                    key: ValueKey('audio-pause-${reciter.id}'),
                    tooltip: 'إيقاف التحميل مؤقتًا',
                    onPressed: () => _library.pause(reciter),
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                  )
                else if (state.status == DownloadStatus.complete)
                  IconButton(
                    key: ValueKey('audio-delete-${reciter.id}'),
                    tooltip: 'حذف من الجهاز',
                    onPressed: () => _delete(reciter),
                    icon: Icon(
                      Icons.download_done_rounded,
                      color: MushafColors.green,
                    ),
                  )
                else ...[
                  IconButton(
                    key: ValueKey('audio-download-${reciter.id}'),
                    tooltip: state.status == DownloadStatus.paused
                        ? 'متابعة التحميل'
                        : 'تحميل التلاوة كاملة',
                    onPressed: () => _startDownload(reciter),
                    icon: const Icon(Icons.download_rounded),
                  ),
                  if (state.status == DownloadStatus.paused)
                    IconButton(
                      tooltip: 'حذف من الجهاز',
                      onPressed: () => _delete(reciter),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ],
            ),
          ),
          if (running)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(value: state.progress),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final recitations = _recitations;
    return Scaffold(
      appBar: AppBar(title: const Text('المسموعات')),
      body: _error != null
          ? const Center(child: Text('تعذر تحميل قائمة التلاوات.'))
          : recitations == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final q in qiraat)
                  ExpansionTile(
                    key: ValueKey('audio-qiraa-${q.id}'),
                    leading: Icon(Icons.headphones_rounded, color: q.color),
                    title: Text(q.nameAr),
                    children: [
                      for (final r in q.riwayat)
                        ExpansionTile(
                          key: ValueKey('audio-riwaya-${r.id}'),
                          tilePadding: const EdgeInsetsDirectional.only(
                            start: 32,
                            end: 16,
                          ),
                          title: Text('رواية ${r.nameAr}'),
                          subtitle: Text(
                            recitations.of(r.id).isEmpty
                                ? 'لا توجد تلاوة متاحة بعد'
                                : '${recitations.of(r.id).length} تلاوة',
                          ),
                          children: [
                            for (final reciter in recitations.of(r.id))
                              _reciterTile(reciter),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}
