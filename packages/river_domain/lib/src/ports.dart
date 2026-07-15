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
  Future<ExtractedArticle> extract({
    required Uri sourceUri,
    required String rawHtml,
  });
}

abstract interface class AiProvider {
  Future<ArticleSummary> summarize(Article article);
}

abstract interface class AudioEngine {
  Future<void> load(AudioItem item);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
}

abstract interface class KnowledgeConnector {
  String get id;
  Future<Uri> upsert(Article article, ArticleSummary? summary);
}
