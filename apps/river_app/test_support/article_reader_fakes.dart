import 'dart:async';

import 'package:river_app/app/article_reader.dart';
import 'package:river_app/app/article_summary.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

final class FakeArticleReaderRepository implements ArticleReaderRepository {
  FakeArticleReaderRepository(this.watch);

  final Stream<FeedArticleDetailRecord?> Function(String articleId) watch;
  final List<bool> readWrites = <bool>[];
  final List<bool> starredWrites = <bool>[];
  final List<bool> readLaterWrites = <bool>[];
  final List<double> progressWrites = <double>[];

  @override
  Stream<FeedArticleDetailRecord?> watchArticle(String articleId) =>
      watch(articleId);

  @override
  Future<void> setRead(
    String articleId, {
    required bool read,
    required DateTime updatedAt,
  }) async {
    readWrites.add(read);
  }

  @override
  Future<void> setStarred(
    String articleId, {
    required bool starred,
    required DateTime updatedAt,
  }) async {
    starredWrites.add(starred);
  }

  @override
  Future<void> setReadLater(
    String articleId, {
    required bool readLater,
    required DateTime updatedAt,
  }) async {
    readLaterWrites.add(readLater);
  }

  @override
  Future<void> saveReadingProgress(
    String articleId, {
    required double scrollDepth,
    required DateTime updatedAt,
  }) async {
    progressWrites.add(scrollDepth);
  }
}

final class FakeExtractor implements FullTextExtractor {
  const FakeExtractor(this.load);

  final Future<ExtractionResult> Function(ExtractionRequest request) load;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) => load(request);
}

final class FakeReaderSettingsRepository implements ReaderSettingsRepository {
  FakeReaderSettingsRepository({
    ReaderSettings initial = const ReaderSettings(),
  }) : _current = initial;

  ReaderSettings _current;
  final StreamController<ReaderSettings> _changes =
      StreamController<ReaderSettings>.broadcast();

  ReaderSettings get current => _current;

  @override
  Stream<ReaderSettings> watchSettings() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> saveSettings(
    ReaderSettings settings, {
    required DateTime updatedAt,
  }) async {
    _current = settings;
    _changes.add(settings);
  }

  Future<void> close() => _changes.close();
}

final class FakeArticleAnnotationRepository
    implements ArticleAnnotationRepository {
  final List<ArticleAnnotation> annotations = <ArticleAnnotation>[];
  final StreamController<List<ArticleAnnotation>> _changes =
      StreamController<List<ArticleAnnotation>>.broadcast();

  @override
  Stream<List<ArticleAnnotation>> watchArticleAnnotations(
    String articleId,
  ) async* {
    yield _forArticle(articleId);
    yield* _changes.stream.map(
      (values) => values
          .where((annotation) => annotation.articleId == articleId)
          .toList(growable: false),
    );
  }

  @override
  Future<void> upsertAnnotation(ArticleAnnotation annotation) async {
    annotations.removeWhere((value) => value.id == annotation.id);
    annotations.add(annotation);
    _changes.add(List<ArticleAnnotation>.unmodifiable(annotations));
  }

  @override
  Future<void> deleteAnnotation(String annotationId) async {
    annotations.removeWhere((value) => value.id == annotationId);
    _changes.add(List<ArticleAnnotation>.unmodifiable(annotations));
  }

  List<ArticleAnnotation> _forArticle(String articleId) => annotations
      .where((annotation) => annotation.articleId == articleId)
      .toList(growable: false);

  Future<void> close() => _changes.close();
}

final class FakeShareGateway implements ShareGateway {
  ShareRequest? lastRequest;
  ShareOutcome outcome = ShareOutcome.completed;

  @override
  Future<ShareOutcome> share(ShareRequest request) async {
    lastRequest = request;
    return outcome;
  }
}

final class FakeExternalUriGateway implements ExternalUriGateway {
  Uri? lastUri;
  ExternalUriOpenOutcome outcome = ExternalUriOpenOutcome.opened;

  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async {
    lastUri = uri;
    return outcome;
  }
}

final class FakeOfflineArticleManager implements OfflineArticleManager {
  final Map<String, OfflineArticleState> _states =
      <String, OfflineArticleState>{};
  final StreamController<OfflineArticleState> _changes =
      StreamController<OfflineArticleState>.broadcast();
  final List<String> enqueued = <String>[];
  final List<String> retried = <String>[];

  @override
  Future<void> enqueue(String articleId) async {
    enqueued.add(articleId);
    emit(
      OfflineArticleState(
        articleId: articleId,
        phase: OfflineArticlePhase.queued,
      ),
    );
  }

  @override
  Future<void> resumePending() async {}

  @override
  Future<void> retry(String articleId) async {
    retried.add(articleId);
    emit(
      OfflineArticleState(
        articleId: articleId,
        phase: OfflineArticlePhase.queued,
      ),
    );
  }

  @override
  Future<OfflineArticleState> status(String articleId) async =>
      _states[articleId] ?? OfflineArticleState.notDownloaded(articleId);

  @override
  Stream<OfflineArticleState> watch(String articleId) async* {
    yield await status(articleId);
    yield* _changes.stream.where((state) => state.articleId == articleId);
  }

  void emit(OfflineArticleState state) {
    _states[state.articleId] = state;
    _changes.add(state);
  }

  Future<void> close() => _changes.close();
}

final class FixedReaderClock implements Clock {
  const FixedReaderClock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 19, 8);
}

final class SequentialReaderIds implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'annotation-${++_next}';
}

final class FakeArticleAudioEngine implements AudioEngine {
  final StreamController<AudioEngineEvent> _events =
      StreamController<AudioEngineEvent>.broadcast(sync: true);
  final List<AudioPlaybackSettings> settingsWrites = <AudioPlaybackSettings>[];
  final List<AudioPlaybackPosition> seeks = <AudioPlaybackPosition>[];
  AudioLoadRequest? loaded;
  AudioPlaybackPosition? position;
  var playCalls = 0;
  var pauseCalls = 0;

  @override
  Stream<AudioEngineEvent> get events => _events.stream;

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      const AudioEngineCapabilities(
        supportsArticleTts: true,
        supportsPodcastMedia: false,
        canPause: true,
        canResume: true,
        canSeek: true,
        canSetRate: true,
        canSetPitch: true,
        canSelectVoice: true,
      );

  @override
  Future<List<AudioVoice>> voices() async => const <AudioVoice>[
        AudioVoice(
          id: 'local-zh',
          name: '本地中文',
          languageTag: 'zh-CN',
          isLocal: true,
        ),
      ];

  @override
  Future<void> load(AudioLoadRequest request) async {
    loaded = request;
    position = const AudioPlaybackPosition.speech(segmentIndex: 0);
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.ready,
        itemId: request.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.playing,
        itemId: loaded?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.paused,
        itemId: loaded?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> resume() => play();

  @override
  Future<void> seek(AudioPlaybackPosition position) async {
    this.position = position;
    seeks.add(position);
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.ready,
        itemId: loaded?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _events.add(
      AudioEngineEvent(
        phase: AudioEnginePhase.stopped,
        itemId: loaded?.item.id,
        position: position,
      ),
    );
  }

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {
    settingsWrites.add(settings);
  }

  @override
  Future<void> dispose() => _events.close();
}

final class MemoryAudioPlaybackRepository implements AudioPlaybackRepository {
  final Map<String, AudioPlaybackSnapshot> values =
      <String, AudioPlaybackSnapshot>{};

  @override
  Future<AudioPlaybackSnapshot?> read(String itemId) async => values[itemId];

  @override
  Future<void> save(AudioPlaybackSnapshot snapshot) async {
    values[snapshot.item.id] = snapshot;
  }

  @override
  Future<void> clear(String itemId) async {
    values.remove(itemId);
  }
}

final class MemoryKnowledgeRepository implements KnowledgeRepository {
  final List<KnowledgeItem> items = <KnowledgeItem>[];
  final List<KnowledgeExternalMapping> mappings = <KnowledgeExternalMapping>[];
  final StreamController<void> _changes =
      StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<KnowledgeItem>> watchItems() async* {
    yield List<KnowledgeItem>.unmodifiable(items);
    yield* _changes.stream.map(
      (_) => List<KnowledgeItem>.unmodifiable(items),
    );
  }

  @override
  Stream<KnowledgeItem?> watchItem(String itemId) async* {
    yield _item(itemId);
    yield* _changes.stream.map((_) => _item(itemId));
  }

  @override
  Future<KnowledgeItem?> findBySource(
    KnowledgeSourceReference source,
  ) async {
    for (final item in items) {
      if (item.source.stableKey == source.stableKey) return item;
    }
    return null;
  }

  @override
  Future<KnowledgeItem> saveItem(KnowledgeItem item) async {
    final existing = await findBySource(item.source);
    final stored = existing == null
        ? item
        : item.withId(existing.id, savedAt: existing.savedAt);
    items.removeWhere(
      (value) =>
          value.id == stored.id ||
          value.source.stableKey == stored.source.stableKey,
    );
    items.add(stored);
    _changes.add(null);
    return stored;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    items.removeWhere((item) => item.id == itemId);
    mappings.removeWhere((mapping) => mapping.knowledgeItemId == itemId);
    _changes.add(null);
  }

  @override
  Stream<List<KnowledgeExternalMapping>> watchExternalMappings(
    String itemId,
  ) async* {
    List<KnowledgeExternalMapping> current() => mappings
        .where((mapping) => mapping.knowledgeItemId == itemId)
        .toList(growable: false);
    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Future<void> upsertExternalMapping(KnowledgeExternalMapping mapping) async {
    mappings.removeWhere((value) => value.stableKey == mapping.stableKey);
    mappings.add(mapping);
    _changes.add(null);
  }

  @override
  Future<void> deleteExternalMapping({
    required String knowledgeItemId,
    required String connectorId,
    required String destinationId,
  }) async {
    mappings.removeWhere(
      (mapping) =>
          mapping.knowledgeItemId == knowledgeItemId &&
          mapping.connectorId == connectorId &&
          mapping.destinationId == destinationId,
    );
    _changes.add(null);
  }

  Future<void> close() => _changes.close();

  KnowledgeItem? _item(String itemId) {
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }
}

ArticleReaderController buildReaderController({
  required String articleId,
  required Stream<FeedArticleDetailRecord?> Function(String articleId) watch,
  required Future<ExtractionResult> Function(ExtractionRequest request) extract,
  FakeArticleReaderRepository? repository,
  FakeReaderSettingsRepository? settings,
  FakeArticleAnnotationRepository? annotations,
  IdGenerator? ids,
  FakeShareGateway? share,
  FakeExternalUriGateway? externalUri,
  FakeOfflineArticleManager? offlineArticles,
  AudioEngine audio = const UnavailableAudioEngine(),
  AudioPlaybackRepository audioPlayback =
      const UnavailableAudioPlaybackRepository(),
  KnowledgeRepository? knowledge,
  ArticleSummaryExperience? summaries,
}) =>
    ArticleReaderController(
      articleId: articleId,
      repository: repository ?? FakeArticleReaderRepository(watch),
      extractor: FakeExtractor(extract),
      readerSettings: settings ?? FakeReaderSettingsRepository(),
      annotations:
          annotations ?? const UnavailableArticleAnnotationRepository(),
      ids: ids,
      share: share ?? FakeShareGateway(),
      externalUri: externalUri ?? FakeExternalUriGateway(),
      offlineArticles: offlineArticles ?? FakeOfflineArticleManager(),
      clock: const FixedReaderClock(),
      audio: audio,
      audioPlayback: audioPlayback,
      knowledge: knowledge,
      summaries: summaries,
    );
