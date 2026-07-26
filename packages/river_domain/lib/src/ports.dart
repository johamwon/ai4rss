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
}

abstract interface class KnowledgeConnector {
  String get id;
  Future<Uri> upsert(Article article, ArticleSummary? summary);
}
