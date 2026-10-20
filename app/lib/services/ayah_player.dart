import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/recitations.dart';

/// Plays ayahs, streamed from the reciter's files, one after the other when
/// [continuous]: shared by the whole app, so one ayah plays at a time.
class AyahPlayer extends ChangeNotifier {
  AyahPlayer._() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _onDone();
      notifyListeners();
    });
  }

  static final instance = AyahPlayer._();

  final _player = AudioPlayer();

  /// The ayah playing (or loading), with its reciter.
  ({int surah, int ayah, Reciter reciter})? current;

  /// Number of ayahs in each surah, to go on to the next ayah.
  List<int> ayahCounts = const [];

  /// Go on to the following ayahs.
  bool continuous = true;

  Object? error;

  bool get playing => _player.playing && current != null;
  bool get loading =>
      current != null &&
      (_player.processingState == ProcessingState.loading ||
          _player.processingState == ProcessingState.buffering);

  bool isPlaying(int surah, int ayah) =>
      current?.surah == surah && current?.ayah == ayah;

  Future<void> play(int surah, int ayah, Reciter reciter) async {
    current = (surah: surah, ayah: ayah, reciter: reciter);
    error = null;
    notifyListeners();
    try {
      await _player.setUrl(reciter.ayah(surah, ayah).toString());
      await _player.play();
    } catch (e) {
      error = e;
      current = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    current = null;
    notifyListeners();
    await _player.stop();
  }

  void _onDone() {
    final c = current;
    if (c == null) return;
    if (!continuous) {
      current = null;
      return;
    }
    var (surah, ayah) = (c.surah, c.ayah + 1);
    if (surah <= ayahCounts.length && ayah > ayahCounts[surah - 1]) {
      (surah, ayah) = (surah + 1, 1);
    }
    if (surah > 114) {
      current = null;
      return;
    }
    play(surah, ayah, c.reciter);
  }
}
