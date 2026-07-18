import 'dart:async';

import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:test/test.dart';

void main() {
  late _MemoryCache cache;
  late _Clock clock;

  setUp(() {
    cache = _MemoryCache();
    clock = _Clock(DateTime.utc(2026, 7, 18, 10));
  });

  test('returns a current cached article without calling the delegate',
      () async {
    cache.entry = _cached(version: '1', etag: 'same');
    final delegate = _Delegate((_) async => _failure());
    final extractor =
        _extractor(delegate: delegate, cache: cache, clock: clock);

    final result = await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        articleId: 'article-1',
        etag: 'same',
      ),
    );

    expect(result, isA<ExtractionSuccess>());
    expect(delegate.calls, 0);
    expect(result.attempts.single.extractor, 'local-cache');
    expect((result as ExtractionSuccess).article.html, '<p>Cached</p>');
  });

  test('coalesces concurrent requests for the same normalized URL', () async {
    final release = Completer<ExtractionResult>();
    final delegate = _Delegate((_) => release.future);
    final extractor =
        _extractor(delegate: delegate, cache: cache, clock: clock);

    final first = extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://EXAMPLE.test:443/article#first'),
        articleId: 'article-1',
        pageHtml: '<main>first</main>',
      ),
    );
    final second = extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article#second'),
        articleId: 'article-1',
        pageHtml: '<main>second</main>',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(identical(first, second), isTrue);
    expect(delegate.calls, 1);
    release.complete(_success(_article()));
    final results =
        await Future.wait(<Future<ExtractionResult>>[first, second]);

    expect(results, everyElement(isA<ExtractionSuccess>()));
    expect(cache.successWrites, 1);
  });

  test('limits global and same-origin extraction concurrency', () async {
    var active = 0;
    var maxActive = 0;
    final activeByHost = <String, int>{};
    final maxByHost = <String, int>{};
    final delegate = _Delegate((request) async {
      active += 1;
      maxActive = active > maxActive ? active : maxActive;
      final host = request.sourceUri.host;
      final hostActive = (activeByHost[host] ?? 0) + 1;
      activeByHost[host] = hostActive;
      final previousHostMax = maxByHost[host] ?? 0;
      maxByHost[host] =
          hostActive > previousHostMax ? hostActive : previousHostMax;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      active -= 1;
      activeByHost[host] = hostActive - 1;
      return _success(_article());
    });
    final extractor =
        _extractor(delegate: delegate, cache: cache, clock: clock);

    await Future.wait(<Future<ExtractionResult>>[
      for (var index = 0; index < 6; index += 1)
        extractor.extract(
          ExtractionRequest(
            sourceUri: Uri.parse('https://a.test/article-$index'),
            pageHtml: '<main>Article $index</main>',
          ),
        ),
      for (var index = 0; index < 4; index += 1)
        extractor.extract(
          ExtractionRequest(
            sourceUri: Uri.parse('https://b.test/article-$index'),
            pageHtml: '<main>Article $index</main>',
          ),
        ),
    ]);

    expect(maxActive, lessThanOrEqualTo(4));
    expect(maxByHost.values, everyElement(lessThanOrEqualTo(2)));
  });

  test('reparses stale extractor versions and stores a SHA-256 hash', () async {
    cache.entry = _cached(version: '0');
    final fresh = _article(html: '<p>Fresh</p>', plainText: 'Fresh');
    final delegate = _Delegate((_) async => _success(fresh));
    final extractor =
        _extractor(delegate: delegate, cache: cache, clock: clock);

    final result = await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        articleId: 'article-1',
        pageHtml: '<main>Fresh</main>',
      ),
    );

    expect(result, isA<ExtractionSuccess>());
    expect(delegate.calls, 1);
    expect(cache.successWrites, 1);
    expect(cache.lastContentHash, hashExtractedContent(fresh));
    expect(cache.lastExtractedAt, clock.value);
  });

  test('reparses when an HTTP validator changes', () async {
    cache.entry = _cached(version: '1', etag: 'old');
    final delegate = _Delegate((_) async => _success(_article()));
    final extractor =
        _extractor(delegate: delegate, cache: cache, clock: clock);

    await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        articleId: 'article-1',
        pageHtml: '<main>Changed</main>',
        etag: 'new',
      ),
    );

    expect(delegate.calls, 1);
    expect(cache.lastEtag, 'new');
  });

  test('keeps stale content readable when forced reparse fails', () async {
    cache.entry = _cached(version: '1');
    final delegate = _Delegate((_) async => _failure());
    final extractor =
        _extractor(delegate: delegate, cache: cache, clock: clock);

    final result = await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        articleId: 'article-1',
        pageHtml: '<main>Unavailable</main>',
        forceReparse: true,
      ),
    );

    expect(result, isA<ExtractionSuccess>());
    expect((result as ExtractionSuccess).article.html, '<p>Cached</p>');
    expect(result.attempts.last.extractor, 'local-cache');
    expect(cache.failureWrites, 1);
    expect(cache.lastFailureCode, ExtractionFailureCode.network);
  });

  test('cache failures do not block successful extraction', () async {
    cache.throwOnRead = true;
    cache.throwOnWrite = true;
    final delegate = _Delegate((_) async => _success(_article()));
    final extractor =
        _extractor(delegate: delegate, cache: cache, clock: clock);

    final result = await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        articleId: 'article-1',
        pageHtml: '<main>Available</main>',
      ),
    );

    expect(result, isA<ExtractionSuccess>());
    expect(delegate.calls, 1);
  });
}

CachedFullTextExtractor _extractor({
  required FullTextExtractor delegate,
  required ExtractionCache cache,
  required Clock clock,
}) =>
    CachedFullTextExtractor(
      delegate: delegate,
      cache: cache,
      clock: clock,
      extractorVersions: const <String, String>{'readability': '1'},
    );

CachedExtraction _cached({required String version, String? etag}) =>
    CachedExtraction(
      articleId: 'article-1',
      article: _article(
        html: '<p>Cached</p>',
        plainText: 'Cached',
        version: version,
      ),
      contentHash: 'cached-hash',
      extractedAt: DateTime.utc(2026, 7, 17),
      etag: etag,
    );

ExtractedArticle _article({
  String html = '<p>Article</p>',
  String plainText = 'Article',
  String version = '1',
}) =>
    ExtractedArticle(
      title: 'Article',
      html: html,
      plainText: plainText,
      extractor: 'readability',
      extractorVersion: version,
      canonicalUri: Uri.parse('https://example.test/article'),
    );

ExtractionSuccess _success(ExtractedArticle article) => ExtractionSuccess(
      article: article,
      attempts: <ExtractionAttempt>[
        ExtractionAttempt(
          extractor: article.extractor,
          extractorVersion: article.extractorVersion,
          outcome: ExtractionAttemptOutcome.succeeded,
        ),
      ],
    );

ExtractionFailureResult _failure() => const ExtractionFailureResult(
      failure: ExtractionFailure(
        code: ExtractionFailureCode.network,
        message: 'Synthetic network failure.',
        retryable: true,
      ),
      attempts: <ExtractionAttempt>[
        ExtractionAttempt(
          extractor: 'readability',
          extractorVersion: '1',
          outcome: ExtractionAttemptOutcome.failed,
          failureCode: ExtractionFailureCode.network,
        ),
      ],
    );

final class _Delegate implements FullTextExtractor {
  _Delegate(this.operation);

  final Future<ExtractionResult> Function(ExtractionRequest request) operation;
  var calls = 0;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) {
    calls += 1;
    return operation(request);
  }
}

final class _MemoryCache implements ExtractionCache {
  CachedExtraction? entry;
  var successWrites = 0;
  var failureWrites = 0;
  var throwOnRead = false;
  var throwOnWrite = false;
  String? lastContentHash;
  DateTime? lastExtractedAt;
  String? lastEtag;
  ExtractionFailureCode? lastFailureCode;

  @override
  Future<CachedExtraction?> read({
    required Uri sourceUri,
    String? articleId,
  }) async {
    if (throwOnRead) throw StateError('synthetic cache read failure');
    return entry;
  }

  @override
  Future<void> writeFailure({
    required String articleId,
    required ExtractionFailureCode failureCode,
    required String extractorVersion,
    required DateTime attemptedAt,
    String? etag,
    String? lastModified,
  }) async {
    failureWrites += 1;
    lastFailureCode = failureCode;
    if (throwOnWrite) throw StateError('synthetic cache write failure');
  }

  @override
  Future<void> writeSuccess({
    required String articleId,
    required ExtractedArticle article,
    required String contentHash,
    required DateTime extractedAt,
    String? etag,
    String? lastModified,
  }) async {
    successWrites += 1;
    lastContentHash = contentHash;
    lastExtractedAt = extractedAt;
    lastEtag = etag;
    if (throwOnWrite) throw StateError('synthetic cache write failure');
  }
}

final class _Clock implements Clock {
  _Clock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
