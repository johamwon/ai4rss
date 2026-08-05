import 'dart:async';
import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:river_data/river_data.dart' hide Article;
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import '../app/article_summary.dart';
import 'personalized_articles.dart';

typedef AutomaticSummaryArticleLoader = Future<FeedArticleDetailRecord?>
    Function(String articleId);
typedef AutomaticSummaryDayKey = String Function(DateTime now);
typedef AutomaticSummaryNextDay = DateTime Function(DateTime now);

final class AutomaticSummaryDashboard {
  const AutomaticSummaryDashboard({
    required this.settings,
    required this.usage,
  });

  final AutomaticSummarySettings settings;
  final AutomaticSummaryUsageSnapshot usage;

  int get remaining =>
      (settings.dailyLimit - usage.consumed).clamp(0, settings.dailyLimit);
}

abstract interface class AutomaticSummaryExperience {
  Future<AutomaticSummaryDashboard> loadDashboard();
  Future<void> updateSettings(AutomaticSummarySettings settings);
}

final class DurableAutomaticSummaryManager
    implements AutomaticSummaryExperience {
  DurableAutomaticSummaryManager({
    required PersistentJobQueue jobs,
    required AutomaticSummaryRepository repository,
    required AutomaticSummaryArticleLoader loadArticle,
    required ArticleSummaryExperience summaries,
    required AutomaticSummaryNetworkMonitor network,
    required Clock clock,
    required IdGenerator ids,
    FullTextExtractor? extractor,
    AutomaticSummaryDayKey? dayKey,
    AutomaticSummaryNextDay? nextDay,
    this.maxAttempts = 3,
    this.leaseDuration = const Duration(minutes: 5),
    this.networkRetryDelay = const Duration(minutes: 5),
    this.providerRetryDelay = const Duration(minutes: 2),
  })  : _jobs = jobs,
        _repository = repository,
        _loadArticle = loadArticle,
        _summaries = summaries,
        _network = network,
        _clock = clock,
        _ids = ids,
        _extractor = extractor,
        _dayKey = dayKey ?? automaticSummaryLocalDayKey,
        _nextDay = nextDay ?? automaticSummaryNextLocalDay {
    if (maxAttempts < 1 ||
        leaseDuration <= Duration.zero ||
        networkRetryDelay.isNegative ||
        providerRetryDelay.isNegative) {
      throw ArgumentError('Invalid automatic summary manager bounds.');
    }
  }

  static const jobType = 'automatic-summary/v1';
  static const _jobPrefix = 'automatic-summary:v1:';
  static const _usagePrefix = 'automatic-summary-usage:v1:';

  final PersistentJobQueue _jobs;
  final AutomaticSummaryRepository _repository;
  final AutomaticSummaryArticleLoader _loadArticle;
  final ArticleSummaryExperience _summaries;
  final AutomaticSummaryNetworkMonitor _network;
  final Clock _clock;
  final IdGenerator _ids;
  final FullTextExtractor? _extractor;
  final AutomaticSummaryDayKey _dayKey;
  final AutomaticSummaryNextDay _nextDay;
  final int maxAttempts;
  final Duration leaseDuration;
  final Duration networkRetryDelay;
  final Duration providerRetryDelay;

  StreamSubscription<AutomaticSummaryNetworkKind>? _networkSubscription;
  Future<void>? _activeRun;
  Timer? _retryTimer;
  DateTime? _retryAt;
  var _started = false;
  var _closed = false;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _networkSubscription = _network.changes.listen(
      (kind) {
        if (kind != AutomaticSummaryNetworkKind.offline) {
          unawaited(_resumeAfterNetworkChange());
        }
      },
      onError: (_, __) {},
    );
    await resumePending();
  }

  Future<int> schedule(PersonalizedArticleListSnapshot snapshot) async {
    if (_closed || !snapshot.personalized) return 0;
    final settings = await _repository.readSettings();
    if (!settings.enabled) return 0;
    settings.validate();
    var inserted = 0;
    for (final article in snapshot.articles) {
      if (inserted >= settings.dailyLimit || article.read) continue;
      final explanation = snapshot.explanations[article.id];
      if (explanation == null ||
          explanation.score < settings.minimumRankingScore) {
        continue;
      }
      final detail = await _safeLoad(article.id);
      if (detail == null) continue;
      final summaryArticle = _summaryArticle(detail);
      final expectedContentHash = summaryArticle == null
          ? null
          : summaryContentHash(summaryArticle.plainText!);
      final revision =
          expectedContentHash ?? 'extract:${explanation.rankingModelVersion}';
      final jobKey = '$_jobPrefix${article.id}:$revision';
      final now = _clock.now().toUtc();
      if (await _jobs.enqueue(
        NewDurableJob(
          id: _ids.next(),
          type: jobType,
          idempotencyKey: jobKey,
          payloadJson: jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'articleId': article.id,
            'contentHash': expectedContentHash,
            'rankingScore': explanation.score,
            'rankingModelVersion': explanation.rankingModelVersion,
          }),
          availableAt: now,
          maxAttempts: maxAttempts,
        ),
        now,
      )) {
        inserted += 1;
      }
    }
    if (inserted > 0) await resumePending();
    return inserted;
  }

  @override
  Future<AutomaticSummaryDashboard> loadDashboard() async {
    final now = _clock.now();
    final settings = await _repository.readSettings();
    return AutomaticSummaryDashboard(
      settings: settings,
      usage: await _repository.readUsage(_dayKey(now)),
    );
  }

  @override
  Future<void> updateSettings(AutomaticSummarySettings settings) async {
    settings.validate();
    final now = _clock.now().toUtc();
    await _repository.saveSettings(settings, updatedAt: now);
    if (!settings.enabled) {
      await _jobs.cancelType(jobType, now);
      return;
    }
    await resumePending();
  }

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
    final payload = _decodePayload(job.payloadJson);
    final now = _clock.now().toUtc();
    if (payload == null) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'invalid_payload',
        now: now,
      );
      return;
    }
    final settings = await _repository.readSettings();
    if (!settings.enabled ||
        payload.rankingScore < settings.minimumRankingScore) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'policy_disabled',
        now: now,
      );
      return;
    }
    final network = await _safeNetwork();
    if (network == AutomaticSummaryNetworkKind.offline ||
        (settings.wifiOnly && network != AutomaticSummaryNetworkKind.wifi)) {
      await _defer(
        job,
        network == AutomaticSummaryNetworkKind.offline
            ? 'offline'
            : 'wifi_required',
        now.add(networkRetryDelay),
      );
      return;
    }
    final detail = await _safeLoad(payload.articleId);
    if (detail == null) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'article_missing',
        now: now,
      );
      return;
    }
    var article = _summaryArticle(detail);
    if (article == null) {
      article = await _extractArticle(job, detail);
      if (article == null) return;
    }
    final contentHash = summaryContentHash(article.plainText!);
    final expectedHash = payload.contentHash;
    if (expectedHash != null && contentHash != expectedHash) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'content_changed',
        now: now,
      );
      return;
    }
    final usageKey = '$_usagePrefix${payload.articleId}:$contentHash';
    ArticleSummaryInspection inspection;
    try {
      inspection = await _summaries.inspect(article);
    } on ArticleSummaryExperienceFailure catch (failure) {
      await _fail(job, failure);
      return;
    } on Object {
      await _failUnexpected(job);
      return;
    }
    if (inspection.cachedSummary != null) {
      if (await _repository.readUsageStatus(usageKey) ==
          AutomaticSummaryUsageStatus.reserved) {
        await _repository.completeUsage(
          idempotencyKey: usageKey,
          completedAt: now,
        );
      }
      await _jobs.complete(job.id, now);
      return;
    }
    final dayKey = _dayKey(now);
    final reservation = await _repository.reserveUsage(
      idempotencyKey: usageKey,
      articleId: payload.articleId,
      dayKey: dayKey,
      dailyLimit: settings.dailyLimit,
      now: now,
    );
    if (reservation == AutomaticSummaryReservationResult.limitReached) {
      await _defer(job, 'daily_limit', _nextDay(now));
      return;
    }
    if (reservation == AutomaticSummaryReservationResult.alreadyCompleted) {
      await _jobs.complete(job.id, now);
      return;
    }
    try {
      await _summaries.summarize(article);
      final persisted = await _summaries.inspect(article);
      if (persisted.cachedSummary == null) {
        throw const ArticleSummaryExperienceFailure(
          code: ArticleSummaryExperienceFailureCode.providerUnavailable,
          retryable: true,
        );
      }
      await _repository.completeUsage(
        idempotencyKey: usageKey,
        completedAt: _clock.now().toUtc(),
      );
      await _jobs.complete(job.id, _clock.now().toUtc());
    } on ArticleSummaryExperienceFailure catch (failure) {
      await _repository.releaseUsage(idempotencyKey: usageKey);
      await _fail(job, failure);
    } on Object {
      await _repository.releaseUsage(idempotencyKey: usageKey);
      await _failUnexpected(job);
    }
  }

  Future<void> _fail(
    ClaimedDurableJob job,
    ArticleSummaryExperienceFailure failure,
  ) async {
    final code = failure.code.name;
    if (!failure.retryable) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: code,
        now: _clock.now().toUtc(),
      );
      return;
    }
    final status = await _jobs.failOrRetry(
      id: job.id,
      errorCode: code,
      now: _clock.now().toUtc(),
      retryDelay: providerRetryDelay,
    );
    if (status == DurableJobStatus.queued) {
      _scheduleRetry(providerRetryDelay);
    }
  }

  Future<void> _failUnexpected(ClaimedDurableJob job) => _fail(
        job,
        const ArticleSummaryExperienceFailure(
          code: ArticleSummaryExperienceFailureCode.providerUnavailable,
          retryable: true,
        ),
      );

  Future<void> _defer(
    ClaimedDurableJob job,
    String reason,
    DateTime availableAt,
  ) async {
    await _jobs.defer(
      id: job.id,
      reasonCode: reason,
      availableAt: availableAt,
      now: _clock.now().toUtc(),
    );
    _scheduleRetry(availableAt.difference(_clock.now().toUtc()));
  }

  Future<void> _resumeAfterNetworkChange() async {
    final now = _clock.now().toUtc();
    await _jobs.expediteQueued(
      type: jobType,
      errorCodes: const <String>{'offline', 'wifi_required'},
      now: now,
    );
    await resumePending();
  }

  Future<FeedArticleDetailRecord?> _safeLoad(String articleId) async {
    try {
      return await _loadArticle(articleId);
    } on Object {
      return null;
    }
  }

  Future<Article?> _extractArticle(
    ClaimedDurableJob job,
    FeedArticleDetailRecord detail,
  ) async {
    final extractor = _extractor;
    if (extractor == null) {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'content_missing',
        now: _clock.now().toUtc(),
      );
      return null;
    }
    ExtractionResult result;
    try {
      result = await extractor.extract(
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
      await _failUnexpected(job);
      return null;
    }
    return switch (result) {
      ExtractionSuccess(:final article) => Article(
          id: detail.id,
          url: article.canonicalUri ?? detail.canonicalUrl,
          title: article.title,
          source: detail.canonicalUrl.host == 'mp.weixin.qq.com'
              ? ContentSource.weChat
              : ContentSource.web,
          author: article.author ?? detail.author,
          publishedAt: article.publishedAt ?? detail.publishedAt,
          plainText: article.plainText,
        ),
      ExtractionFailureResult(:final failure) =>
        await _handleExtractionFailure(job, failure),
    };
  }

  Future<Article?> _handleExtractionFailure(
    ClaimedDurableJob job,
    ExtractionFailure failure,
  ) async {
    if (failure.retryable) {
      final status = await _jobs.failOrRetry(
        id: job.id,
        errorCode: 'extraction_${failure.code.name}',
        now: _clock.now().toUtc(),
        retryDelay: providerRetryDelay,
      );
      if (status == DurableJobStatus.queued) {
        _scheduleRetry(providerRetryDelay);
      }
    } else {
      await _jobs.failPermanently(
        id: job.id,
        errorCode: 'extraction_${failure.code.name}',
        now: _clock.now().toUtc(),
      );
    }
    return null;
  }

  Future<AutomaticSummaryNetworkKind> _safeNetwork() async {
    try {
      return await _network.check();
    } on Object {
      return AutomaticSummaryNetworkKind.unknown;
    }
  }

  void _scheduleRetry(Duration delay) {
    final boundedDelay = delay.isNegative ? Duration.zero : delay;
    final retryAt = _clock.now().toUtc().add(boundedDelay);
    if (_retryAt case final scheduled? when !retryAt.isBefore(scheduled)) {
      return;
    }
    _retryTimer?.cancel();
    _retryAt = retryAt;
    _retryTimer = Timer(boundedDelay, () {
      _retryTimer = null;
      _retryAt = null;
      unawaited(resumePending());
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retryTimer?.cancel();
    await _networkSubscription?.cancel();
    await _activeRun;
  }
}

final class _AutomaticSummaryPayload {
  const _AutomaticSummaryPayload({
    required this.articleId,
    required this.contentHash,
    required this.rankingScore,
  });

  final String articleId;
  final String? contentHash;
  final double rankingScore;
}

_AutomaticSummaryPayload? _decodePayload(String encoded) {
  try {
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic> ||
        value.length != 5 ||
        value['schemaVersion'] != 1 ||
        value['articleId'] is! String ||
        value['contentHash'] != null && value['contentHash'] is! String ||
        value['rankingScore'] is! num ||
        value['rankingModelVersion'] is! int) {
      return null;
    }
    final articleId = value['articleId'] as String;
    final contentHash = value['contentHash'] as String?;
    final score = (value['rankingScore'] as num).toDouble();
    if (articleId.isEmpty ||
        articleId.length > 256 ||
        articleId.trim() != articleId ||
        contentHash != null &&
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(contentHash) ||
        !score.isFinite ||
        score < 0 ||
        score > 1 ||
        (value['rankingModelVersion'] as int) < 1) {
      return null;
    }
    return _AutomaticSummaryPayload(
      articleId: articleId,
      contentHash: contentHash,
      rankingScore: score,
    );
  } on Object {
    return null;
  }
}

Article? _summaryArticle(FeedArticleDetailRecord detail) {
  final content = detail.content;
  if (content == null || !content.isReadable) return null;
  final text = content.plainText.trim();
  if (text.isEmpty) return null;
  return Article(
    id: detail.id,
    url: detail.canonicalUrl,
    title: detail.title,
    source: detail.canonicalUrl.host == 'mp.weixin.qq.com'
        ? ContentSource.weChat
        : ContentSource.web,
    author: detail.author,
    publishedAt: detail.publishedAt,
    plainText: text,
  );
}

String automaticSummaryLocalDayKey(DateTime now) {
  final local = now.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime automaticSummaryNextLocalDay(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1).toUtc();
}
