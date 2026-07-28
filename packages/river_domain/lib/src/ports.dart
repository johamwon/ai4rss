import 'audio.dart';
import 'models.dart';

abstract interface class Clock {
  DateTime now();
}

abstract interface class IdGenerator {
  String next();
}

final class PortHttpResponse {
  const PortHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const <String, String>{},
    this.effectiveUri,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final Uri? effectiveUri;
}

abstract interface class HttpPort {
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  });
}

abstract interface class FullTextExtractor {
  Future<ExtractionResult> extract(ExtractionRequest request);
}

abstract interface class DynamicPageRenderer {
  Future<DynamicPageRenderResult> render(DynamicPageRenderRequest request);
}

abstract interface class ExtractionCache {
  Future<CachedExtraction?> read({
    required Uri sourceUri,
    String? articleId,
  });

  Future<void> writeSuccess({
    required String articleId,
    required ExtractedArticle article,
    required String contentHash,
    required DateTime extractedAt,
    String? etag,
    String? lastModified,
  });

  Future<void> writeFailure({
    required String articleId,
    required ExtractionFailureCode failureCode,
    required String extractorVersion,
    required DateTime attemptedAt,
    String? etag,
    String? lastModified,
  });
}

abstract interface class AiProvider {
  Future<ArticleSummary> summarize(Article article);
}

abstract interface class ReaderSettingsRepository {
  Stream<ReaderSettings> watchSettings();

  Future<void> saveSettings(
    ReaderSettings settings, {
    required DateTime updatedAt,
  });
}

abstract interface class ShareGateway {
  Future<ShareOutcome> share(ShareRequest request);
}

enum ExternalUriOpenOutcome { opened, unavailable }

abstract interface class ExternalUriGateway {
  Future<ExternalUriOpenOutcome> open(Uri uri);
}

final class UnavailableExternalUriGateway implements ExternalUriGateway {
  const UnavailableExternalUriGateway();

  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async =>
      ExternalUriOpenOutcome.unavailable;
}

abstract interface class AudioEngine {
  Stream<AudioEngineEvent> get events;

  Future<AudioEngineCapabilities> capabilities();
  Future<List<AudioVoice>> voices();
  Future<void> load(AudioLoadRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(AudioPlaybackPosition position);
  Future<void> updateSettings(AudioPlaybackSettings settings);
  Future<void> dispose();
}

abstract interface class AudioPlaybackRepository {
  Future<AudioPlaybackSnapshot?> read(String itemId);
  Future<void> save(AudioPlaybackSnapshot snapshot);
  Future<void> clear(String itemId);
}

abstract interface class AudioQueueRepository {
  Stream<AudioQueueSnapshot> watch();
  Future<AudioQueueSnapshot> read();

  Future<bool> enqueue({
    required AudioItem item,
    required String? contentRevision,
    required DateTime enqueuedAt,
  });

  Future<void> move({
    required String itemId,
    required int targetIndex,
    required DateTime updatedAt,
  });

  Future<void> select({
    required String itemId,
    required DateTime updatedAt,
  });

  Future<void> remove({
    required String itemId,
    required DateTime updatedAt,
  });

  Future<AudioQueueEntry?> consumeCurrent({required DateTime updatedAt});
  Future<void> clear();
}

abstract interface class AudioSystemSession {
  Stream<AudioSystemEvent> get events;

  Future<bool> activate();
  Future<void> deactivate();
  Future<void> publish(AudioSystemPlaybackState state);
  Future<void> clear();
  Future<void> dispose();
}

final class UnavailableAudioSystemSession implements AudioSystemSession {
  const UnavailableAudioSystemSession();

  @override
  Stream<AudioSystemEvent> get events => const Stream<AudioSystemEvent>.empty();

  @override
  Future<bool> activate() async => true;

  @override
  Future<void> clear() async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> publish(AudioSystemPlaybackState state) async {}
}

final class UnavailableAudioPlaybackRepository
    implements AudioPlaybackRepository {
  const UnavailableAudioPlaybackRepository();

  @override
  Future<void> clear(String itemId) async {}

  @override
  Future<AudioPlaybackSnapshot?> read(String itemId) async => null;

  @override
  Future<void> save(AudioPlaybackSnapshot snapshot) async {}
}

final class UnavailableAudioQueueRepository implements AudioQueueRepository {
  const UnavailableAudioQueueRepository();

  @override
  Future<void> clear() async {}

  @override
  Future<AudioQueueEntry?> consumeCurrent({
    required DateTime updatedAt,
  }) async =>
      null;

  @override
  Future<bool> enqueue({
    required AudioItem item,
    required String? contentRevision,
    required DateTime enqueuedAt,
  }) async =>
      false;

  @override
  Future<void> move({
    required String itemId,
    required int targetIndex,
    required DateTime updatedAt,
  }) async {}

  @override
  Future<AudioQueueSnapshot> read() async => const AudioQueueSnapshot.empty();

  @override
  Future<void> remove({
    required String itemId,
    required DateTime updatedAt,
  }) async {}

  @override
  Future<void> select({
    required String itemId,
    required DateTime updatedAt,
  }) async {}

  @override
  Stream<AudioQueueSnapshot> watch() =>
      Stream<AudioQueueSnapshot>.value(const AudioQueueSnapshot.empty());
}

final class UnavailableAudioEngine implements AudioEngine {
  const UnavailableAudioEngine();

  @override
  Stream<AudioEngineEvent> get events => const Stream<AudioEngineEvent>.empty();

  @override
  Future<AudioEngineCapabilities> capabilities() async =>
      const AudioEngineCapabilities(
        supportsArticleTts: false,
        supportsPodcastMedia: false,
        canPause: false,
        canResume: false,
        canSeek: false,
        canSetRate: false,
        canSetPitch: false,
        canSelectVoice: false,
      );

  @override
  Future<List<AudioVoice>> voices() async => const <AudioVoice>[];

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load(AudioLoadRequest request) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(AudioPlaybackPosition position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> updateSettings(AudioPlaybackSettings settings) async {}
}

abstract interface class KnowledgeConnector {
  String get id;
  Future<Uri> upsert(Article article, ArticleSummary? summary);
}
