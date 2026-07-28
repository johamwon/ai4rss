import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/audio/audio_queue_page.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_data/river_data.dart' hide AudioItem, AudioQueueEntry;
import 'package:river_domain/river_domain.dart';

void main() {
  late RiverDatabase database;
  late PersistentAudioQueue queue;
  late AudioPlaybackController playback;
  late AudioQueuePlaybackCoordinator player;

  setUp(() {
    database = RiverDatabase.inMemory();
    queue = PersistentAudioQueue(
      repository: DriftAudioQueueRepository(database),
      clock: const _Clock(),
    );
    playback = AudioPlaybackController(
      engine: const UnavailableAudioEngine(),
      repository: const UnavailableAudioPlaybackRepository(),
      clock: const _Clock(),
    );
    player = AudioQueuePlaybackCoordinator(
      queue: queue,
      playback: playback,
      resolve: (_) async => null,
    );
  });

  tearDown(() async {
    await player.dispose();
    await playback.dispose();
    await database.close();
  });

  testWidgets('empty queue explains both supported source types',
      (tester) async {
    await tester.pumpWidget(_app(queue, player, playback));
    await tester.pumpAndSettle();

    expect(find.text('收听队列为空'), findsOneWidget);
    expect(find.text('可从文章或 Podcast 分集加入'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('mixed queue can reorder remove and clear transactionally',
      (tester) async {
    await queue.enqueue(_article, contentRevision: 'revision-1');
    await queue.enqueue(_podcast);
    await tester.pumpWidget(_app(queue, player, playback));
    await tester.pumpAndSettle();

    expect(find.text('Article'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    expect(find.text('文章朗读 · 当前'), findsOneWidget);

    await tester.tap(find.byTooltip('上移').last);
    await tester.pumpAndSettle();
    expect(
      (await queue.read()).entries.map((entry) => entry.item.id),
      <String>[_podcast.id, _article.id],
    );

    await tester.tap(find.byTooltip('从队列移除').first);
    await tester.pumpAndSettle();
    expect((await queue.read()).entries.single.item.id, _article.id);

    await tester.tap(find.byTooltip('清空收听队列'));
    await tester.pumpAndSettle();
    expect(find.text('播放断点会保留，之后仍可重新加入。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();
    expect((await queue.read()).entries, isEmpty);
    expect(find.text('收听队列为空'), findsOneWidget);
    await _unmount(tester);
  });
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Widget _app(
  PersistentAudioQueue queue,
  AudioQueuePlaybackCoordinator player,
  AudioPlaybackController playback,
) =>
    MaterialApp(
      home: AudioQueuePage(
        queue: queue,
        player: player,
        playback: playback,
      ),
    );

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 28, 10);
}

final _article = AudioItem(
  id: 'article-1',
  kind: AudioKind.articleTts,
  title: 'Article',
  sourceUri: Uri.parse('https://example.test/article'),
);

final _podcast = AudioItem(
  id: 'podcast-1',
  kind: AudioKind.podcastEpisode,
  title: 'Podcast',
  sourceUri: Uri.parse('https://example.test/podcast.mp3'),
);
