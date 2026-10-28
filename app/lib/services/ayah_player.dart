import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/audio_numbering.dart';
import '../data/recitations.dart';

/// One shared player. Displayed verse anchors and native audio numbering are
/// separate: a displayed verse can share a clip or require several clips.
class AyahPlayer extends ChangeNotifier {
  AyahPlayer._() : this.withPlayer(AudioPlayer(), AudioNumbering.load);

  @visibleForTesting
  AyahPlayer.withPlayer(this._player, this._loadNumbering) {
    _subscription = _player.playerStateStream.listen((state) {
      if (_armed &&
          _wantsToPlay &&
          state.processingState == ProcessingState.completed &&
          _player.processingState == ProcessingState.completed) {
        _armed = false;
        _onDone();
      }
      notifyListeners();
    });
  }

  static final instance = AyahPlayer._();
  final AudioPlayer _player;
  final Future<AudioNumbering> Function() _loadNumbering;
  late final StreamSubscription<PlayerState> _subscription;
  AudioNumbering? _numbering;
  int _request = 0;
  int _native = 0;
  int _selectionEnd = 0;
  bool _armed = false;
  bool _preparing = false;
  bool _wantsToPlay = false;
  String? _selectionSystem;
  int _currentWord = 0;
  int get currentWord => _currentWord;
  int get nativeAyah => _native;
  int get clipToken => _request;
  bool get playbackRequested => current != null && _wantsToPlay;
  Duration get position =>
      current == null || _preparing ? Duration.zero : _player.position;
  Duration? get duration =>
      current == null || _preparing ? null : _player.duration;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  bool get canSeek =>
      current != null && !_preparing && (duration?.inMilliseconds ?? 0) > 0;

  /// Always expressed in the displayed Hafs/Kufan verse numbering.
  ({int surah, int ayah, Reciter reciter})? current;

  /// Retained for callers supplying displayed verse counts.
  List<int> ayahCounts = const [];
  bool continuous = true;
  Object? error;

  /// The speeds a recitation can be heard at.
  static const speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 2.5];

  /// The speed of every recitation, kept from one ayah to the next.
  double get speed => _speed;
  double _speed = 1.0;

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    notifyListeners();
    await _player.setSpeed(speed);
  }

  bool get playing => _player.playing && current != null;
  bool get loading =>
      current != null &&
      (_preparing ||
          _player.processingState == ProcessingState.loading ||
          _player.processingState == ProcessingState.buffering);

  /// Native clips cannot be trimmed to other verse boundaries without timings.
  List<int> get clipVerses {
    final c = current;
    if (c == null || _numbering == null || _preparing) return const [];
    return _numbering!.displayedVerses(c.reciter.numbering, c.surah, _native);
  }

  List<int> clipVersesIn(String system) {
    final c = current;
    if (c == null || _numbering == null || _preparing) return const [];
    return _numbering!.clipsForSpan(
      system,
      c.surah,
      _numbering!.span(c.reciter.numbering, c.surah, _native),
    );
  }

  bool isPlaying(int surah, int ayah) =>
      current?.surah == surah && current?.ayah == ayah;

  Future<void> play(
    int surah,
    int ayah,
    Reciter reciter, {
    String? selectionSystem,
    int word = 0,
  }) async {
    final request = ++_request;
    _armed = false;
    _preparing = true;
    _wantsToPlay = true;
    _selectionSystem = selectionSystem;
    _currentWord = word;
    current = (surah: surah, ayah: ayah, reciter: reciter);
    error = null;
    notifyListeners();
    try {
      await _player.stop();
      if (request != _request) return;
      final numbering = _numbering ??= await _loadNumbering();
      if (request != _request) return;
      final clips = selectionSystem == null
          ? numbering.clips(reciter.numbering, surah, ayah)
          : numbering.clipsForSpan(
              reciter.numbering,
              surah,
              numbering.span(
                selectionSystem,
                surah,
                numbering.verseAt(selectionSystem, surah, ayah, word),
              ),
            );
      _selectionEnd = clips.last;
      await _startClip(request, clips.first);
    } catch (e) {
      _fail(request, e);
    }
  }

  Future<void> _startClip(int request, int native) async {
    final c = current!;
    _native = native;
    _armed = false;
    _preparing = true;
    notifyListeners();
    if (request != _request) return;
    try {
      await _player.setUrl(c.reciter.ayah(c.surah, native).toString());
      if (request != _request) return;
      _preparing = false;
      _armed = true;
      notifyListeners();
      if (request != _request) return;
      if (_wantsToPlay) await _player.play();
    } catch (e) {
      _fail(request, e);
    }
  }

  void _fail(int request, Object e) {
    if (request != _request) return;
    _armed = false;
    _preparing = false;
    error = e;
    current = null;
    notifyListeners();
  }

  Future<void> stop() async {
    ++_request;
    _armed = false;
    _preparing = false;
    _wantsToPlay = false;
    current = null;
    notifyListeners();
    await _player.stop();
  }

  Future<void> pause() async {
    if (current == null) return;
    _wantsToPlay = false;
    final request = _request;
    try {
      await _player.pause();
      if (request == _request) notifyListeners();
    } catch (e) {
      _controlError(request, e);
    }
  }

  Future<void> resume() async {
    if (current == null) return;
    final request = _request;
    _wantsToPlay = true;
    error = null;
    notifyListeners();
    if (request != _request || !_wantsToPlay || _preparing) return;
    try {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      if (request != _request || !_wantsToPlay) return;
      await _player.play();
      if (request == _request) notifyListeners();
    } catch (e) {
      _controlError(request, e);
    }
  }

  Future<void> seek(Duration target, {int? clip}) async {
    if (!canSeek || clip != null && clip != _request) return;
    final request = _request;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, duration!.inMilliseconds),
    );
    try {
      await _player.seek(clamped);
      if (request == _request) {
        error = null;
        notifyListeners();
      }
    } catch (e) {
      _controlError(request, e);
    }
  }

  void _controlError(int request, Object e) {
    if (request != _request) return;
    error = e;
    notifyListeners();
  }

  void _onDone() {
    final c = current;
    if (c == null) return;
    // Single-verse playback must also finish every part of a split verse.
    if (!continuous && _native >= _selectionEnd) {
      current = null;
      return;
    }
    var surah = c.surah;
    var native = _native + 1;
    final numbering = _numbering!;
    if (native > numbering.nativeCount(c.reciter.numbering, surah)) {
      surah++;
      native = 1;
    }
    if (surah > numbering.hafsCounts.length) {
      current = null;
      return;
    }
    final covered = numbering.displayedVerses(
      c.reciter.numbering,
      surah,
      native,
    );
    // Preserve a selection within a merged clip; never move backwards through
    // the parts of a split verse during automatic playback.
    final ayah = surah == c.surah && c.ayah > covered.first
        ? c.ayah
        : covered.first;
    final firstWord = numbering.span(c.reciter.numbering, surah, native).first;
    final word =
        surah == c.surah &&
            ayah == c.ayah &&
            (ayah > firstWord.ayah || _currentWord > firstWord.word)
        ? _currentWord
        : firstWord.word;
    _currentWord = word;
    final system = _selectionSystem;
    _selectionEnd = system == null
        ? numbering.clips(c.reciter.numbering, surah, ayah).last
        : numbering
              .clipsForSpan(
                c.reciter.numbering,
                surah,
                numbering.span(
                  system,
                  surah,
                  numbering.verseAt(system, surah, ayah, word),
                ),
              )
              .last;
    current = (surah: surah, ayah: ayah, reciter: c.reciter);
    unawaited(_startClip(++_request, native));
  }

  @override
  void dispose() {
    ++_request;
    _armed = false;
    _wantsToPlay = false;
    unawaited(_subscription.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
