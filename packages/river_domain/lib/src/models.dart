enum ContentSource { feed, web, weChat, podcast }

final class Article {
  const Article({
    required this.id,
    required this.url,
    required this.title,
    required this.source,
    this.author,
    this.publishedAt,
    this.plainText,
  });

  final String id;
  final Uri url;
  final String title;
  final ContentSource source;
  final String? author;
  final DateTime? publishedAt;
  final String? plainText;
}

final class ExtractedArticle {
  const ExtractedArticle({
    required this.title,
    required this.html,
    required this.plainText,
    required this.extractor,
    required this.extractorVersion,
    this.author,
    this.imageUrls = const <Uri>[],
  });

  final String title;
  final String? author;
  final String html;
  final String plainText;
  final List<Uri> imageUrls;
  final String extractor;
  final String extractorVersion;
}

final class ArticleSummary {
  const ArticleSummary({
    required this.oneLine,
    required this.keyPoints,
    required this.language,
    required this.model,
    required this.promptVersion,
  });

  final String oneLine;
  final List<String> keyPoints;
  final String language;
  final String model;
  final String promptVersion;
}

enum ReadingEventType {
  impression,
  open,
  activeRead,
  completed,
  starred,
  savedToKnowledge,
  notInterested,
}

final class ReadingEvent {
  const ReadingEvent({
    required this.articleId,
    required this.type,
    required this.occurredAt,
    this.activeSeconds = 0,
    this.completionRatio = 0,
  });

  final String articleId;
  final ReadingEventType type;
  final DateTime occurredAt;
  final int activeSeconds;
  final double completionRatio;
}

enum AudioKind { articleTts, podcastEpisode }

final class AudioItem {
  const AudioItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.sourceUri,
  });

  final String id;
  final AudioKind kind;
  final String title;
  final Uri sourceUri;
}
