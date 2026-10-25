import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_audio.dart';

import 'package:qiraat_mushaf/data/audio_numbering.dart';
import 'package:qiraat_mushaf/data/recitations.dart';
import 'package:qiraat_mushaf/services/ayah_player.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AudioNumbering map;
  late TestAudio audio;
  late AyahPlayer player;
  const warsh = Reciter(
    262,
    'warsh',
    'https://audio/',
    numbering: 'madani-last',
  );
  const hafs = Reciter(1, 'hafs', 'https://hafs/');
  setUpAll(() async => map = await AudioNumbering.load());
  setUp(() {
    audio = TestAudio();
    player = AyahPlayer.withPlayer(audio, () async => map);
  });
  tearDown(() => player.dispose());

  test('selected displayed verse requests its own native audio', () async {
    await player.play(2, 5, warsh);
    expect(audio.urls.single, endsWith('/002004.mp3'));
    expect(player.current?.ayah, 5);
    expect(player.clipVerses, [5]);
    await player.play(2, 5, hafs);
    expect(audio.urls.last, endsWith('/002005.mp3'));
  });

  test('merged clips are not repeated during continuous playback', () async {
    await player.play(2, 1, warsh);
    expect(player.clipVerses, [1, 2]);
    audio.complete();
    await settle();
    expect(audio.urls, [
      'https://audio/002001.mp3',
      'https://audio/002002.mp3',
    ]);
    expect(player.current?.ayah, 3);
  });

  test(
    'single displayed verse plays every split part before stopping',
    () async {
      player.continuous = false;
      await player.play(1, 7, warsh);
      expect(audio.urls.last, endsWith('/001006.mp3'));
      audio.complete();
      await settle();
      expect(audio.urls.last, endsWith('/001007.mp3'));
      expect(player.current?.ayah, 7);
      audio.complete();
      await settle();
      expect(player.current, isNull);
      expect(audio.urls, hasLength(2));
    },
  );

  test(
    'uncounted basmala is played then follows to displayed verse two',
    () async {
      await player.play(1, 1, warsh);
      expect(audio.urls.last, endsWith('/001000.mp3'));
      audio.complete();
      await settle();
      expect(audio.urls.last, endsWith('/001001.mp3'));
      expect(player.current?.ayah, 2);
    },
  );

  test(
    'continuous playback uses native surah endpoints and stops at Quran end',
    () async {
      await player.play(2, 286, warsh);
      expect(audio.urls.last, endsWith('/002285.mp3'));
      audio.complete();
      await settle();
      expect(audio.urls.last, endsWith('/003001.mp3'));
      expect(player.current?.surah, 3);
      await player.play(114, 6, warsh);
      audio.complete();
      await settle();
      expect(player.current, isNull);
    },
  );

  test('old load failure cannot clear the newly selected verse', () async {
    audio.holdLoads = true;
    final old = player.play(2, 5, warsh);
    await settle();
    final latest = player.play(2, 8, hafs);
    await settle();
    audio.pending[0].completeError(StateError('interrupted old load'));
    await old;
    expect(player.current?.ayah, 8);
    expect(player.error, isNull);
    audio.pending[1].complete(const Duration(seconds: 10));
    await latest;
    expect(audio.plays, 1);
    expect(audio.urls.last, endsWith('/002008.mp3'));
  });

  test('stop cancels a pending load and ignores completion events', () async {
    audio.holdLoads = true;
    final load = player.play(2, 5, warsh);
    await settle();
    audio.complete();
    expect(audio.urls, hasLength(1));
    await player.stop();
    audio.pending.single.complete(const Duration(seconds: 10));
    await load;
    audio.complete();
    await settle();
    expect(player.current, isNull);
    expect(audio.plays, 0);
  });

  test('duplicate completion does not skip a verse during loading', () async {
    await player.play(2, 5, hafs);
    audio.holdLoads = true;
    audio.complete();
    audio.complete();
    expect(audio.urls, hasLength(2));
    expect(player.current?.ayah, 6);
    audio.pending.single.complete(const Duration(seconds: 10));
    await settle();
    expect(player.current?.ayah, 6);
  });

  test(
    'disabling continuous playback finishes the current split verse',
    () async {
      await player.play(1, 6, warsh);
      audio.complete();
      await settle();
      expect(player.current?.ayah, 7);
      expect(audio.urls.last, endsWith('/001006.mp3'));

      player.continuous = false;
      audio.complete();
      await settle();
      expect(audio.urls.last, endsWith('/001007.mp3'));
      expect(player.current?.ayah, 7);

      audio.complete();
      await settle();
      expect(player.current, isNull);
      expect(audio.urls, hasLength(3));
    },
  );

  test('stopping from a ready notification prevents playback', () async {
    player.addListener(() {
      if (player.current != null && !player.loading) {
        unawaited(player.stop());
      }
    });

    await player.play(2, 5, hafs);
    expect(player.current, isNull);
    expect(audio.plays, 0);
    expect(audio.playing, isFalse);
  });

  test(
    'Warsh display and Hafs audio play both halves of a merged verse',
    () async {
      player.continuous = false;
      await player.play(2, 2, hafs, selectionSystem: 'madani-last', word: 2);
      expect(audio.urls.single, endsWith('/002001.mp3'));
      audio.complete();
      await settle();
      expect(audio.urls.last, endsWith('/002002.mp3'));
      expect(player.current, isNotNull);
      audio.complete();
      await settle();
      expect(player.current, isNull);
      expect(audio.urls, hasLength(2));
    },
  );

  test(
    'Warsh Fatiha words on either side of the split choose different clips',
    () async {
      player.continuous = false;
      await player.play(1, 7, warsh, selectionSystem: 'madani-last', word: 1);
      expect(audio.urls.last, endsWith('/001006.mp3'));
      audio.complete();
      await settle();
      expect(player.current, isNull);
      await player.play(1, 7, warsh, selectionSystem: 'madani-last', word: 4);
      expect(audio.urls.last, endsWith('/001007.mp3'));
      expect(player.clipVersesIn('madani-last'), [7]);
    },
  );

  test(
    'all displayed counting profiles map to all recording profiles',
    () async {
      player.continuous = false;
      for (final displayed in map.systems) {
        for (final listening in map.systems) {
          final reciter = Reciter(
            99,
            listening,
            'https://audio/',
            numbering: listening,
          );
          const surah = 2, ayah = 255, word = 8;
          final verse = map.verseAt(displayed, surah, ayah, word);
          final expected = map.clipsForSpan(
            listening,
            surah,
            map.span(displayed, surah, verse),
          );
          audio.urls.clear();
          await player.play(
            surah,
            ayah,
            reciter,
            selectionSystem: displayed,
            word: word,
          );
          for (final n in expected) {
            expect(
              audio.urls.last,
              reciter.ayah(surah, n).toString(),
              reason: '$displayed/$listening',
            );
            audio.complete();
            await settle();
          }
          expect(player.current, isNull, reason: '$displayed/$listening');
          expect(audio.urls, hasLength(expected.length));
        }
      }
    },
  );

  test('Qunbul display and Bazzi audio retain both Naba clips', () async {
    player.continuous = false;
    const bazzi = Reciter(
      268,
      'Bazzi',
      'https://audio/',
      numbering: 'makki-6220',
    );
    await player.play(78, 40, bazzi, selectionSystem: 'makki', word: 0);
    expect(audio.urls.single, endsWith('/078040.mp3'));
    audio.complete();
    await settle();
    expect(audio.urls.last, endsWith('/078041.mp3'));
    audio.complete();
    await settle();
    expect(player.current, isNull);
    expect(audio.urls, hasLength(2));
  });

  test(
    'pause, seek and resume preserve the verse and loaded recording',
    () async {
      await player.play(2, 5, warsh);
      audio.updatePosition(const Duration(seconds: 4));
      await player.pause();
      expect(player.current?.ayah, 5);
      expect(player.playing, isFalse);
      expect(player.playbackRequested, isFalse);
      expect(player.position, const Duration(seconds: 4));
      await player.seek(const Duration(seconds: 8));
      expect(player.position, const Duration(seconds: 8));
      expect(audio.playing, isFalse);
      await player.resume();
      expect(player.playing, isTrue);
      expect(audio.urls, hasLength(1));
      expect(audio.plays, 2);
      expect(player.nativeAyah, 4);
    },
  );

  test('pausing during loading prevents delayed automatic playback', () async {
    audio.holdLoads = true;
    final loading = player.play(2, 5, hafs);
    await settle();
    await player.pause();
    audio.pending.single.complete(const Duration(seconds: 10));
    await loading;
    expect(audio.plays, 0);
    expect(player.current?.ayah, 5);
    await player.resume();
    expect(audio.plays, 1);
  });

  test(
    'a drag from a replaced or closed clip cannot seek a new verse',
    () async {
      await player.play(2, 5, hafs);
      final oldClip = player.clipToken;
      await player.play(2, 6, hafs);
      await player.seek(const Duration(seconds: 9), clip: oldClip);
      expect(audio.seeks, isEmpty);
      await player.stop();
      await player.seek(const Duration(seconds: 9));
      expect(audio.seeks, isEmpty);
      expect(player.duration, isNull);
      expect(player.position, Duration.zero);
    },
  );

  test(
    'seeking while paused clamps to the clip and does not advance',
    () async {
      await player.play(2, 5, hafs);
      await player.pause();
      await player.seek(const Duration(seconds: -2));
      expect(player.position, Duration.zero);
      await player.seek(const Duration(hours: 1));
      expect(player.position, const Duration(seconds: 10));
      expect(player.current?.ayah, 5);
      expect(audio.urls, hasLength(1));
      await player.resume();
      expect(player.position, Duration.zero);
      expect(player.current?.ayah, 5);
      expect(player.playing, isTrue);
    },
  );

  test(
    'a failed seek leaves the current audio accessible to stop or retry',
    () async {
      await player.play(2, 5, hafs);
      audio.seekError = StateError('seek failed');
      await player.seek(const Duration(seconds: 3));
      expect(player.current?.ayah, 5);
      expect(player.error, isNotNull);
      audio.seekError = null;
      await player.seek(const Duration(seconds: 3));
      expect(player.error, isNull);
      expect(player.position, const Duration(seconds: 3));
      await player.stop();
      expect(audio.playing, isFalse);
    },
  );

  test('stop during a resume notification cannot restart playback', () async {
    await player.play(2, 5, hafs);
    await player.pause();
    player.addListener(() {
      if (player.playbackRequested) unawaited(player.stop());
    });
    await player.resume();
    expect(player.current, isNull);
    expect(audio.plays, 1);
    expect(audio.playing, isFalse);
  });
}
