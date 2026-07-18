import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

final class CachedFullTextExtractor implements FullTextExtractor {
  CachedFullTextExtractor({
    required FullTextExtractor delegate,
    required ExtractionCache cache,
    required Clock clock,
    required Map<String, String> extractorVersions,
    this.maxConcurrent = 4,
    this.maxPerOrigin = 2,
  })  : _delegate = delegate,
        _cache = cache,
        _clock = clock,
        _extractorVersions = Map<String, String>.unmodifiable(
          extractorVersions,
        ),
        _globalPool = _PermitPool(maxConcurrent),
        assert(extractorVersions.isNotEmpty),
        assert(maxConcurrent > 0),
        assert(maxPerOrigin > 0);

  static const cacheExtractor = 'local-cache';
  static const cacheVersion = '1';

  final FullTextExtractor _delegate;
  final ExtractionCache _cache;
  final Clock _clock;
  final Map<String, String> _extractorVersions;
  final int maxConcurrent;
  final int maxPerOrigin;
  final _PermitPool _globalPool;
  final Map<String, _OriginPermitPool> _originPools =
      <String, _OriginPermitPool>{};
  final Map<String, Future<ExtractionResult>> _inFlight =
      <String, Future<ExtractionResult>>{};

  String get versionFingerprint {
    final entries = _extractorVersions.entries.toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries.map((entry) => '${entry.key}@${entry.value}').join('|');
  }

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) {
    final key = _operationKey(request.sourceUri);
    final active = _inFlight[key];
    if (active != null) return active;

    final completer = Completer<ExtractionResult>();
    _inFlight[key] = completer.future;
    unawaited(_complete(request: request, key: key, completer: completer));
    return completer.future;
  }

  Future<void> _complete({
    required ExtractionRequest request,
    required String key,
    required Completer<ExtractionResult> completer,
  }) async {
    try {
      completer.complete(await _run(request));
    } on Object {
      completer.complete(
        const ExtractionFailureResult(
          failure: ExtractionFailure(
            code: ExtractionFailureCode.unexpected,
            message: 'The cached extraction operation failed unexpectedly.',
            retryable: true,
          ),
          attempts: <ExtractionAttempt>[],
        ),
      );
    } finally {
      if (identical(_inFlight[key], completer.future)) {
        unawaited(_inFlight.remove(key));
      }
    }
  }

  Future<ExtractionResult> _run(ExtractionRequest request) async {
    final cached = await _readCache(request);
    final cacheIsCurrent = cached != null &&
        _extractorVersions[cached.article.extractor] ==
            cached.article.extractorVersion;
    final validatorsChanged =
        cached != null && _validatorsChanged(request: request, cached: cached);

    if (cached != null &&
        cacheIsCurrent &&
        !validatorsChanged &&
        !request.forceReparse) {
      return _cacheSuccess(cached);
    }

    final originKey = _originKey(request.sourceUri);
    final origin = _originPools.putIfAbsent(
      originKey,
      () => _OriginPermitPool(_PermitPool(maxPerOrigin)),
    );
    origin.references += 1;
    late final ExtractionResult result;
    try {
      result = await origin.pool.run(
        () => _globalPool.run(() => _delegate.extract(request)),
      );
    } finally {
      origin.references -= 1;
      if (origin.references == 0 &&
          identical(_originPools[originKey], origin)) {
        _originPools.remove(originKey);
      }
    }
    switch (result) {
      case ExtractionSuccess(:final article):
        final contentHash = hashExtractedContent(article);
        await _writeSuccess(
          request: request,
          article: article,
          contentHash: contentHash,
        );
        return result;
      case ExtractionFailureResult(:final failure):
        await _writeFailure(request: request, failure: failure);
        if (cached != null) {
          return ExtractionSuccess(
            article: cached.article,
            attempts: <ExtractionAttempt>[
              ...result.attempts,
              const ExtractionAttempt(
                extractor: cacheExtractor,
                extractorVersion: cacheVersion,
                outcome: ExtractionAttemptOutcome.succeeded,
              ),
            ],
          );
        }
        return result;
    }
  }

  Future<CachedExtraction?> _readCache(ExtractionRequest request) async {
    try {
      return await _cache.read(
        sourceUri: request.sourceUri,
        articleId: request.articleId,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _writeSuccess({
    required ExtractionRequest request,
    required ExtractedArticle article,
    required String contentHash,
  }) async {
    final articleId = request.articleId;
    if (articleId == null) return;
    try {
      await _cache.writeSuccess(
        articleId: articleId,
        article: article,
        contentHash: contentHash,
        extractedAt: _clock.now().toUtc(),
        etag: request.etag,
        lastModified: request.lastModified,
      );
    } on Object {
      // A cache write must never make successfully extracted content unreadable.
    }
  }

  Future<void> _writeFailure({
    required ExtractionRequest request,
    required ExtractionFailure failure,
  }) async {
    final articleId = request.articleId;
    if (articleId == null) return;
    try {
      await _cache.writeFailure(
        articleId: articleId,
        failureCode: failure.code,
        extractorVersion: versionFingerprint,
        attemptedAt: _clock.now().toUtc(),
        etag: request.etag,
        lastModified: request.lastModified,
      );
    } on Object {
      // Classified extraction failures remain usable when persistence is down.
    }
  }
}

String hashExtractedContent(ExtractedArticle article) =>
    sha256.convert(utf8.encode(article.html)).toString();

ExtractionSuccess _cacheSuccess(CachedExtraction cached) => ExtractionSuccess(
      article: cached.article,
      attempts: const <ExtractionAttempt>[
        ExtractionAttempt(
          extractor: CachedFullTextExtractor.cacheExtractor,
          extractorVersion: CachedFullTextExtractor.cacheVersion,
          outcome: ExtractionAttemptOutcome.succeeded,
        ),
      ],
    );

bool _validatorsChanged({
  required ExtractionRequest request,
  required CachedExtraction cached,
}) {
  final requestEtag = request.etag;
  if (requestEtag != null && requestEtag != cached.etag) return true;
  final requestLastModified = request.lastModified;
  return requestLastModified != null &&
      requestLastModified != cached.lastModified;
}

String _operationKey(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final defaultPort = switch (scheme) {
    'http' => 80,
    'https' => 443,
    _ => null,
  };
  return Uri(
    scheme: scheme,
    userInfo: uri.userInfo,
    host: uri.host.toLowerCase(),
    port: uri.hasPort && uri.port != defaultPort ? uri.port : null,
    path: uri.path.isEmpty ? '/' : uri.path,
    query: uri.hasQuery ? uri.query : null,
  ).toString();
}

String _originKey(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final defaultPort = switch (scheme) {
    'http' => 80,
    'https' => 443,
    _ => 0,
  };
  final port = uri.hasPort ? uri.port : defaultPort;
  return '$scheme://${uri.host.toLowerCase()}:$port';
}

final class _PermitPool {
  _PermitPool(this.limit);

  final int limit;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  var _active = 0;

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_active >= limit) {
      final waiter = Completer<void>();
      _waiters.addLast(waiter);
      await waiter.future;
    }
    _active += 1;
    try {
      return await operation();
    } finally {
      _active -= 1;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }
}

final class _OriginPermitPool {
  _OriginPermitPool(this.pool);

  final _PermitPool pool;
  var references = 0;
}
