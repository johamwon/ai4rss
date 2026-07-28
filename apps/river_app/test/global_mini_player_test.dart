import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/audio/global_mini_player.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_data/river_data.dart' hide AudioItem, AudioQueueEntry;
import 'package:river_domain/river_domain.dart';

void main() {
  late RiverDatabase database;
  late PersistentAudioQueue queue;
  late _AudioEngine engine;
  late AudioPlaybackController playback;
  late AudioQueuePlaybackCoordinator player;

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

  testWidgets('stays hidden until audio is available', (tester) async {
    await tester.pumpWidget(_app(queue, player, playback));
    await tester.pumpAndSettle();

    expect(find.byTooltip('打开收听队列'), findsNothing);
    expect(find.byType(GlobalMiniPlayer), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('controls mixed queue and opens its full view', (tester) async {
    await queue.enqueue(_article, contentRevision: 'revision-1');
    await queue.enqueue(_podcast);
    var playerOpened = false;
    var queueOpened = false;
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        queue,
        player,
        playback,
        onOpenPlayer: () => playerOpened = true,
        onOpenQueue: () => queueOpened = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Article'), findsOneWidget);
    expect(find.text('文章朗读 · 等待播放'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('播放'));
    await tester.pumpAndSettle();
    expect(engine.loads.map((request) => request.item.id), <String>[
      _article.id,
    ]);
    expect(find.text('文章朗读 · 正在播放'), findsOneWidget);
    expect(find.byTooltip('暂停'), findsOneWidget);

    await tester.tap(find.byTooltip('播放队列下一项'));
    await tester.pumpAndSettle();
    expect(engine.loads.last.item.id, _podcast.id);
    expect(find.text('Podcast · 正在播放'), findsOneWidget);
    expect(find.byTooltip('播放队列上一项'), findsOneWidget);

    await tester.tap(find.byTooltip('暂停'));
    await tester.pumpAndSettle();
    expect(find.text('Podcast · 已暂停'), findsOneWidget);

    await tester.tap(find.text('Podcast'));
    await tester.pump();
    expect(playerOpened, isTrue);
    await tester.tap(find.byTooltip('打开收听队列'));
    await tester.pump();
    expect(queueOpened, isTrue);
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
  VoidCallback? onOpenPlayer,
  VoidCallback? onOpenQueue,
}) =>
    MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: GlobalMiniPlayer(
          queue: queue,
          player: player,
          playback: playback,
          onOpenPlayer: onOpenPlayer ?? () {},
          onOpenQueue: onOpenQueue ?? () {},
        ),
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
  title: 'Podcast',
  sourceUri: Uri.parse('https://example.test/podcast/1.mp3'),
);
