import 'dart:async';
import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import 'job_queue.dart';

typedef OfflineArticleLoader =
    Future<FeedArticleDetailRecord?> Function(String articleId);

final class DurableOfflineArticleManager implements OfflineArticleManager {
  DurableOfflineArticleManager({
    required PersistentJobQueue jobs,
    required OfflineArticleLoader loadArticle,
    required FullTextExtractor extractor,
    required NetworkMonitor network,
    required Clock clock,
    required IdGenerator ids,
    this.maxAttempts = 5,
    this.leaseDuration = const Duration(minutes: 3),
    this.retryBaseDelay = const Duration(seconds: 30),
    this.maxRetryDelay = const Duration(minutes: 15),
  }) : assert(maxAttempts > 0),
       assert(!retryBaseDelay.isNegative),
       assert(!maxRetryDelay.isNegative),
       _jobs = jobs,
       _loadArticle = loadArticle,
       _extractor = extractor,
       _network = network,
       _clock = clock,
       _ids = ids;

  static const jobType = 'article-offline/v1';
  static const _idempotencyPrefix = 'article-offline:v1:';

  final PersistentJobQueue _jobs;
  final OfflineArticleLoader _loadArticle;
  final FullTextExtractor _extractor;
  final NetworkMonitor _network;
  final Clock _clock;
  final IdGenerator _ids;
  final int maxAttempts;
  final Duration leaseDuration;
  final Duration retryBaseDelay;
  final Duration maxRetryDelay;
  final StreamController<OfflineArticleState> _changes =
      StreamController<OfflineArticleState>.broadcast(sync: true);

  StreamSubscription<NetworkAvailability>? _networkSubscription;
  Future<void>? _activeRun;
  Timer? _retryTimer;
  DateTime? _retryAt;
  var _started = false;
  var _closed = false;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _networkSubscription = _network.changes.listen((availability) {
      if (availability.mayAttemptRequest) {
        unawaited(resumePending());
      }
    }, onError: (_, __) => unawaited(resumePending()));
    await resumePending();
  }

  @override
  Stream<OfflineArticleState> watch(String articleId) async* {
    final normalized = _normalizeArticleId(articleId);
    yield await status(normalized);
    yield* _changes.stream.where((state) => state.articleId == normalized);
  }

  @override
  Future<OfflineArticleState> status(String articleId) async {
    final normalized = _normalizeArticleId(articleId);
    final job = await _jobs.findByIdempotencyKey(_idempotencyKey(normalized));
    if (job == null) return OfflineArticleState.notDownloaded(normalized);
    return _stateForJob(normalized, job);
  }

  @override
  Future<void> enqueue(String articleId) async {
    final normalized = _normalizeArticleId(articleId);
    final now = _clock.now().toUtc();
    final inserted = await _jobs.enqueue(
      NewDurableJob(
        id: _ids.next(),
        type: jobType,
        idempotencyKey: _idempotencyKey(normalized),
        payloadJson: jsonEncode(<String, String>{'articleId': normalized}),
        availableAt: now,
        maxAttempts: maxAttempts,
      ),
      now,
    );
    if (inserted) {
      _emit(
        OfflineArticleState(
          articleId: normalized,
          phase: OfflineArticlePhase.queued,
        ),
      );
    } else {
      _emit(await status(normalized));
    }
    await resumePending();
  }

  @override
  Future<void> retry(String articleId) async {
    final normalized = _normalizeArticleId(articleId);
    final retried = await _jobs.retryFailed(
      idempotencyKey: _idempotencyKey(normalized),
      now: _clock.now().toUtc(),
    );
    if (!retried) return;
    _emit(
      OfflineArticleState(
        articleId: normalized,
        phase: OfflineArticlePhase.queued,
      ),
    );
    await resumePending();
  }

  @override
  Future<void> resumePending() {
    if (_closed) return Future<void>.value();
    final active = _activeRun;
    if (active != null) return active;
    late final Future<void> tracked;
    tracked = _resumePending().whenComplete(() {
      if (identical(_activeRun, tracked)) _activeRun = null;
    });
    _activeRun = tracked;
    return tracked;
  }

  Future<void> _resumePending() async {
    final availability = await _safeAvailability();
    if (availability.isOffline || _closed) return;
    var now = _clock.now().toUtc();
    await _jobs.recoverExpiredLeases(now, typePrefix: jobType);
    while (!_closed) {
      final claimed = await _jobs.claimNext(
        now: now,
        leaseDuration: leaseDuration,
        type: jobType,
      );
      if (claimed == null) return;
      await _process(claimed);
      now = _clock.now().toUtc();
    }
  }

  Future<void> _process(ClaimedDurableJob job) async {
    final articleId = _decodeArticleId(job.payloadJson);
    if (articleId == null) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'invalid_payload',
        now: _clock.now().toUtc(),
      );
      return;
    }
    _emit(
      OfflineArticleState(
        articleId: articleId,
        phase: OfflineArticlePhase.downloading,
      ),
    );
    FeedArticleDetailRecord? detail;
    try {
      detail = await _loadArticle(articleId);
    } on Object {
      await _failOrRetry(job, articleId, 'article_load_failed');
      return;
    }
    if (detail == null) {
      await _failPermanently(job, articleId, 'article_missing');
      return;
    }

    ExtractionResult result;
    try {
      result = await _extractor.extract(
        ExtractionRequest(
          sourceUri: detail.canonicalUrl,
          articleId: detail.id,
          feedContentHtml: detail.feedContentHtml,
          feedSummary: detail.summary,
          title: detail.title,
          author: detail.author,
          publishedAt: detail.publishedAt,
        ),
      );
    } on Object {
      await _failOrRetry(job, articleId, 'unexpected');
      return;
    }

    switch (result) {
      case ExtractionSuccess():
        await _jobs.complete(job.id, _clock.now().toUtc());
        _emit(
          OfflineArticleState(
            articleId: articleId,
            phase: OfflineArticlePhase.available,
          ),
        );
      case ExtractionFailureResult(:final failure):
        if (failure.retryable) {
          await _failOrRetry(job, articleId, failure.code.name);
        } else {
          await _failPermanently(job, articleId, failure.code.name);
        }
    }
  }

  Future<void> _failOrRetry(
    ClaimedDurableJob job,
    String articleId,
    String errorCode,
  ) async {
    final status = await _jobs.failOrRetry(
      id: job.id,
      errorCode: errorCode,
      now: _clock.now().toUtc(),
      retryDelay: _retryDelay(job.attempt),
    );
    _emit(
      OfflineArticleState(
        articleId: articleId,
        phase: status == DurableJobStatus.failed
            ? OfflineArticlePhase.failed
            : OfflineArticlePhase.queued,
        failureCode: errorCode,
      ),
    );
    if (status == DurableJobStatus.queued) {
      _scheduleRetry(_retryDelay(job.attempt));
    }
  }

  Future<void> _failPermanently(
    ClaimedDurableJob job,
    String articleId,
    String errorCode,
  ) async {
    await _jobs.failPermanently(
      id: job.id,
      errorCode: errorCode,
      now: _clock.now().toUtc(),
    );
    _emit(
      OfflineArticleState(
        articleId: articleId,
        phase: OfflineArticlePhase.failed,
        failureCode: errorCode,
      ),
    );
  }

  Future<NetworkAvailability> _safeAvailability() async {
    try {
      return await _network.check();
    } on Object {
      return NetworkAvailability.unknown;
    }
  }

  Duration _retryDelay(int attempt) {
    final exponent = (attempt - 1).clamp(0, 5).toInt();
    final candidate = retryBaseDelay * (1 << exponent);
    return candidate > maxRetryDelay ? maxRetryDelay : candidate;
  }

  void _scheduleRetry(Duration delay) {
    final retryAt = _clock.now().toUtc().add(delay);
    final scheduled = _retryAt;
    if (scheduled != null && !retryAt.isBefore(scheduled)) return;
    _retryTimer?.cancel();
    _retryAt = retryAt;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _retryAt = null;
      unawaited(resumePending());
    });
  }

  OfflineArticleState _stateForJob(String articleId, DurableJobRecord job) =>
      OfflineArticleState(
        articleId: articleId,
        phase: switch (job.status) {
          DurableJobStatus.queued => OfflineArticlePhase.queued,
          DurableJobStatus.running => OfflineArticlePhase.downloading,
          DurableJobStatus.completed => OfflineArticlePhase.available,
          DurableJobStatus.failed => OfflineArticlePhase.failed,
          DurableJobStatus.cancelled => OfflineArticlePhase.notDownloaded,
        },
        failureCode: job.lastErrorCode,
      );

  void _emit(OfflineArticleState state) {
    if (!_closed) _changes.add(state);
  }

  String _normalizeArticleId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 512) {
      throw ArgumentError.value(value, 'articleId', 'Invalid article ID.');
    }
    return normalized;
  }

  String _idempotencyKey(String articleId) => '$_idempotencyPrefix$articleId';

  String? _decodeArticleId(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final value = decoded['articleId'];
      if (value is! String) return null;
      return _normalizeArticleId(value);
    } on Object {
      return null;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAt = null;
    await _networkSubscription?.cancel();
    await _activeRun;
    await _changes.close();
  }
}
