import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class TestAudio extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  final urls = <String>[];
  final seeks = <Duration>[];
  Object? seekError;
  final pending = <Completer<Duration?>>[];
  bool holdLoads = false;
  int plays = 0;
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(seconds: 10);
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    urls.add(url);
    processingState = ProcessingState.loading;
    position = Duration.zero;
    duration = null;
    if (holdLoads) {
      final load = Completer<Duration?>();
      pending.add(load);
      final result = await load.future;
      processingState = ProcessingState.ready;
      duration = result;
      durations.add(duration);
      return result;
    }
    processingState = ProcessingState.ready;
    duration = const Duration(seconds: 10);
    durations.add(duration);
    return const Duration(seconds: 10);
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
    states.add(PlayerState(playing, processingState));
  }

  @override
  Future<void> pause() async {
    playing = false;
    states.add(PlayerState(playing, processingState));
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    if (seekError case final error?) throw error;
    this.position = position ?? Duration.zero;
    seeks.add(this.position);
    positions.add(this.position);
    processingState = duration != null && this.position >= duration!
        ? ProcessingState.completed
        : ProcessingState.ready;
    states.add(PlayerState(playing, processingState));
  }

  void updatePosition(Duration value) {
    position = value;
    positions.add(value);
  }

  void updateDuration(Duration? value) {
    duration = value;
    durations.add(value);
  }

  @override
  Future<void> stop() async {
    playing = false;
    processingState = ProcessingState.idle;
  }

  @override
  Future<void> dispose() async {
    await states.close();
    await positions.close();
    await durations.close();
  }

  void complete() {
    processingState = ProcessingState.completed;
    states.add(PlayerState(playing, processingState));
  }
}
