import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('flight mode keeps a durable job and connectivity resumes it', () async {
    final database = RiverDatabase(NativeDatabase.memory());
    final network = _FakeNetwork(NetworkAvailability.offline);
    var extractionCalls = 0;
    final manager = DurableOfflineArticleManager(
      jobs: PersistentJobQueue(database),
      loadArticle: (_) async => _detail(),
      extractor: _Extractor((_) async {
        extractionCalls += 1;
        return _success();
      }),
      network: network,
      clock: const _Clock(),
      ids: _Ids(),
    );
    addTearDown(() async {
      await manager.close();
      await network.close();
      await database.close();
    });

    await manager.start();
    await manager.enqueue('article-1');

    expect(extractionCalls, 0);
    expect(
      (await manager.status('article-1')).phase,
      OfflineArticlePhase.queued,
    );

    final available = manager
        .watch('article-1')
        .firstWhere((state) => state.phase == OfflineArticlePhase.available);
    network.emit(NetworkAvailability.online);

    expect((await available).phase, OfflineArticlePhase.available);
    expect(extractionCalls, 1);
  });

  test('terminal failure can be retried with a fresh attempt budget', () async {
    final database = RiverDatabase(NativeDatabase.memory());
    final network = _FakeNetwork(NetworkAvailability.online);
    var extractionCalls = 0;
    final manager = DurableOfflineArticleManager(
      jobs: PersistentJobQueue(database),
      loadArticle: (_) async => _detail(),
      extractor: _Extractor((_) async {
        extractionCalls += 1;
        if (extractionCalls == 1) {
          return const ExtractionFailureResult(
            failure: ExtractionFailure(
              code: ExtractionFailureCode.network,
              message: 'private transport detail',
              retryable: true,
            ),
            attempts: <ExtractionAttempt>[],
          );
        }
        return _success();
      }),
      network: network,
      clock: const _Clock(),
      ids: _Ids(),
      maxAttempts: 1,
    );
    addTearDown(() async {
      await manager.close();
      await network.close();
      await database.close();
    });

    await manager.start();
    await manager.enqueue('article-1');
    final failed = await manager.status('article-1');
    expect(failed.phase, OfflineArticlePhase.failed);
    expect(failed.failureCode, 'network');

    await manager.retry('article-1');

    expect(
      (await manager.status('article-1')).phase,
      OfflineArticlePhase.available,
    );
    expect(extractionCalls, 2);
  });

  test(
    'retryable work uses its durable attempt budget before succeeding',
    () async {
      final database = RiverDatabase(NativeDatabase.memory());
      final network = _FakeNetwork(NetworkAvailability.online);
      var extractionCalls = 0;
      final manager = DurableOfflineArticleManager(
        jobs: PersistentJobQueue(database),
        loadArticle: (_) async => _detail(),
        extractor: _Extractor((_) async {
          extractionCalls += 1;
          if (extractionCalls == 1) {
            return const ExtractionFailureResult(
              failure: ExtractionFailure(
                code: ExtractionFailureCode.timeout,
                message: 'private timeout detail',
                retryable: true,
              ),
              attempts: <ExtractionAttempt>[],
            );
          }
          return _success();
        }),
        network: network,
        clock: const _Clock(),
        ids: _Ids(),
        maxAttempts: 2,
        retryBaseDelay: Duration.zero,
      );
      addTearDown(() async {
        await manager.close();
        await network.close();
        await database.close();
      });

      await manager.start();
      await manager.enqueue('article-1');

      expect(
        (await manager.status('article-1')).phase,
        OfflineArticlePhase.available,
      );
      expect(extractionCalls, 2);
    },
  );

  test(
    'downloaded article remains readable after a cold database reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'river-offline-article-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}river.sqlite',
      );
      final network = _FakeNetwork(NetworkAvailability.online);
      var database = RiverDatabase(NativeDatabase(file));
      final manager = await _buildCachingManager(database, network);

      await manager.start();
      await manager.enqueue('article-1');
      await manager.close();
      await database.close();

      database = RiverDatabase(NativeDatabase(file));
      final restored = await DriftFeedRepository(
        database,
      ).watchArticle('article-1').first;

      expect(restored, isNotNull);
      expect(restored!.content?.plainText, 'Downloaded full article');
      expect(restored.content?.isReadable, isTrue);

      await database.close();
      await network.close();
      await directory.delete(recursive: true);
    },
  );
}

Future<DurableOfflineArticleManager> _buildCachingManager(
  RiverDatabase database,
  NetworkMonitor network,
) async {
  final repository = DriftFeedRepository(database);
  final now = DateTime.utc(2026, 7, 26, 8);
  await repository.applyRefresh(
    feedId: 'feed-1',
    canonicalUrl: Uri.parse('https://example.test/feed.xml'),
    feed: const ParsedFeed(
      kind: FeedDocumentKind.rss,
      title: 'Example',
      items: <ParsedFeedItem>[],
    ),
    articles: <FeedArticleDraft>[
      FeedArticleDraft(
        id: 'article-1',
        canonicalUrl: Uri.parse('https://example.test/article'),
        title: 'Offline article',
        summary: 'Short preview',
      ),
    ],
    refreshedAt: now,
  );
  final cached = CachedFullTextExtractor(
    delegate: _Extractor((_) async => _success()),
    cache: DriftExtractionCache(database),
    clock: const _Clock(),
    extractorVersions: const <String, String>{'readability': '1'},
  );
  return DurableOfflineArticleManager(
    jobs: PersistentJobQueue(database),
    loadArticle: (articleId) => repository.watchArticle(articleId).first,
    extractor: cached,
    network: network,
    clock: const _Clock(),
    ids: _Ids(),
  );
}

FeedArticleDetailRecord _detail() => FeedArticleDetailRecord(
  id: 'article-1',
  feedId: 'feed-1',
  feedTitle: 'Example',
  canonicalUrl: Uri.parse('https://example.test/article'),
  title: 'Offline article',
  read: false,
  starred: false,
  readLater: false,
  scrollDepth: 0,
  activeReadSeconds: 0,
  summary: 'Short preview',
);

ExtractionSuccess _success() => ExtractionSuccess(
  article: const ExtractedArticle(
    title: 'Offline article',
    html: '<p>Downloaded full article</p>',
    plainText: 'Downloaded full article',
    extractor: 'readability',
    extractorVersion: '1',
  ),
  attempts: const <ExtractionAttempt>[
    ExtractionAttempt(
      extractor: 'readability',
      extractorVersion: '1',
      outcome: ExtractionAttemptOutcome.succeeded,
    ),
  ],
);

final class _Extractor implements FullTextExtractor {
  const _Extractor(this.operation);

  final Future<ExtractionResult> Function(ExtractionRequest request) operation;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) =>
      operation(request);
}

final class _FakeNetwork implements NetworkMonitor {
  _FakeNetwork(this.current);

  NetworkAvailability current;
  final StreamController<NetworkAvailability> _changes =
      StreamController<NetworkAvailability>();

  @override
  Future<NetworkAvailability> check() async => current;

  @override
  Stream<NetworkAvailability> get changes => _changes.stream;

  void emit(NetworkAvailability value) {
    current = value;
    _changes.add(value);
  }

  Future<void> close() => _changes.close();
}

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 26, 8);
}

final class _Ids implements IdGenerator {
  var value = 0;

  @override
  String next() => 'offline-job-${++value}';
}
