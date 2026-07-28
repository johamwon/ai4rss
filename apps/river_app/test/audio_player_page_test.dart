import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/audio/audio_player_page.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_data/river_data.dart' hide AudioItem, AudioQueueEntry;
import 'package:river_domain/river_domain.dart';

void main() {
  const goldenDiffTolerance = 0.025;
  late GoldenFileComparator originalComparator;
  late RiverDatabase database;
  late PersistentAudioQueue queue;
  late _AudioEngine engine;
  late AudioPlaybackController playback;
  late AudioQueuePlaybackCoordinator player;

  setUpAll(() {
    originalComparator = goldenFileComparator;
    final localComparator = originalComparator;
    if (localComparator is LocalFileComparator) {
      goldenFileComparator = _CrossPlatformGoldenComparator(
        localComparator.basedir.resolve('audio_player_page_test.dart'),
        tolerance: goldenDiffTolerance,
      );
    }
  });

  tearDownAll(() {
    goldenFileComparator = originalComparator;
  });

  setUp(() {
    database = RiverDatabase.inMemory();
    queue = PersistentAudioQueue(
      repository: DriftAudioQueueRepository(database),
      clock: const _Clock(),
    );
    engine = _AudioEngine();
    playback = AudioPlaybackController(
      engine: engine,
      repository: const UnavailableAudioPlaybackRepository(),
      clock: const _Clock(),
    );
    player = AudioQueuePlaybackCoordinator(
      queue: queue,
      playback: playback,
      resolve: _resolve,
    );
  });

  tearDown(() async {
    await player.dispose();
    await playback.dispose();
    await engine.close();
    await database.close();
  });

  testWidgets('empty player explains how to start listening', (tester) async {
    await tester.pumpWidget(_app(queue, player, playback));
    await tester.pumpAndSettle();

    expect(find.text('当前没有可播放内容'), findsOneWidget);
    expect(find.text('请先从文章或 Podcast 分集加入收听队列'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('player controls mixed queue rate and sleep timer', (
    tester,
  ) async {
    await queue.enqueue(_article, contentRevision: 'revision-1');
    await queue.enqueue(_podcast);
    var queueOpened = false;
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        queue,
        player,
        playback,
        onOpenQueue: () => queueOpened = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Article'), findsOneWidget);
    expect(find.text('文章朗读 · 等待播放'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('播放'));
    await tester.pumpAndSettle();
    expect(find.text('文章朗读 · 正在播放'), findsOneWidget);
    expect(find.text('第 1 / 1 段'), findsOneWidget);

    await tester.tap(find.byTooltip('播放速度'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<double>, '1.5 倍速'),
    );
    await tester.pumpAndSettle();
    expect(playback.state.settings.rate, 1.5);
    expect(find.text('1.5×'), findsOneWidget);

    await tester.tap(find.byTooltip('定时停止'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<int>, '10 分钟后停止'),
    );
    await tester.pumpAndSettle();
    expect(playback.state.sleepDeadline, isNotNull);
    expect(find.text('定时已开启'), findsOneWidget);

    await tester.tap(find.byTooltip('播放队列下一项'));
    await tester.pumpAndSettle();
    expect(engine.loads.last.item.id, _podcast.id);
    expect(find.text('Podcast · 正在播放'), findsOneWidget);

    await tester.tap(find.byTooltip('暂停'));
    await tester.pumpAndSettle();
    expect(find.text('Podcast · 已暂停'), findsOneWidget);

    await tester.tap(find.byTooltip('打开收听队列'));
    await tester.pump();
    expect(queueOpened, isTrue);
    await _unmount(tester);
  });

  testWidgets('player phone layout matches the approved surface', (
    tester,
  ) async {
    await queue.enqueue(_podcast);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(queue, player, playback));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AudioPlayerPage),
      matchesGoldenFile('goldens/audio_player_phone_light.png'),
    );
    await _unmount(tester);
  });
}

Future<ResolvedAudioQueueItem?> _resolve(AudioQueueEntry entry) async =>
    ResolvedAudioQueueItem(
      request: AudioLoadRequest(
        item: entry.item,
        speechSegments: entry.item.kind == AudioKind.articleTts
            ? const <SpeechSegment>[
                SpeechSegment(
                  index: 0,
                  text: 'Article sentence.',
                  sourceStart: 0,
                  sourceEnd: 17,
                ),
              ]
            : const <SpeechSegment>[],
        contentRevision: entry.contentRevision,
      ),
    );

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Widget _app(
  PersistentAudioQueue queue,
  AudioQueuePlaybackCoordinator player,
  AudioPlaybackController playback, {
  VoidCallback? onOpenQueue,
}) =>
    MaterialApp(
      home: AudioPlayerPage(
        queue: queue,
        player: player,
        playback: playback,
        onOpenQueue: onOpenQueue ?? () {},
      ),
    );

final class _AudioEngine implements AudioEngine {
  final _events = StreamController<AudioEngineEvent>.broadcast(sync: true);
  final List<AudioLoadRequest> loads = <AudioLoadRequest>[];
  AudioLoadRequest? _current;

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      const AudioEngineCapabilities(
        supportsArticleTts: true,
        supportsPodcastMedia: true,
        canPause: true,
        canResume: true,
        canSeek: true,
        canSetRate: true,
        canSetPitch: true,
        canSelectVoice: true,
      );

  @override
  Future<List<AudioVoice>> voices() async => const <AudioVoice>[];

  @override
  Future<void> load(AudioLoadRequest request) async {
    _current = request;
    loads.add(request);
  }

  @override
  Future<void> play() async => _emit(AudioEnginePhase.playing);

  @override
  Future<void> pause() async => _emit(AudioEnginePhase.paused);

  @override
  Future<void> resume() async => _emit(AudioEnginePhase.playing);

  void _emit(AudioEnginePhase phase) {
    _events.add(
      AudioEngineEvent(
        phase: phase,
        itemId: _current?.item.id,
        position: _current?.item.kind == AudioKind.articleTts
            ? const AudioPlaybackPosition.speech(segmentIndex: 0)
            : AudioPlaybackPosition.media(Duration.zero),
      ),
    );
  }

  Future<void> close() => _events.close();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> seek(AudioPlaybackPosition position) async {}

  @override
  Future<void> stop() async => _emit(AudioEnginePhase.stopped);

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {}
}

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 28, 10);
}

final _article = AudioItem(
  id: 'article-1',
  kind: AudioKind.articleTts,
  title: 'Article',
  sourceUri: Uri.parse('https://example.test/articles/1'),
);

final _podcast = AudioItem(
  id: 'podcast-1',
  kind: AudioKind.podcastEpisode,
  title: 'A thoughtful Podcast episode for the commute',
  sourceUri: Uri.parse('https://example.test/podcast/1.mp3'),
);

final class _CrossPlatformGoldenComparator extends LocalFileComparator {
  _CrossPlatformGoldenComparator(
    super.testFile, {
    required this.tolerance,
  });

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }

    final feedback = await generateFailureOutput(result, golden, basedir);
    final actual = (result.diffPercent * 100).toStringAsFixed(2);
    final allowed = (tolerance * 100).toStringAsFixed(2);
    result.dispose();
    throw FlutterError(
      '$feedback\n'
      'Cross-platform golden difference was $actual%; '
      'the allowed maximum is $allowed%.',
    );
  }
}
