import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart' as domain;
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftAudioQueueRepository repository;

  setUp(() {
    database = RiverDatabase.inMemory();
    repository = DriftAudioQueueRepository(database);
  });

  tearDown(() => database.close());

  test('article and Podcast share one durable deduplicated order', () async {
    final snapshots = <domain.AudioQueueSnapshot>[];
    final subscription = repository.watch().listen(snapshots.add);

    expect(
      await repository.enqueue(
        item: _article,
        contentRevision: 'sha256:article-v1',
        enqueuedAt: _time(0),
      ),
      isTrue,
    );
    expect(
      await repository.enqueue(
        item: _podcast,
        contentRevision: null,
        enqueuedAt: _time(1),
      ),
      isTrue,
    );
    expect(
      await repository.enqueue(
        item: _article,
        contentRevision: 'sha256:article-v2',
        enqueuedAt: _time(2),
      ),
      isFalse,
    );

    final queue = await repository.read();
    expect(queue.entries.map((entry) => entry.item.id), <String>[
      _article.id,
      _podcast.id,
    ]);
    expect(queue.entries.map((entry) => entry.position), <int>[0, 1]);
    expect(queue.current?.item.id, _article.id);
    expect(queue.entries.first.contentRevision, 'sha256:article-v1');
    expect(queue.entries.last.contentRevision, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(snapshots.last.entries, hasLength(2));

    await subscription.cancel();
  });

  test(
    'move select and remove preserve one deterministic current item',
    () async {
      await _seed(repository);
      await repository.move(
        itemId: _third.id,
        targetIndex: 0,
        updatedAt: _time(3),
      );
      await repository.select(itemId: _podcast.id, updatedAt: _time(4));

      var queue = await repository.read();
      expect(queue.entries.map((entry) => entry.item.id), <String>[
        _third.id,
        _article.id,
        _podcast.id,
      ]);
      expect(queue.current?.item.id, _podcast.id);
      expect(queue.entries.where((entry) => entry.isCurrent), hasLength(1));

      await repository.remove(itemId: _podcast.id, updatedAt: _time(5));
      queue = await repository.read();
      expect(queue.entries.map((entry) => entry.item.id), <String>[
        _third.id,
        _article.id,
      ]);
      expect(queue.current?.item.id, _article.id);

      await repository.remove(itemId: _third.id, updatedAt: _time(6));
      expect((await repository.read()).current?.item.id, _article.id);
    },
  );

  test('consuming current advances and removes it atomically', () async {
    await _seed(repository);
    await repository.select(itemId: _podcast.id, updatedAt: _time(3));

    final consumed = await repository.consumeCurrent(updatedAt: _time(4));
    expect(consumed?.item.id, _podcast.id);
    final queue = await repository.read();
    expect(queue.entries.map((entry) => entry.item.id), <String>[
      _article.id,
      _third.id,
    ]);
    expect(queue.current?.item.id, _third.id);
    expect(queue.entries.map((entry) => entry.position), <int>[0, 1]);
  });

  test('queue order and current item survive a process restart', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('river-queue-');
    final file = File('${directory.path}${Platform.pathSeparator}river.db');
    database = RiverDatabase(NativeDatabase(file));
    repository = DriftAudioQueueRepository(database);
    await _seed(repository);
    await repository.move(
      itemId: _third.id,
      targetIndex: 0,
      updatedAt: _time(3),
    );
    await repository.select(itemId: _podcast.id, updatedAt: _time(4));
    await database.close();

    database = RiverDatabase(NativeDatabase(file));
    repository = DriftAudioQueueRepository(database);
    final restored = await repository.read();
    expect(restored.entries.map((entry) => entry.item.id), <String>[
      _third.id,
      _article.id,
      _podcast.id,
    ]);
    expect(restored.current?.item.id, _podcast.id);

    await database.close();
    await directory.delete(recursive: true);
    database = RiverDatabase.inMemory();
  });

  test(
    'invalid candidates and corrupt rows cannot escape the repository',
    () async {
      expect(
        () => repository.enqueue(
          item: _article,
          contentRevision: null,
          enqueuedAt: _time(0),
        ),
        throwsArgumentError,
      );
      await database.customStatement('''
      INSERT INTO audio_queue_entries (
        item_id, kind, title, source_uri, content_revision, queue_position,
        is_current, enqueued_at, updated_at
      ) VALUES (
        'corrupt', 'unknown', '', 'not a uri', NULL, -4, 1,
        1784995200, 1784995200
      )
    ''');
      expect((await repository.read()).entries, isEmpty);
    },
  );
}

Future<void> _seed(DriftAudioQueueRepository repository) async {
  await repository.enqueue(
    item: _article,
    contentRevision: 'sha256:article-v1',
    enqueuedAt: _time(0),
  );
  await repository.enqueue(
    item: _podcast,
    contentRevision: null,
    enqueuedAt: _time(1),
  );
  await repository.enqueue(
    item: _third,
    contentRevision: 'sha256:article-v3',
    enqueuedAt: _time(2),
  );
}

DateTime _time(int minute) => DateTime.utc(2026, 7, 28, 10, minute);

final _article = domain.AudioItem(
  id: 'article-1',
  kind: domain.AudioKind.articleTts,
  title: 'Article',
  sourceUri: Uri.parse('https://example.test/articles/1'),
);

final _podcast = domain.AudioItem(
  id: 'podcast-1',
  kind: domain.AudioKind.podcastEpisode,
  title: 'Podcast',
  sourceUri: Uri.parse('https://example.test/podcast/1.mp3'),
);

final _third = domain.AudioItem(
  id: 'article-3',
  kind: domain.AudioKind.articleTts,
  title: 'Third',
  sourceUri: Uri.parse('https://example.test/articles/3'),
);
