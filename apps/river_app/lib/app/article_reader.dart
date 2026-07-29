import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_design_system/river_design_system.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_knowledge/river_knowledge.dart';

enum ArticleReaderLoadPhase { loading, ready, missing, failed }

enum ArticleEnhancementPhase {
  idle,
  enhancing,
  ready,
  failed,
  usingAvailable,
}

enum ArticleReaderContentSource { feed, cache, extracted }

typedef ArticleAnnotationCreator = Future<void> Function({
  required ArticleTextAnchor anchor,
  String? note,
  ArticleAnnotationColor color,
});

final class ArticleReaderContent {
  const ArticleReaderContent({
    required this.text,
    required this.source,
    required this.revision,
    this.markdown,
    this.sanitizedHtml,
  });

  final String text;
  final ArticleReaderContentSource source;
  final String revision;
  final String? markdown;
  final String? sanitizedHtml;

  int get priority => switch (source) {
        ArticleReaderContentSource.feed => 0,
        ArticleReaderContentSource.cache => 1,
        ArticleReaderContentSource.extracted => 2,
      };
}

final class ArticleEnhancementFailure {
  const ArticleEnhancementFailure({
    required this.code,
    required this.retryable,
    required this.attempts,
  });

  final ExtractionFailureCode code;
  final bool retryable;
  final List<ExtractionAttempt> attempts;
}

final class ArticleReaderState {
  const ArticleReaderState({
    required this.loadPhase,
    this.enhancementPhase = ArticleEnhancementPhase.idle,
    this.detail,
    this.content,
    this.enhancementFailure,
    this.offlineArticle,
    this.settings = const ReaderSettings(),
    this.annotations = const <ArticleAnnotation>[],
    this.audio = const AudioPlaybackState.initial(),
    this.knowledgeItemId,
    this.operationFailure,
    this.isMutating = false,
    this.isSavingKnowledge = false,
  });

  const ArticleReaderState.loading()
      : this(loadPhase: ArticleReaderLoadPhase.loading);

  final ArticleReaderLoadPhase loadPhase;
  final ArticleEnhancementPhase enhancementPhase;
  final FeedArticleDetailRecord? detail;
  final ArticleReaderContent? content;
  final ArticleEnhancementFailure? enhancementFailure;
  final OfflineArticleState? offlineArticle;
  final ReaderSettings settings;
  final List<ArticleAnnotation> annotations;
  final AudioPlaybackState audio;
  final String? knowledgeItemId;
  final String? operationFailure;
  final bool isMutating;
  final bool isSavingKnowledge;

  ArticleReaderState copyWith({
    ArticleReaderLoadPhase? loadPhase,
    ArticleEnhancementPhase? enhancementPhase,
    FeedArticleDetailRecord? detail,
    ArticleReaderContent? content,
    ArticleEnhancementFailure? enhancementFailure,
    bool clearEnhancementFailure = false,
    OfflineArticleState? offlineArticle,
    ReaderSettings? settings,
    List<ArticleAnnotation>? annotations,
    AudioPlaybackState? audio,
    String? knowledgeItemId,
    String? operationFailure,
    bool clearOperationFailure = false,
    bool? isMutating,
    bool? isSavingKnowledge,
  }) =>
      ArticleReaderState(
        loadPhase: loadPhase ?? this.loadPhase,
        enhancementPhase: enhancementPhase ?? this.enhancementPhase,
        detail: detail ?? this.detail,
        content: content ?? this.content,
        enhancementFailure: clearEnhancementFailure
            ? null
            : enhancementFailure ?? this.enhancementFailure,
        offlineArticle: offlineArticle ?? this.offlineArticle,
        settings: settings ?? this.settings,
        annotations: annotations ?? this.annotations,
        audio: audio ?? this.audio,
        knowledgeItemId: knowledgeItemId ?? this.knowledgeItemId,
        operationFailure: clearOperationFailure
            ? null
            : operationFailure ?? this.operationFailure,
        isMutating: isMutating ?? this.isMutating,
        isSavingKnowledge: isSavingKnowledge ?? this.isSavingKnowledge,
      );
}

final class ArticleReaderController extends ChangeNotifier {
  ArticleReaderController({
    required this.articleId,
    required ArticleReaderRepository repository,
    required FullTextExtractor extractor,
    required ReaderSettingsRepository readerSettings,
    ArticleAnnotationRepository annotations =
        const UnavailableArticleAnnotationRepository(),
    IdGenerator? ids,
    required ShareGateway share,
    required ExternalUriGateway externalUri,
    required OfflineArticleManager offlineArticles,
    required Clock clock,
    AudioEngine audio = const UnavailableAudioEngine(),
    AudioPlaybackRepository audioPlayback =
        const UnavailableAudioPlaybackRepository(),
    AudioPlaybackController? audioController,
    PersistentAudioQueue? audioQueue,
    KnowledgeRepository? knowledge,
  })  : _repository = repository,
        _extractor = extractor,
        _readerSettings = readerSettings,
        _annotations = annotations,
        _ids = ids,
        _share = share,
        _externalUri = externalUri,
        _offlineArticles = offlineArticles,
        _clock = clock,
        _audioQueue = audioQueue,
        _knowledge = knowledge,
        _audioController = audioController ??
            AudioPlaybackController(
              engine: audio,
              repository: audioPlayback,
              clock: clock,
            ),
        _ownsAudioController = audioController == null {
    _subscribeArticle();
    _subscribeSettings();
    _subscribeAnnotations();
    _subscribeOfflineArticle();
    _subscribeAudio();
  }

  final String articleId;
  final ArticleReaderRepository _repository;
  final FullTextExtractor _extractor;
  final ReaderSettingsRepository _readerSettings;
  final ArticleAnnotationRepository _annotations;
  final IdGenerator? _ids;
  final ShareGateway _share;
  final ExternalUriGateway _externalUri;
  final OfflineArticleManager _offlineArticles;
  final Clock _clock;
  final PersistentAudioQueue? _audioQueue;
  final KnowledgeRepository? _knowledge;
  final AudioPlaybackController _audioController;
  final bool _ownsAudioController;
  StreamSubscription<FeedArticleDetailRecord?>? _articleSubscription;
  StreamSubscription<ReaderSettings>? _settingsSubscription;
  StreamSubscription<List<ArticleAnnotation>>? _annotationSubscription;
  StreamSubscription<OfflineArticleState>? _offlineArticleSubscription;
  StreamSubscription<AudioPlaybackState>? _audioSubscription;
  ArticleReaderState _state = const ArticleReaderState.loading();
  var _extractionStarted = false;
  var _subscriptionGeneration = 0;
  var _extractionGeneration = 0;
  var _openedMarked = false;
  Timer? _progressTimer;
  double? _pendingProgress;
  var _disposed = false;

  ArticleReaderState get state => _state;
  bool get canAnnotate => _ids != null && _state.content != null;
  bool get canQueueSpeech =>
      _audioQueue != null && _state.detail != null && _state.content != null;
  bool get canSaveToKnowledge =>
      _knowledge != null &&
      _ids != null &&
      _state.detail != null &&
      _state.content != null;

  void retry() {
    _extractionStarted = false;
    _extractionGeneration += 1;
    _setState(
      ArticleReaderState(
        loadPhase: ArticleReaderLoadPhase.loading,
        settings: _state.settings,
        annotations: _state.annotations,
        audio: _state.audio,
        knowledgeItemId: _state.knowledgeItemId,
      ),
    );
    _subscribeArticle();
  }

  void _subscribeArticle() {
    final generation = ++_subscriptionGeneration;
    unawaited(_articleSubscription?.cancel());
    _articleSubscription = _repository.watchArticle(articleId).listen(
      (detail) {
        if (generation == _subscriptionGeneration) _acceptDetail(detail);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _subscriptionGeneration) return;
        _setState(
          _state.copyWith(loadPhase: ArticleReaderLoadPhase.failed),
        );
      },
    );
  }

  void _subscribeSettings() {
    _settingsSubscription = _readerSettings.watchSettings().listen(
          (settings) => _setState(_state.copyWith(settings: settings)),
          onError: (Object error, StackTrace stackTrace) => _setState(
            _state.copyWith(
              operationFailure: '阅读设置暂不可用，已使用默认排版',
            ),
          ),
        );
  }

  void _subscribeAnnotations() {
    _annotationSubscription = _annotations
        .watchArticleAnnotations(articleId)
        .listen(
          (annotations) => _setState(
            _state.copyWith(
              annotations: List<ArticleAnnotation>.unmodifiable(annotations),
            ),
          ),
          onError: (Object error, StackTrace stackTrace) => _setState(
            _state.copyWith(
              operationFailure: '高亮与笔记暂时无法读取',
            ),
          ),
        );
  }

  void _subscribeOfflineArticle() {
    _offlineArticleSubscription = _offlineArticles.watch(articleId).listen(
          _acceptOfflineArticleState,
          onError: (Object error, StackTrace stackTrace) => _setState(
            _state.copyWith(
              offlineArticle: OfflineArticleState(
                articleId: articleId,
                phase: OfflineArticlePhase.failed,
              ),
            ),
          ),
        );
  }

  void _subscribeAudio() {
    _audioSubscription = _audioController.states.listen(
      (audio) => _setState(_state.copyWith(audio: audio)),
    );
  }

  void _acceptOfflineArticleState(OfflineArticleState offlineArticle) {
    final content = _state.content;
    if (content != null && content.source != ArticleReaderContentSource.feed) {
      _setState(
        _state.copyWith(
          offlineArticle: OfflineArticleState(
            articleId: articleId,
            phase: OfflineArticlePhase.available,
          ),
        ),
      );
      return;
    }
    _setState(_state.copyWith(offlineArticle: offlineArticle));
  }

  void _acceptDetail(FeedArticleDetailRecord? detail) {
    if (detail == null) {
      unawaited(_audioController.stop());
      _setState(
        ArticleReaderState(
          loadPhase: ArticleReaderLoadPhase.missing,
          settings: _state.settings,
          annotations: _state.annotations,
          audio: _state.audio,
          knowledgeItemId: _state.knowledgeItemId,
        ),
      );
      return;
    }
    final candidate = _availableContent(detail);
    final current = _state.content;
    final nextContent = candidate == null ||
            (current != null && candidate.priority < current.priority)
        ? current
        : candidate;
    _setState(
      ArticleReaderState(
        loadPhase: ArticleReaderLoadPhase.ready,
        enhancementPhase: _state.enhancementPhase,
        detail: detail,
        content: nextContent,
        enhancementFailure: _state.enhancementFailure,
        offlineArticle: _offlineStateForDetail(detail),
        settings: _state.settings,
        annotations: _state.annotations,
        audio: _state.audio,
        knowledgeItemId: _state.knowledgeItemId,
        operationFailure: _state.operationFailure,
        isMutating: _state.isMutating,
        isSavingKnowledge: _state.isSavingKnowledge,
      ),
    );
    unawaited(_refreshKnowledgeState(detail));
    if (!_openedMarked) {
      _openedMarked = true;
      unawaited(_setRead(true, automatic: true));
    }
    if (!_extractionStarted) {
      _extractionStarted = true;
      unawaited(_enhance(detail));
    }
  }

  Future<void> _enhance(
    FeedArticleDetailRecord detail, {
    bool forceReparse = false,
  }) async {
    final generation = ++_extractionGeneration;
    _setState(
      _state.copyWith(
        enhancementPhase: ArticleEnhancementPhase.enhancing,
        clearEnhancementFailure: true,
      ),
    );
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
          forceReparse: forceReparse,
        ),
      );
    } on Object {
      if (_disposed || generation != _extractionGeneration) return;
      _setState(
        _state.copyWith(
          enhancementPhase: ArticleEnhancementPhase.failed,
          enhancementFailure: const ArticleEnhancementFailure(
            code: ExtractionFailureCode.unexpected,
            retryable: true,
            attempts: <ExtractionAttempt>[],
          ),
        ),
      );
      return;
    }
    if (_disposed || generation != _extractionGeneration) return;
    switch (result) {
      case ExtractionSuccess(:final article, :final attempts):
        final fromCache = attempts.any(
          (attempt) =>
              attempt.extractor == CachedFullTextExtractor.cacheExtractor,
        );
        final content = ArticleReaderContent(
          text: article.plainText.trim(),
          source: fromCache
              ? ArticleReaderContentSource.cache
              : ArticleReaderContentSource.extracted,
          revision:
              '${article.extractor}@${article.extractorVersion}:${article.html.hashCode}',
          markdown: article.plainText.trim(),
          sanitizedHtml: article.html,
        );
        if (_state.audio.request case final request?
            when request.contentRevision != content.revision) {
          await _audioController.stop();
          if (_disposed || generation != _extractionGeneration) return;
        }
        _setState(
          _state.copyWith(
            enhancementPhase: ArticleEnhancementPhase.ready,
            content: content.text.isEmpty ? _state.content : content,
            offlineArticle: OfflineArticleState(
              articleId: articleId,
              phase: OfflineArticlePhase.available,
            ),
            clearEnhancementFailure: true,
          ),
        );
      case ExtractionFailureResult(:final failure, :final attempts):
        _setState(
          _state.copyWith(
            enhancementPhase: ArticleEnhancementPhase.failed,
            enhancementFailure: ArticleEnhancementFailure(
              code: failure.code,
              retryable: failure.retryable,
              attempts: List<ExtractionAttempt>.unmodifiable(attempts),
            ),
          ),
        );
    }
  }

  Future<void> retryEnhancement() async {
    final detail = _state.detail;
    if (detail == null) return;
    _extractionStarted = true;
    await _enhance(detail, forceReparse: true);
  }

  void useAvailableContent() {
    if (_state.content == null ||
        _state.enhancementPhase != ArticleEnhancementPhase.failed) {
      return;
    }
    _setState(
      _state.copyWith(
        enhancementPhase: ArticleEnhancementPhase.usingAvailable,
      ),
    );
  }

  Future<void> openOriginal() async {
    final detail = _state.detail;
    if (detail == null) return;
    ExternalUriOpenOutcome outcome;
    try {
      outcome = await _externalUri.open(detail.canonicalUrl);
    } on Object {
      outcome = ExternalUriOpenOutcome.unavailable;
    }
    if (outcome == ExternalUriOpenOutcome.unavailable) {
      _setState(
        _state.copyWith(
          operationFailure: '无法打开原文，请检查系统浏览器设置后重试',
        ),
      );
    }
  }

  Future<void> reportExtractionIssue({ShareAnchor? anchor}) async {
    final detail = _state.detail;
    final failure = _state.enhancementFailure;
    if (detail == null || failure == null) return;
    final attempts = failure.attempts.isEmpty
        ? 'none'
        : failure.attempts
            .map(
              (attempt) => '${attempt.extractor}@${attempt.extractorVersion}:'
                  '${attempt.outcome.name}',
            )
            .join(', ');
    try {
      final outcome = await _share.share(
        ShareRequest(
          title: 'River 全文提取问题',
          subject: 'River 全文提取问题：${detail.title}',
          text: 'River 全文提取问题\n'
              '原文：${detail.canonicalUrl}\n'
              '失败类型：${failure.code.name}\n'
              '可重试：${failure.retryable}\n'
              '提取阶段：$attempts',
          anchor: anchor,
        ),
      );
      if (outcome == ShareOutcome.unavailable) {
        _setState(
          _state.copyWith(operationFailure: '当前系统暂不支持报告问题'),
        );
      }
    } on Object {
      _setState(_state.copyWith(operationFailure: '报告问题失败，请重试'));
    }
  }

  Future<void> downloadForOffline() async {
    final detail = _state.detail;
    if (detail == null) return;
    if (_state.offlineArticle?.isAvailable == true ||
        detail.content?.isReadable == true) {
      _setState(
        _state.copyWith(
          offlineArticle: OfflineArticleState(
            articleId: articleId,
            phase: OfflineArticlePhase.available,
          ),
        ),
      );
      return;
    }
    try {
      await _offlineArticles.enqueue(articleId);
    } on Object {
      _setState(_state.copyWith(operationFailure: '无法创建离线下载任务，请重试'));
    }
  }

  Future<void> retryOfflineDownload() async {
    try {
      await _offlineArticles.retry(articleId);
    } on Object {
      _setState(_state.copyWith(operationFailure: '离线下载重试失败，请稍后再试'));
    }
  }

  Future<void> toggleRead() async {
    final detail = _state.detail;
    if (detail == null) return;
    await _setRead(!detail.read);
  }

  Future<void> _setRead(bool read, {bool automatic = false}) => _mutate(
        () => _repository.setRead(
          articleId,
          read: read,
          updatedAt: _clock.now(),
        ),
        failureMessage: automatic ? null : '无法更新已读状态',
      );

  Future<void> toggleStarred() async {
    final detail = _state.detail;
    if (detail == null) return;
    await _mutate(
      () => _repository.setStarred(
        articleId,
        starred: !detail.starred,
        updatedAt: _clock.now(),
      ),
      failureMessage: '无法更新收藏状态',
    );
  }

  Future<void> toggleReadLater() async {
    final detail = _state.detail;
    if (detail == null) return;
    await _mutate(
      () => _repository.setReadLater(
        articleId,
        readLater: !detail.readLater,
        updatedAt: _clock.now(),
      ),
      failureMessage: '无法更新稍后读状态',
    );
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    final previous = _state.settings;
    _setState(
      _state.copyWith(settings: settings, clearOperationFailure: true),
    );
    try {
      await _readerSettings.saveSettings(settings, updatedAt: _clock.now());
    } on Object {
      _setState(
        _state.copyWith(
          settings: previous,
          operationFailure: '阅读设置保存失败，请重试',
        ),
      );
    }
  }

  Future<void> createAnnotation({
    required ArticleTextAnchor anchor,
    String? note,
    ArticleAnnotationColor color = ArticleAnnotationColor.yellow,
  }) async {
    final ids = _ids;
    if (ids == null) {
      _setState(_state.copyWith(operationFailure: '当前正文暂时无法添加高亮'));
      return;
    }
    final normalizedNote = _normalizedAnnotationNote(note);
    try {
      final now = _clock.now().toUtc();
      await _annotations.upsertAnnotation(
        ArticleAnnotation(
          id: ids.next(),
          articleId: articleId,
          anchor: anchor,
          color: color,
          note: normalizedNote,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } on Object {
      _setState(_state.copyWith(operationFailure: '高亮保存失败，请重试'));
    }
  }

  Future<void> updateAnnotation({
    required ArticleAnnotation annotation,
    required ArticleAnnotationColor color,
    String? note,
  }) async {
    try {
      await _annotations.upsertAnnotation(
        annotation.copyWith(
          color: color,
          note: _normalizedAnnotationNote(note),
          clearNote: note == null || note.trim().isEmpty,
          updatedAt: _clock.now().toUtc(),
        ),
      );
    } on Object {
      _setState(_state.copyWith(operationFailure: '笔记保存失败，请重试'));
    }
  }

  Future<void> deleteAnnotation(String annotationId) async {
    try {
      await _annotations.deleteAnnotation(annotationId);
    } on Object {
      _setState(_state.copyWith(operationFailure: '高亮删除失败，请重试'));
    }
  }

  Future<void> toggleSpeech() async {
    final audio = _audioController.state;
    if (audio.phase == AudioEnginePhase.playing) {
      await _audioController.pause();
      return;
    }
    if (audio.phase == AudioEnginePhase.loading || audio.restoring) return;

    final detail = _state.detail;
    final content = _state.content;
    if (detail == null || content == null) {
      _setState(
        _state.copyWith(operationFailure: '正文准备完成后才能开始朗读'),
      );
      return;
    }
    final segments = const ArticleSpeechSegmenter().segment(content.text);
    if (segments.isEmpty) {
      _setState(_state.copyWith(operationFailure: '当前文章没有可朗读的正文'));
      return;
    }

    final loaded = audio.request;
    if (loaded == null ||
        loaded.item.id != articleId ||
        loaded.contentRevision != content.revision) {
      await _audioController.load(
        AudioLoadRequest(
          item: AudioItem(
            id: articleId,
            kind: AudioKind.articleTts,
            title: detail.title,
            sourceUri: detail.canonicalUrl,
          ),
          speechSegments: segments,
          contentRevision: content.revision,
        ),
      );
    }
    if (_audioController.state.phase != AudioEnginePhase.failed) {
      await _audioController.play();
    }
  }

  Future<bool?> enqueueSpeech() async {
    final queue = _audioQueue;
    final detail = _state.detail;
    final content = _state.content;
    if (queue == null || detail == null || content == null) return null;
    if (const ArticleSpeechSegmenter().segment(content.text).isEmpty) {
      _setState(_state.copyWith(operationFailure: '当前文章没有可朗读的正文'));
      return null;
    }
    return queue.enqueue(
      AudioItem(
        id: detail.id,
        kind: AudioKind.articleTts,
        title: detail.title,
        sourceUri: detail.canonicalUrl,
      ),
      contentRevision: content.revision,
    );
  }

  Future<void> skipSpeechNext() => _audioController.skipNext();

  Future<void> skipSpeechPrevious() => _audioController.skipPrevious();

  Future<void> restartSpeechSegment() =>
      _audioController.restartCurrentSegment();

  Future<void> setSpeechRate(double rate) {
    final current = _audioController.state.settings;
    return _audioController.updateSettings(
      AudioPlaybackSettings(
        rate: rate,
        pitch: current.pitch,
        voiceId: current.voiceId,
        languageTag: current.languageTag,
      ),
    );
  }

  Future<void> selectSpeechVoice(String? voiceId) {
    final current = _audioController.state.settings;
    AudioVoice? selected;
    if (voiceId != null) {
      for (final voice in _audioController.state.voices) {
        if (voice.id == voiceId) {
          selected = voice;
          break;
        }
      }
    }
    return _audioController.updateSettings(
      AudioPlaybackSettings(
        rate: current.rate,
        pitch: current.pitch,
        voiceId: selected?.id,
        languageTag: selected?.languageTag,
      ),
    );
  }

  void setSpeechTimer(Duration? duration) =>
      _audioController.setSleepTimer(duration);

  void clearAudioFailure() => _audioController.clearFailure();

  Future<void> shareArticle({ShareAnchor? anchor}) async {
    final detail = _state.detail;
    if (detail == null) return;
    try {
      final outcome = await _share.share(
        ShareRequest(
          title: detail.title,
          subject: detail.title,
          text: '${detail.title}\n${detail.canonicalUrl}',
          anchor: anchor,
        ),
      );
      if (outcome == ShareOutcome.unavailable) {
        _setState(
          _state.copyWith(operationFailure: '当前系统暂不支持分享'),
        );
      }
    } on Object {
      _setState(_state.copyWith(operationFailure: '分享失败，请重试'));
    }
  }

  Future<KnowledgeItem?> saveToKnowledge() async {
    final repository = _knowledge;
    final idGenerator = _ids;
    final detail = _state.detail;
    final content = _state.content;
    if (repository == null ||
        idGenerator == null ||
        detail == null ||
        content == null ||
        _state.isSavingKnowledge) {
      return null;
    }
    _setState(
      _state.copyWith(
        isSavingKnowledge: true,
        clearOperationFailure: true,
      ),
    );
    try {
      final source = KnowledgeSourceReference(
        kind: KnowledgeSourceKind.article,
        sourceId: detail.id,
        originalUrl: detail.canonicalUrl,
        sourceTitle: detail.feedTitle,
        author: detail.author,
        publishedAt: detail.publishedAt,
      );
      final existing = await repository.findBySource(source);
      final excerpts = _state.annotations
          .map(
            (annotation) => KnowledgeExcerpt(
              quote: annotation.anchor.exact,
              note: annotation.note,
              annotationId: annotation.id,
            ),
          )
          .toList(growable: false);
      final notes = _state.annotations
          .map((annotation) => annotation.note?.trim())
          .whereType<String>()
          .where((note) => note.isNotEmpty)
          .toList(growable: false);
      final markdown = content.markdown?.trim().isNotEmpty == true
          ? content.markdown!.trim()
          : content.text.trim();
      final sanitizedHtml = content.sanitizedHtml ?? '';
      final hash = const KnowledgeContentHasher().hash(
        title: detail.title,
        markdown: markdown,
        sanitizedHtml: sanitizedHtml,
        excerpts: excerpts,
        notes: notes,
        tags: existing?.tags ?? const <String>[],
        topics: existing?.topics ?? const <String>[],
        entities: existing?.entities ?? const <String>[],
        summary: existing?.summary,
      );
      final now = _clock.now().toUtc();
      final updatedAt = existing != null && !now.isAfter(existing.updatedAt)
          ? existing.updatedAt.add(const Duration(microseconds: 1))
          : now;
      final saved = await repository.saveItem(
        KnowledgeItem(
          id: existing?.id ?? idGenerator.next(),
          source: source,
          title: detail.title,
          markdown: markdown,
          sanitizedHtml: sanitizedHtml,
          summary: existing?.summary,
          excerpts: excerpts,
          notes: notes,
          tags: existing?.tags ?? const <String>[],
          topics: existing?.topics ?? const <String>[],
          entities: existing?.entities ?? const <String>[],
          contentHash: hash,
          savedAt: existing?.savedAt ?? now,
          updatedAt: updatedAt,
        ),
      );
      _setState(
        _state.copyWith(
          knowledgeItemId: saved.id,
          isSavingKnowledge: false,
        ),
      );
      return saved;
    } on Object {
      _setState(
        _state.copyWith(
          operationFailure: '保存到知识库失败，本地文章与高亮未受影响',
          isSavingKnowledge: false,
        ),
      );
      return null;
    }
  }

  void reportProgress(double progress) {
    final normalized = progress.clamp(0, 1).toDouble();
    _pendingProgress = normalized;
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(milliseconds: 450), _flushProgress);
  }

  void clearOperationFailure() =>
      _setState(_state.copyWith(clearOperationFailure: true));

  Future<void> _refreshKnowledgeState(FeedArticleDetailRecord detail) async {
    final repository = _knowledge;
    if (repository == null) return;
    try {
      final existing = await repository.findBySource(
        KnowledgeSourceReference(
          kind: KnowledgeSourceKind.article,
          sourceId: detail.id,
          originalUrl: detail.canonicalUrl,
          sourceTitle: detail.feedTitle,
          author: detail.author,
          publishedAt: detail.publishedAt,
        ),
      );
      if (existing != null && _state.detail?.id == detail.id) {
        _setState(_state.copyWith(knowledgeItemId: existing.id));
      }
    } on Object {
      // Knowledge lookup is an optional enhancement and must not block reading.
    }
  }

  Future<void> _mutate(
    Future<void> Function() operation, {
    required String? failureMessage,
  }) async {
    _setState(
      _state.copyWith(isMutating: true, clearOperationFailure: true),
    );
    try {
      await operation();
    } on Object {
      if (failureMessage != null) {
        _setState(_state.copyWith(operationFailure: failureMessage));
      }
    } finally {
      _setState(_state.copyWith(isMutating: false));
    }
  }

  void _flushProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
    final progress = _pendingProgress;
    _pendingProgress = null;
    if (progress == null) return;
    unawaited(
      _repository
          .saveReadingProgress(
        articleId,
        scrollDepth: progress,
        updatedAt: _clock.now(),
      )
          .onError((Object error, StackTrace stackTrace) {
        if (!_disposed) {
          _setState(
            _state.copyWith(operationFailure: '阅读进度保存失败'),
          );
        }
      }),
    );
  }

  ArticleReaderContent? _availableContent(FeedArticleDetailRecord detail) {
    final cached = detail.content;
    if (cached != null && cached.isReadable) {
      return ArticleReaderContent(
        text: cached.plainText.trim(),
        source: ArticleReaderContentSource.cache,
        revision: cached.contentHash ??
            '${cached.extractorName}@${cached.extractorVersion}:'
                '${cached.extractedAt.microsecondsSinceEpoch}',
        markdown: cached.markdown,
        sanitizedHtml: cached.sanitizedHtml,
      );
    }
    final assessed = const FeedContentAssessor().assess(
      contentHtml: detail.feedContentHtml,
      summary: detail.summary,
      sourceUri: detail.canonicalUrl,
    );
    final preview = assessed.content.plainText.trim();
    if (preview.isEmpty) return null;
    return ArticleReaderContent(
      text: preview,
      source: ArticleReaderContentSource.feed,
      revision: 'feed:${preview.hashCode}',
      markdown: preview,
      sanitizedHtml: assessed.content.html,
    );
  }

  OfflineArticleState _offlineStateForDetail(
    FeedArticleDetailRecord detail,
  ) {
    if (detail.content?.isReadable == true) {
      return OfflineArticleState(
        articleId: articleId,
        phase: OfflineArticlePhase.available,
      );
    }
    return _state.offlineArticle ??
        OfflineArticleState.notDownloaded(articleId);
  }

  void _setState(ArticleReaderState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _flushProgress();
    _progressTimer?.cancel();
    _subscriptionGeneration += 1;
    _extractionGeneration += 1;
    unawaited(_articleSubscription?.cancel());
    unawaited(_settingsSubscription?.cancel());
    unawaited(_annotationSubscription?.cancel());
    unawaited(_offlineArticleSubscription?.cancel());
    unawaited(_audioSubscription?.cancel());
    if (_ownsAudioController) {
      unawaited(_audioController.dispose());
    }
    super.dispose();
  }
}

String? _normalizedAnnotationNote(String? note) {
  final normalized = note?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.length <= 20000
      ? normalized
      : normalized.substring(0, 20000);
}

List<ResolvedArticleAnnotation> _resolveAnnotations(ArticleReaderState state) {
  final content = state.content;
  if (content == null || state.annotations.isEmpty) {
    return const <ResolvedArticleAnnotation>[];
  }
  final document = DocumentTextSnapshot.single(content.text);
  final resolved = state.annotations
      .map(
        (annotation) => const ArticleAnchorResolver().resolve(
          annotation,
          document,
          contentRevision: content.revision,
        ),
      )
      .toList(growable: false);
  resolved.sort((left, right) {
    if (left.isAttached != right.isAttached) return left.isAttached ? -1 : 1;
    return (left.start ?? left.annotation.anchor.originalStart)
        .compareTo(right.start ?? right.annotation.anchor.originalStart);
  });
  return List<ResolvedArticleAnnotation>.unmodifiable(resolved);
}

final class ArticleReaderPage extends StatefulWidget {
  const ArticleReaderPage({
    required this.articleId,
    required this.repository,
    required this.extractor,
    required this.readerSettings,
    this.annotations = const UnavailableArticleAnnotationRepository(),
    this.ids,
    required this.share,
    required this.externalUri,
    required this.offlineArticles,
    required this.clock,
    this.audio = const UnavailableAudioEngine(),
    this.audioPlayback = const UnavailableAudioPlaybackRepository(),
    this.audioController,
    this.audioQueue,
    this.knowledge,
    super.key,
  });

  final String articleId;
  final ArticleReaderRepository repository;
  final FullTextExtractor extractor;
  final ReaderSettingsRepository readerSettings;
  final ArticleAnnotationRepository annotations;
  final IdGenerator? ids;
  final ShareGateway share;
  final ExternalUriGateway externalUri;
  final OfflineArticleManager offlineArticles;
  final Clock clock;
  final AudioEngine audio;
  final AudioPlaybackRepository audioPlayback;
  final AudioPlaybackController? audioController;
  final PersistentAudioQueue? audioQueue;
  final KnowledgeRepository? knowledge;

  @override
  State<ArticleReaderPage> createState() => _ArticleReaderPageState();
}

final class _ArticleReaderPageState extends State<ArticleReaderPage> {
  late final ArticleReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ArticleReaderController(
      articleId: widget.articleId,
      repository: widget.repository,
      extractor: widget.extractor,
      readerSettings: widget.readerSettings,
      annotations: widget.annotations,
      ids: widget.ids,
      share: widget.share,
      externalUri: widget.externalUri,
      offlineArticles: widget.offlineArticles,
      clock: widget.clock,
      audio: widget.audio,
      audioPlayback: widget.audioPlayback,
      audioController: widget.audioController,
      audioQueue: widget.audioQueue,
      knowledge: widget.knowledge,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ArticleReaderScreen(controller: _controller);
}

Future<String?> _requestAnnotationNote(
  BuildContext context, {
  String initial = '',
}) async {
  var note = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('添加笔记'),
      content: TextFormField(
        initialValue: initial,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        maxLength: 20000,
        onChanged: (value) => note = value,
        decoration: const InputDecoration(
          hintText: '记录为什么这段内容值得保留',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(note),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

Future<void> _showAnnotations(
  BuildContext context,
  ArticleReaderState state,
  ArticleReaderController controller,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AnnotationSheet(
        annotations: _resolveAnnotations(state),
        onUpdate: controller.updateAnnotation,
        onDelete: controller.deleteAnnotation,
      ),
    );

enum _AnnotationAction { edit, delete }

final class _AnnotationEdit {
  const _AnnotationEdit({required this.note, required this.color});

  final String note;
  final ArticleAnnotationColor color;
}

final class _AnnotationSheet extends StatelessWidget {
  const _AnnotationSheet({
    required this.annotations,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<ResolvedArticleAnnotation> annotations;
  final Future<void> Function({
    required ArticleAnnotation annotation,
    required ArticleAnnotationColor color,
    String? note,
  }) onUpdate;
  final Future<void> Function(String annotationId) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.78,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            Text(
              '高亮与笔记',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final resolved in annotations)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: _annotationColor(
                      resolved.annotation.color,
                    ),
                  ),
                  title: Text(
                    resolved.annotation.anchor.exact,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    <String>[
                      if (!resolved.isAttached) '正文变化后已失联',
                      if (resolved.annotation.note case final note?) note,
                    ].join('\n'),
                  ),
                  trailing: PopupMenuButton<_AnnotationAction>(
                    tooltip: '管理高亮',
                    onSelected: (action) => unawaited(
                      _handleAction(context, action, resolved.annotation),
                    ),
                    itemBuilder: (context) =>
                        const <PopupMenuEntry<_AnnotationAction>>[
                      PopupMenuItem(
                        value: _AnnotationAction.edit,
                        child: Text('编辑笔记与颜色'),
                      ),
                      PopupMenuItem(
                        value: _AnnotationAction.delete,
                        child: Text('删除高亮'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    _AnnotationAction action,
    ArticleAnnotation annotation,
  ) async {
    switch (action) {
      case _AnnotationAction.edit:
        final edit = await _editAnnotation(context, annotation);
        if (edit == null) return;
        await onUpdate(
          annotation: annotation,
          color: edit.color,
          note: edit.note,
        );
      case _AnnotationAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除高亮？'),
            content: const Text('该高亮及其笔记将从本机删除。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await onDelete(annotation.id);
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<_AnnotationEdit?> _editAnnotation(
  BuildContext context,
  ArticleAnnotation annotation,
) async {
  var note = annotation.note ?? '';
  var color = annotation.color;
  return showDialog<_AnnotationEdit>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocalState) => AlertDialog(
        title: const Text('编辑高亮'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: ArticleAnnotationColor.values
                    .map(
                      (value) => ChoiceChip(
                        selected: color == value,
                        avatar: CircleAvatar(
                          backgroundColor: _annotationColor(value),
                        ),
                        label: Text(_annotationColorLabel(value)),
                        onSelected: (_) => setLocalState(() => color = value),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: note,
                minLines: 3,
                maxLines: 8,
                maxLength: 20000,
                onChanged: (value) => note = value,
                decoration: const InputDecoration(labelText: '笔记'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _AnnotationEdit(note: note, color: color),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

String _annotationColorLabel(ArticleAnnotationColor color) => switch (color) {
      ArticleAnnotationColor.yellow => '黄',
      ArticleAnnotationColor.green => '绿',
      ArticleAnnotationColor.blue => '蓝',
      ArticleAnnotationColor.pink => '粉',
    };

Color _annotationColor(ArticleAnnotationColor color) => switch (color) {
      ArticleAnnotationColor.yellow => Colors.amber,
      ArticleAnnotationColor.green => Colors.lightGreen,
      ArticleAnnotationColor.blue => Colors.lightBlue,
      ArticleAnnotationColor.pink => Colors.pinkAccent,
    };

final class ArticleReaderScreen extends StatelessWidget {
  const ArticleReaderScreen({required this.controller, super.key});

  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final state = controller.state;
        final inheritedTheme = Theme.of(context);
        final highContrast = MediaQuery.highContrastOf(context);
        final theme = switch (state.settings.theme) {
          ReaderThemePreference.system => inheritedTheme,
          ReaderThemePreference.light =>
            highContrast ? RiverTheme.highContrastLight() : RiverTheme.light(),
          ReaderThemePreference.dark =>
            highContrast ? RiverTheme.highContrastDark() : RiverTheme.dark(),
        };
        return Theme(
          data: theme,
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: CallbackShortcuts(
              bindings: _readerShortcuts(state, controller),
              child: Focus(
                autofocus: true,
                child: Scaffold(
                  appBar:
                      AppBar(title: Text(state.detail?.feedTitle ?? '阅读文章')),
                  body: switch (state.loadPhase) {
                    ArticleReaderLoadPhase.loading => const _ReaderLoading(),
                    ArticleReaderLoadPhase.missing => const _ReaderMissing(),
                    ArticleReaderLoadPhase.failed => _ReaderFailure(
                        onRetry: controller.retry,
                      ),
                    ArticleReaderLoadPhase.ready => _ReaderReady(
                        state: state,
                        controller: controller,
                      ),
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<ShortcutActivator, VoidCallback> _readerShortcuts(
    ArticleReaderState state,
    ArticleReaderController controller,
  ) {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(
        LogicalKeyboardKey.keyO,
        control: true,
      ): () => unawaited(controller.openOriginal()),
    };
    if (state.loadPhase != ArticleReaderLoadPhase.ready) return bindings;
    if (!state.isMutating) {
      bindings.addAll(<ShortcutActivator, VoidCallback>{
        const SingleActivator(
          LogicalKeyboardKey.keyM,
          control: true,
        ): () => unawaited(controller.toggleRead()),
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
        ): () => unawaited(controller.toggleStarred()),
        const SingleActivator(
          LogicalKeyboardKey.keyL,
          control: true,
        ): () => unawaited(controller.toggleReadLater()),
      });
    }
    final offlinePhase =
        state.offlineArticle?.phase ?? OfflineArticlePhase.notDownloaded;
    if (offlinePhase == OfflineArticlePhase.notDownloaded) {
      bindings[const SingleActivator(
        LogicalKeyboardKey.keyD,
        control: true,
      )] = () => unawaited(controller.downloadForOffline());
    } else if (offlinePhase == OfflineArticlePhase.failed) {
      bindings[const SingleActivator(
        LogicalKeyboardKey.keyD,
        control: true,
      )] = () => unawaited(controller.retryOfflineDownload());
    }
    if (state.enhancementPhase == ArticleEnhancementPhase.failed) {
      bindings[const SingleActivator(
        LogicalKeyboardKey.keyR,
        control: true,
      )] = () => unawaited(controller.retryEnhancement());
    }
    return bindings;
  }
}

final class _ReaderReady extends StatelessWidget {
  const _ReaderReady({required this.state, required this.controller});

  final ArticleReaderState state;
  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail!;
    final content = state.content;
    final resolvedAnnotations = _resolveAnnotations(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.operationFailure case final failure?)
          MaterialBanner(
            content: Text(failure),
            actions: <Widget>[
              TextButton(
                onPressed: controller.clearOperationFailure,
                child: const Text('关闭'),
              ),
            ],
          ),
        if (state.enhancementPhase == ArticleEnhancementPhase.failed)
          _EnhancementFailureBanner(
            hasAvailableContent: content != null,
            controller: controller,
          ),
        _ReaderActions(state: state, controller: controller),
        if (resolvedAnnotations.any((annotation) => !annotation.isAttached))
          const MaterialBanner(
            content: Text('部分高亮因正文变化已失联，可在“高亮与笔记”中查看'),
            actions: <Widget>[SizedBox.shrink()],
          ),
        if (content != null)
          _ArticleTtsControls(
            audio: state.audio,
            controller: controller,
          ),
        const Divider(height: 1),
        _ReaderHeader(
          detail: detail,
          enhancement: state.enhancementPhase,
          offlineArticle: state.offlineArticle,
        ),
        const Divider(height: 1),
        Expanded(
          child: content == null
              ? state.enhancementPhase == ArticleEnhancementPhase.failed
                  ? const _ReaderContentUnavailable()
                  : const _ReaderContentPending()
              : ArticleDocumentView(
                  content: content,
                  settings: state.settings,
                  initialProgress: detail.scrollDepth,
                  onProgressChanged: controller.reportProgress,
                  annotations: resolvedAnnotations,
                  onCreateAnnotation: controller.createAnnotation,
                  highlightedSegment:
                      state.audio.request?.contentRevision == content.revision
                          ? state.audio.currentSpeechSegment
                          : null,
                ),
        ),
      ],
    );
  }
}

final class _ArticleTtsControls extends StatelessWidget {
  const _ArticleTtsControls({
    required this.audio,
    required this.controller,
  });

  static const _rates = <double>[0.75, 1, 1.25, 1.5, 2, 2.5, 3];
  static const _systemVoiceId = '__river_system_voice__';

  final AudioPlaybackState audio;
  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) {
    final hasRequest = audio.request != null;
    final busy = audio.phase == AudioEnginePhase.loading || audio.restoring;
    final playing = audio.phase == AudioEnginePhase.playing;
    final segment = audio.currentSpeechSegment;
    final segmentCount = audio.request?.speechSegments.length ?? 0;
    final status = _statusLabel(audio, segment?.index, segmentCount);
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '文章朗读控制，$status',
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  IconButton(
                    onPressed: busy
                        ? null
                        : () => unawaited(controller.toggleSpeech()),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(playing ? Icons.pause : Icons.play_arrow),
                    tooltip: !hasRequest
                        ? '朗读文章'
                        : playing
                            ? '暂停朗读'
                            : '继续朗读',
                  ),
                  IconButton(
                    onPressed: controller.canQueueSpeech
                        ? () => _enqueue(context)
                        : null,
                    icon: const Icon(Icons.playlist_add),
                    tooltip: '加入收听队列',
                  ),
                  IconButton(
                    onPressed: audio.canSkipPrevious && !busy
                        ? () => unawaited(controller.skipSpeechPrevious())
                        : null,
                    icon: const Icon(Icons.skip_previous),
                    tooltip: '上一句',
                  ),
                  IconButton(
                    onPressed: hasRequest && !busy
                        ? () => unawaited(controller.restartSpeechSegment())
                        : null,
                    icon: const Icon(Icons.replay),
                    tooltip: '重读当前句',
                  ),
                  IconButton(
                    onPressed: audio.canSkipNext && !busy
                        ? () => unawaited(controller.skipSpeechNext())
                        : null,
                    icon: const Icon(Icons.skip_next),
                    tooltip: '下一句',
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 80,
                      maxWidth: 220,
                    ),
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  PopupMenuButton<double>(
                    enabled: hasRequest && !busy,
                    tooltip: '朗读速度',
                    onSelected: (rate) =>
                        unawaited(controller.setSpeechRate(rate)),
                    itemBuilder: (context) => _rates
                        .map(
                          (rate) => CheckedPopupMenuItem<double>(
                            value: rate,
                            checked: audio.settings.rate == rate,
                            child: Text('${_number(rate)} 倍速'),
                          ),
                        )
                        .toList(growable: false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Text('${_number(audio.settings.rate)}×'),
                    ),
                  ),
                  if (audio.voices.isNotEmpty)
                    PopupMenuButton<String>(
                      enabled: hasRequest && !busy,
                      tooltip: '朗读声音',
                      onSelected: (voiceId) => unawaited(
                        controller.selectSpeechVoice(
                          voiceId == _systemVoiceId ? null : voiceId,
                        ),
                      ),
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        CheckedPopupMenuItem<String>(
                          value: _systemVoiceId,
                          checked: audio.settings.voiceId == null,
                          child: const Text('系统默认声音'),
                        ),
                        ...audio.voices.map(
                          (voice) => CheckedPopupMenuItem<String>(
                            value: voice.id,
                            checked: audio.settings.voiceId == voice.id,
                            child: Text(
                              '${voice.name} · ${voice.languageTag}',
                            ),
                          ),
                        ),
                      ],
                      icon: const Icon(Icons.record_voice_over_outlined),
                    ),
                  PopupMenuButton<int>(
                    enabled: hasRequest && !busy,
                    tooltip: '定时停止',
                    onSelected: (minutes) => controller.setSpeechTimer(
                      minutes == 0 ? null : Duration(minutes: minutes),
                    ),
                    itemBuilder: (context) => <PopupMenuEntry<int>>[
                      const PopupMenuItem<int>(
                        value: 0,
                        child: Text('关闭定时'),
                      ),
                      for (final minutes in <int>[10, 20, 30, 60])
                        PopupMenuItem<int>(
                          value: minutes,
                          child: Text('$minutes 分钟后停止'),
                        ),
                    ],
                    icon: Icon(
                      audio.sleepDeadline == null
                          ? Icons.timer_outlined
                          : Icons.timer,
                    ),
                  ),
                ],
              ),
              if (audio.failureCode case final failure?)
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: colors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _failureLabel(failure),
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                    IconButton(
                      onPressed: controller.clearAudioFailure,
                      icon: const Icon(Icons.close),
                      tooltip: '关闭朗读提示',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enqueue(BuildContext context) async {
    final added = await controller.enqueueSpeech();
    if (!context.mounted || added == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(added ? '已加入收听队列' : '已在收听队列中')),
      );
  }

  static String _statusLabel(
    AudioPlaybackState audio,
    int? segmentIndex,
    int segmentCount,
  ) {
    if (audio.restoring) return '正在恢复上次朗读位置';
    if (audio.phase == AudioEnginePhase.loading) return '正在准备朗读';
    final progress = segmentIndex == null || segmentCount == 0
        ? ''
        : ' · 第 ${segmentIndex + 1}/$segmentCount 句';
    final timer = audio.sleepDeadline == null ? '' : ' · 已开启定时停止';
    final phase = switch (audio.phase) {
      AudioEnginePhase.idle => '点击播放开始朗读',
      AudioEnginePhase.ready => '朗读已就绪',
      AudioEnginePhase.playing => '正在朗读',
      AudioEnginePhase.paused => '朗读已暂停',
      AudioEnginePhase.stopped => '朗读已停止',
      AudioEnginePhase.completed => '朗读已完成',
      AudioEnginePhase.interrupted => '朗读被系统中断',
      AudioEnginePhase.failed => '朗读暂不可用',
      AudioEnginePhase.loading => '正在准备朗读',
    };
    return '$phase$progress$timer';
  }

  static String _failureLabel(String code) => switch (code) {
        'audio_kind_unsupported' => '当前设备不支持文章朗读',
        'audio_voice_unavailable' => '所选声音不可用，请重新选择',
        'audio_progress_save_failed' => '朗读进度暂时无法保存',
        'audio_invalid_sleep_timer' => '定时时长无效',
        _ => '朗读遇到问题，请重试',
      };

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

final class _EnhancementFailureBanner extends StatelessWidget {
  const _EnhancementFailureBanner({
    required this.hasAvailableContent,
    required this.controller,
  });

  final bool hasAvailableContent;
  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) {
    final label =
        hasAvailableContent ? '未能获取完整正文，Feed 或缓存内容仍可阅读' : '未能获取可阅读正文，可以重试或打开原文';
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ColoredBox(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.info_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  if (hasAvailableContent)
                    TextButton(
                      onPressed: controller.useAvailableContent,
                      child: const Text('使用当前内容'),
                    ),
                  FilledButton.tonal(
                    onPressed: () => unawaited(controller.retryEnhancement()),
                    child: const Text('重试全文'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(controller.openOriginal()),
                    child: const Text('打开原文'),
                  ),
                  TextButton(
                    onPressed: () => unawaited(
                      controller.reportExtractionIssue(
                        anchor: _shareAnchorFor(context),
                      ),
                    ),
                    child: const Text('报告问题'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReaderActions extends StatelessWidget {
  const _ReaderActions({required this.state, required this.controller});

  final ArticleReaderState state;
  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail!;
    return Semantics(
      container: true,
      label: '文章状态与阅读操作',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: state.isMutating
                  ? null
                  : () => unawaited(controller.toggleRead()),
              icon: Icon(detail.read ? Icons.mark_email_unread : Icons.done),
              tooltip: detail.read ? '标记未读' : '标记已读',
            ),
            IconButton(
              onPressed: state.isMutating
                  ? null
                  : () => unawaited(controller.toggleStarred()),
              icon: Icon(detail.starred ? Icons.star : Icons.star_outline),
              tooltip: detail.starred ? '取消收藏' : '收藏',
            ),
            IconButton(
              onPressed: state.isMutating
                  ? null
                  : () => unawaited(controller.toggleReadLater()),
              icon: Icon(
                detail.readLater ? Icons.bookmark : Icons.bookmark_outline,
              ),
              tooltip: detail.readLater ? '移出稍后读' : '稍后读',
            ),
            IconButton(
              onPressed: () => unawaited(_share(context)),
              icon: const Icon(Icons.share_outlined),
              tooltip: '分享',
            ),
            IconButton(
              onPressed: () => unawaited(controller.openOriginal()),
              icon: const Icon(Icons.open_in_new),
              tooltip: '打开原文',
            ),
            IconButton(
              onPressed: state.annotations.isEmpty
                  ? null
                  : () => unawaited(
                        _showAnnotations(context, state, controller),
                      ),
              icon: Badge.count(
                count: state.annotations.length,
                isLabelVisible: state.annotations.isNotEmpty,
                child: const Icon(Icons.highlight_outlined),
              ),
              tooltip: state.annotations.isEmpty ? '选择正文即可添加高亮' : '高亮与笔记',
            ),
            IconButton(
              onPressed:
                  !controller.canSaveToKnowledge || state.isSavingKnowledge
                      ? null
                      : () => unawaited(_saveToKnowledge(context)),
              icon: state.isSavingKnowledge
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      state.knowledgeItemId == null
                          ? Icons.library_add_outlined
                          : Icons.library_add_check,
                    ),
              tooltip: state.knowledgeItemId == null ? '保存到知识库' : '更新知识库内容',
            ),
            _OfflineArticleAction(state: state, controller: controller),
            IconButton(
              onPressed: () => unawaited(
                _showReaderSettings(context, state.settings, controller),
              ),
              icon: const Icon(Icons.text_fields),
              tooltip: '阅读排版',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    await controller.shareArticle(anchor: _shareAnchorFor(context));
  }

  Future<void> _saveToKnowledge(BuildContext context) async {
    final saved = await controller.saveToKnowledge();
    if (!context.mounted || saved == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('已保存到知识库，高亮与笔记已一并保留')),
      );
  }
}

final class _OfflineArticleAction extends StatelessWidget {
  const _OfflineArticleAction({required this.state, required this.controller});

  final ArticleReaderState state;
  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) {
    final phase =
        state.offlineArticle?.phase ?? OfflineArticlePhase.notDownloaded;
    return switch (phase) {
      OfflineArticlePhase.notDownloaded => IconButton(
          onPressed: () => unawaited(controller.downloadForOffline()),
          icon: const Icon(Icons.download_for_offline_outlined),
          tooltip: '离线下载',
        ),
      OfflineArticlePhase.queued => const IconButton(
          onPressed: null,
          icon: Icon(Icons.cloud_queue),
          tooltip: '等待离线下载',
        ),
      OfflineArticlePhase.downloading => const IconButton(
          onPressed: null,
          icon: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          tooltip: '正在离线下载',
        ),
      OfflineArticlePhase.available => const IconButton(
          onPressed: null,
          icon: Icon(Icons.offline_pin_outlined),
          tooltip: '已可离线阅读',
        ),
      OfflineArticlePhase.failed => IconButton(
          onPressed: () => unawaited(controller.retryOfflineDownload()),
          icon: const Icon(Icons.sync_problem_outlined),
          tooltip: '重试离线下载',
        ),
    };
  }
}

final class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.detail,
    required this.enhancement,
    required this.offlineArticle,
  });

  final FeedArticleDetailRecord detail;
  final ArticleEnhancementPhase enhancement;
  final OfflineArticleState? offlineArticle;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      detail.feedTitle,
      if (detail.author?.trim() case final author? when author.isNotEmpty)
        author,
      if (detail.publishedAt case final date?) _dateLabel(date),
    ].join(' · ');
    final (status, icon) = switch (enhancement) {
      ArticleEnhancementPhase.idle => ('正在准备正文', Icons.hourglass_empty),
      ArticleEnhancementPhase.enhancing => (
          '已显示可用内容，正在获取完整正文',
          Icons.downloading_outlined
        ),
      ArticleEnhancementPhase.ready => ('完整正文已就绪', Icons.check_circle_outline),
      ArticleEnhancementPhase.failed => ('完整正文暂不可用', Icons.info_outline),
      ArticleEnhancementPhase.usingAvailable => (
          '正在使用 Feed 或缓存内容',
          Icons.article_outlined
        ),
    };
    final offlineStatus = switch (offlineArticle?.phase) {
      OfflineArticlePhase.queued => ('已排队，联网后自动完成离线下载', Icons.cloud_queue),
      OfflineArticlePhase.downloading => ('正在保存以供离线阅读', Icons.downloading),
      OfflineArticlePhase.available => ('已可离线阅读', Icons.offline_pin_outlined),
      OfflineArticlePhase.failed => ('离线下载失败，可以重试', Icons.sync_problem),
      OfflineArticlePhase.notDownloaded || null => null,
    };
    return Semantics(
      container: true,
      label: '${detail.title}，$metadata，$status'
          '${offlineStatus == null ? '' : '，${offlineStatus.$1}'}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                detail.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            Text(metadata, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              label: status,
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status)),
                ],
              ),
            ),
            if (offlineStatus case final value?) ...<Widget>[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                label: value.$1,
                child: Row(
                  children: <Widget>[
                    Icon(value.$2, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(value.$1)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class ArticleDocumentView extends StatefulWidget {
  const ArticleDocumentView({
    required this.content,
    required this.settings,
    required this.initialProgress,
    required this.onProgressChanged,
    this.annotations = const <ResolvedArticleAnnotation>[],
    this.onCreateAnnotation,
    this.highlightedSegment,
    super.key,
  });

  final ArticleReaderContent content;
  final ReaderSettings settings;
  final double initialProgress;
  final ValueChanged<double> onProgressChanged;
  final List<ResolvedArticleAnnotation> annotations;
  final ArticleAnnotationCreator? onCreateAnnotation;
  final SpeechSegment? highlightedSegment;

  @override
  State<ArticleDocumentView> createState() => ArticleDocumentViewState();
}

final class ArticleDocumentViewState extends State<ArticleDocumentView> {
  late final ScrollController _scrollController;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late TextSelection _lastSelection;
  late String _displayedRevision;
  String? _pendingText;
  String? _pendingRevision;
  var _updatingText = false;
  var _restoredInitialProgress = false;

  TextSelection get selection => _textController.selection;
  String get documentText => _textController.text;
  TextRange? get highlightedRange =>
      (_textController as _HighlightingTextEditingController).highlightedRange;
  double get scrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0;
  String get selectedText {
    final current = selection;
    if (!current.isValid || current.isCollapsed) return '';
    return _textController.text.substring(current.start, current.end);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_reportProgress);
    _textController = _HighlightingTextEditingController(
      text: widget.content.text,
      highlightedSegment: widget.highlightedSegment,
      annotations: widget.annotations,
    )..addListener(_handleSelectionChange);
    _lastSelection = _textController.selection;
    _displayedRevision = widget.content.revision;
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreProgress());
  }

  @override
  void didUpdateWidget(ArticleDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content.text != oldWidget.content.text) {
      if (_replacePreservingAnchors(widget.content.text)) {
        _displayedRevision = widget.content.revision;
        _pendingText = null;
        _pendingRevision = null;
      } else {
        _pendingRevision = widget.content.revision;
      }
    } else if (widget.content.revision != oldWidget.content.revision) {
      if (_pendingText == null) {
        _displayedRevision = widget.content.revision;
      } else {
        _pendingRevision = widget.content.revision;
      }
    }
    if (widget.highlightedSegment != oldWidget.highlightedSegment) {
      (_textController as _HighlightingTextEditingController)
          .setHighlightedSegment(widget.highlightedSegment);
    }
    if (!identical(widget.annotations, oldWidget.annotations)) {
      (_textController as _HighlightingTextEditingController)
          .setAnnotations(widget.annotations);
    }
  }

  void selectRange(int start, int end) {
    _textController.selection =
        TextSelection(baseOffset: start, extentOffset: end);
    _focusNode.requestFocus();
  }

  void scrollToFraction(double fraction) {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(
      _scrollController.position.maxScrollExtent * fraction.clamp(0, 1),
    );
  }

  void _restoreProgress() {
    if (!mounted || _restoredInitialProgress || !_scrollController.hasClients) {
      return;
    }
    _restoredInitialProgress = true;
    final extent = _scrollController.position.maxScrollExtent;
    if (extent > 0) {
      _scrollController.jumpTo(
        extent * widget.initialProgress.clamp(0, 1).toDouble(),
      );
    }
  }

  void _reportProgress() {
    if (!_scrollController.hasClients) return;
    final extent = _scrollController.position.maxScrollExtent;
    final progress = extent <= 0
        ? 1.0
        : (_scrollController.offset / extent).clamp(0, 1).toDouble();
    widget.onProgressChanged(progress);
  }

  void _handleSelectionChange() {
    if (_updatingText) return;
    if (_pendingText != null && selection.isCollapsed) {
      final pending = _pendingText!;
      _pendingText = null;
      if (_replacePreservingAnchors(pending)) {
        _displayedRevision = _pendingRevision ?? _displayedRevision;
        _pendingRevision = null;
      }
    }
    final current = selection;
    if (current == _lastSelection) return;
    _lastSelection = current;
    if (mounted) setState(() {});
  }

  Future<void> _createAnnotation({String? note}) async {
    final create = widget.onCreateAnnotation;
    final current = selection;
    if (create == null ||
        !current.isValid ||
        current.isCollapsed ||
        current.start < 0 ||
        current.end > documentText.length) {
      return;
    }
    await create(
      anchor: ArticleTextAnchor.capture(
        document: DocumentTextSnapshot.single(documentText),
        start: current.start,
        end: current.end,
        contentRevision: _displayedRevision,
      ),
      note: note,
      color: ArticleAnnotationColor.yellow,
    );
    if (!mounted) return;
    _textController.selection = TextSelection.collapsed(offset: current.end);
  }

  Future<void> _createAnnotationWithNote() async {
    final note = await _requestAnnotationNote(context);
    if (note != null) await _createAnnotation(note: note);
  }

  bool _replacePreservingAnchors(String nextText) {
    final previousText = _textController.text;
    if (previousText == nextText) return true;
    final previousSelection = _textController.selection;
    final mappedSelection = _mapSelection(
      previousText,
      nextText,
      previousSelection,
    );
    if (!previousSelection.isCollapsed && mappedSelection == null) {
      _pendingText = nextText;
      return false;
    }

    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = scrollOffset;
    final oldAnchor = previousText.isEmpty || oldExtent <= 0
        ? 0
        : (previousText.length * (oldOffset / oldExtent))
            .round()
            .clamp(0, previousText.length);
    final mappedAnchor = _mapOffset(previousText, nextText, oldAnchor);
    _updatingText = true;
    _textController.value = TextEditingValue(
      text: nextText,
      selection: mappedSelection ??
          TextSelection.collapsed(
            offset: _mapOffset(
              previousText,
              nextText,
              previousSelection.extentOffset.clamp(0, previousText.length),
            ),
          ),
    );
    _updatingText = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || nextText.isEmpty) return;
      final extent = _scrollController.position.maxScrollExtent;
      final target = extent * (mappedAnchor / nextText.length);
      _scrollController.jumpTo(target.clamp(0, extent));
    });
    return true;
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleSelectionChange)
      ..dispose();
    _scrollController
      ..removeListener(_reportProgress)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.settings.contentWidth),
            child: Semantics(
              container: true,
              label: '文章正文',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    readOnly: true,
                    maxLines: null,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    decoration: const InputDecoration.collapsed(hintText: ''),
                    style: _readerTextStyle(textTheme, widget.settings),
                  ),
                  if (selection.isValid &&
                      !selection.isCollapsed &&
                      widget.onCreateAnnotation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: () => unawaited(_createAnnotation()),
                            icon: const Icon(Icons.highlight),
                            label: const Text('高亮'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                unawaited(_createAnnotationWithNote()),
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('高亮并添加笔记'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _HighlightingTextEditingController extends TextEditingController {
  _HighlightingTextEditingController({
    required String text,
    SpeechSegment? highlightedSegment,
    List<ResolvedArticleAnnotation> annotations =
        const <ResolvedArticleAnnotation>[],
  })  : _highlightedRange = _rangeFor(text, highlightedSegment),
        _annotations = annotations,
        super(text: text);

  TextRange? _highlightedRange;
  List<ResolvedArticleAnnotation> _annotations;

  TextRange? get highlightedRange => _highlightedRange;

  void setHighlightedSegment(SpeechSegment? segment) {
    final next = _rangeFor(text, segment);
    if (_sameRange(_highlightedRange, next)) return;
    _highlightedRange = next;
    notifyListeners();
  }

  void setAnnotations(List<ResolvedArticleAnnotation> annotations) {
    _annotations = annotations;
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    super.value = newValue;
    final range = _highlightedRange;
    if (range != null && range.end > newValue.text.length) {
      _highlightedRange = null;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final range = _highlightedRange;
    final attached = _annotations
        .where(
          (annotation) =>
              annotation.isAttached &&
              annotation.start! >= 0 &&
              annotation.end! <= text.length &&
              annotation.start! < annotation.end!,
        )
        .toList(growable: false);
    if ((range == null || range.isCollapsed || range.end > text.length) &&
        attached.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final foreground = style?.color ?? Theme.of(context).colorScheme.onSurface;
    final boundaries = <int>{0, text.length};
    if (range != null && range.end <= text.length) {
      boundaries
        ..add(range.start)
        ..add(range.end);
    }
    for (final annotation in attached) {
      boundaries
        ..add(annotation.start!)
        ..add(annotation.end!);
    }
    final ordered = boundaries.toList()..sort();
    return TextSpan(
      style: style,
      children: <InlineSpan>[
        for (var index = 0; index + 1 < ordered.length; index += 1)
          _annotationSpan(
            text,
            ordered[index],
            ordered[index + 1],
            attached,
            range,
            foreground,
          ),
      ],
    );
  }

  static TextRange? _rangeFor(String text, SpeechSegment? segment) {
    if (segment == null ||
        segment.sourceStart < 0 ||
        segment.sourceStart >= segment.sourceEnd ||
        segment.sourceEnd > text.length) {
      return null;
    }
    return TextRange(start: segment.sourceStart, end: segment.sourceEnd);
  }

  static bool _sameRange(TextRange? left, TextRange? right) =>
      left?.start == right?.start && left?.end == right?.end;
}

TextSpan _annotationSpan(
  String text,
  int start,
  int end,
  List<ResolvedArticleAnnotation> annotations,
  TextRange? speechRange,
  Color foreground,
) {
  ArticleAnnotationColor? color;
  for (final annotation in annotations) {
    if (annotation.start! <= start && annotation.end! >= end) {
      color = annotation.annotation.color;
    }
  }
  final spoken = speechRange != null &&
      speechRange.start <= start &&
      speechRange.end >= end;
  return TextSpan(
    text: text.substring(start, end),
    style: TextStyle(
      backgroundColor: color == null
          ? spoken
              ? foreground.withValues(alpha: 0.16)
              : null
          : _annotationColor(color).withValues(alpha: 0.34),
      fontWeight: spoken ? FontWeight.w600 : null,
      decoration: spoken && color != null ? TextDecoration.underline : null,
    ),
  );
}

TextStyle _readerTextStyle(TextTheme textTheme, ReaderSettings settings) {
  final base = textTheme.bodyLarge ?? const TextStyle(fontSize: 18);
  final baseSize = base.fontSize ?? 18;
  final (fontFamily, fallbacks) = switch (settings.fontFamily) {
    ReaderFontFamily.system => (null, null),
    ReaderFontFamily.serif => (
        'Noto Serif CJK SC',
        const <String>['Songti SC', 'SimSun', 'Georgia'],
      ),
    ReaderFontFamily.sansSerif => (
        'Noto Sans CJK SC',
        const <String>['Microsoft YaHei', 'Arial'],
      ),
  };
  return base.copyWith(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbacks,
    fontSize: baseSize * settings.fontScale,
    height: settings.lineHeight,
  );
}

Future<void> _showReaderSettings(
  BuildContext context,
  ReaderSettings initial,
  ArticleReaderController controller,
) async {
  var working = initial;
  final result = await showDialog<ReaderSettings>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocalState) => AlertDialog(
        title: const Text('阅读排版'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<ReaderFontFamily>(
                  initialValue: working.fontFamily,
                  decoration: const InputDecoration(labelText: '字体'),
                  items: const <DropdownMenuItem<ReaderFontFamily>>[
                    DropdownMenuItem(
                      value: ReaderFontFamily.system,
                      child: Text('系统字体'),
                    ),
                    DropdownMenuItem(
                      value: ReaderFontFamily.serif,
                      child: Text('衬线字体'),
                    ),
                    DropdownMenuItem(
                      value: ReaderFontFamily.sansSerif,
                      child: Text('无衬线字体'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setLocalState(
                        () => working = working.copyWith(fontFamily: value),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('字号 ${(working.fontScale * 100).round()}%'),
                Slider(
                  value: working.fontScale,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  label: '${(working.fontScale * 100).round()}%',
                  onChanged: (value) => setLocalState(
                    () => working = working.copyWith(fontScale: value),
                  ),
                ),
                Text('行距 ${working.lineHeight.toStringAsFixed(2)}'),
                Slider(
                  value: working.lineHeight,
                  min: 1.3,
                  max: 2.2,
                  divisions: 9,
                  label: working.lineHeight.toStringAsFixed(2),
                  onChanged: (value) => setLocalState(
                    () => working = working.copyWith(lineHeight: value),
                  ),
                ),
                Text('页面宽度 ${working.contentWidth.round()} px'),
                Slider(
                  value: working.contentWidth,
                  min: 480,
                  max: 1000,
                  divisions: 13,
                  label: '${working.contentWidth.round()} px',
                  onChanged: (value) => setLocalState(
                    () => working = working.copyWith(contentWidth: value),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ReaderThemePreference>(
                  segments: const <ButtonSegment<ReaderThemePreference>>[
                    ButtonSegment(
                      value: ReaderThemePreference.system,
                      label: Text('跟随系统'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ReaderThemePreference.light,
                      label: Text('浅色'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ReaderThemePreference.dark,
                      label: Text('深色'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: <ReaderThemePreference>{working.theme},
                  onSelectionChanged: (selection) => setLocalState(
                    () => working = working.copyWith(theme: selection.single),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => setLocalState(
              () => working = const ReaderSettings(),
            ),
            child: const Text('恢复默认'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(working),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  if (result != null) await controller.saveSettings(result);
}

TextSelection? _mapSelection(
  String previous,
  String next,
  TextSelection selection,
) {
  if (!selection.isValid) return const TextSelection.collapsed(offset: 0);
  final start = selection.start.clamp(0, previous.length);
  final end = selection.end.clamp(start, previous.length);
  if (start == end) {
    return TextSelection.collapsed(offset: _mapOffset(previous, next, start));
  }
  final selected = previous.substring(start, end);
  final matches = <int>[];
  var from = 0;
  while (from <= next.length - selected.length) {
    final match = next.indexOf(selected, from);
    if (match < 0) break;
    matches.add(match);
    from = match + selected.length.clamp(1, selected.length);
  }
  if (matches.isEmpty) return null;
  final expected =
      previous.isEmpty ? 0 : (next.length * (start / previous.length)).round();
  matches.sort(
    (left, right) =>
        (left - expected).abs().compareTo((right - expected).abs()),
  );
  final mappedStart = matches.first;
  return TextSelection(
    baseOffset: mappedStart,
    extentOffset: mappedStart + selected.length,
  );
}

int _mapOffset(String previous, String next, int offset) {
  if (next.isEmpty || previous.isEmpty) return 0;
  final safeOffset = offset.clamp(0, previous.length);
  final contextStart = (safeOffset - 24).clamp(0, previous.length);
  final contextEnd = (safeOffset + 24).clamp(contextStart, previous.length);
  final context = previous.substring(contextStart, contextEnd);
  if (context.isNotEmpty) {
    final match = next.indexOf(context);
    if (match >= 0) {
      return (match + safeOffset - contextStart).clamp(0, next.length);
    }
  }
  return (next.length * (safeOffset / previous.length))
      .round()
      .clamp(0, next.length);
}

final class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: '正在打开文章',
          child: const CircularProgressIndicator(),
        ),
      );
}

final class _ReaderContentPending extends StatelessWidget {
  const _ReaderContentPending();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: 'Feed 没有提供正文，正在获取完整内容',
          child: const Text('Feed 没有提供正文，正在获取完整内容…'),
        ),
      );
}

final class _ReaderContentUnavailable extends StatelessWidget {
  const _ReaderContentUnavailable();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '未能获取可阅读正文，请重试全文或打开原文',
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text('未能获取可阅读正文，请重试全文或打开原文'),
          ),
        ),
      );
}

final class _ReaderMissing extends StatelessWidget {
  const _ReaderMissing();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          container: true,
          label: '文章不存在或已被删除',
          child: const Text('文章不存在或已被删除'),
        ),
      );
}

final class _ReaderFailure extends StatelessWidget {
  const _ReaderFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '文章打开失败，可以重试',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text('无法打开文章'),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

ShareAnchor? _shareAnchorFor(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero);
  return ShareAnchor(
    left: origin.dx,
    top: origin.dy,
    width: box.size.width,
    height: box.size.height,
  );
}
