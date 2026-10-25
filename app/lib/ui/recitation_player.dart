import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import '../services/ayah_player.dart';
import 'theme.dart';

/// Lives outside the Navigator so closing a sheet or returning home never
/// removes the controls for audio that is still playing.
class RecitationPlayerHost extends StatefulWidget {
  const RecitationPlayerHost({
    super.key,
    required this.child,
    required this.player,
    required this.quran,
    required this.onOpen,
  });

  final Widget child;
  final AyahPlayer player;
  final QuranRepository quran;
  final VoidCallback onOpen;

  @override
  State<RecitationPlayerHost> createState() => _RecitationPlayerHostState();
}

class _RecitationPlayerHostState extends State<RecitationPlayerHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: _buildContent);

  @override
  void didUpdateWidget(RecitationPlayerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    if (_entry.mounted) _entry.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);

  Widget _buildContent(BuildContext context) => Column(
    children: [
      Expanded(child: widget.child),
      ListenableBuilder(
        listenable: widget.player,
        builder: (context, _) {
          final player = widget.player;
          final current = player.current;
          if (current == null) return const SizedBox.shrink();
          final verse = player.nativeAyah == 0
              ? 'البسملة'
              : 'الآية ${player.nativeAyah}';
          return Material(
            key: const ValueKey('mini-recitation-player'),
            color: Theme.of(context).colorScheme.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: player.playbackRequested
                              ? 'إيقاف مؤقت'
                              : 'متابعة التلاوة',
                          onPressed: () => player.playbackRequested
                              ? player.pause()
                              : player.resume(),
                          icon: Icon(
                            player.playbackRequested
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: widget.onOpen,
                            child: Tooltip(
                              message: 'فتح الاستماع والتفسير',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  '${player.loading ? 'جارٍ تحميل التلاوة' : 'سورة ${widget.quran.surah(current.surah).nameAr} • $verse'}\n${current.reciter.name}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'فتح الاستماع والتفسير',
                          onPressed: widget.onOpen,
                          icon: const Icon(Icons.expand_less_rounded),
                        ),
                        IconButton(
                          tooltip: 'إغلاق المشغّل',
                          onPressed: player.stop,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    RecitationSeekBar(player: player),
                    if (player.error != null)
                      Text(
                        'تعذر التحكم بالتلاوة. حاول مرة أخرى.',
                        style: TextStyle(
                          color: MushafColors.rose,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}

/// Stream updates repaint only the timeline. A drag previews its target and
/// commits one seek on release, provided the same clip is still selected.
class RecitationSeekBar extends StatefulWidget {
  const RecitationSeekBar({super.key, required this.player});
  final AyahPlayer player;

  @override
  State<RecitationSeekBar> createState() => _RecitationSeekBarState();
}

class _RecitationSeekBarState extends State<RecitationSeekBar> {
  double? _drag;
  int? _clip;

  static String _time(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.player,
    builder: (context, _) => StreamBuilder<Duration?>(
      stream: widget.player.durationStream,
      builder: (context, _) => StreamBuilder<Duration>(
        stream: widget.player.positionStream,
        builder: (context, _) {
          final player = widget.player;
          final total = player.duration;
          final maximum = (total?.inMilliseconds ?? 0).toDouble();
          final dragging = _clip == player.clipToken ? _drag : null;
          final value = (dragging ?? player.position.inMilliseconds.toDouble())
              .clamp(0.0, maximum);
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Text(
                  _time(Duration(milliseconds: value.round())),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey('recitation-seek-bar'),
                    value: value,
                    max: maximum > 0 ? maximum : 1,
                    label: _time(Duration(milliseconds: value.round())),
                    semanticFormatterCallback: (value) =>
                        _time(Duration(milliseconds: value.round())),
                    onChangeStart: player.canSeek
                        ? (value) => setState(() {
                            _clip = player.clipToken;
                            _drag = value;
                          })
                        : null,
                    onChanged: player.canSeek
                        ? (value) => setState(() => _drag = value)
                        : null,
                    onChangeEnd: player.canSeek
                        ? (value) {
                            final clip = _clip;
                            setState(() {
                              _drag = null;
                              _clip = null;
                            });
                            // If completion replaced the source during the gesture,
                            // never apply the old finger position to the next ayah.
                            if (clip != null) {
                              player.seek(
                                Duration(milliseconds: value.round()),
                                clip: clip,
                              );
                            }
                          }
                        : null,
                  ),
                ),
                Text(
                  total == null ? '--:--' : _time(total),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
