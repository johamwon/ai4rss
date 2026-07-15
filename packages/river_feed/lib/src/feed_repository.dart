import 'feed_models.dart';

final class FeedSubscriptionRecord {
  const FeedSubscriptionRecord({
    required this.id,
    required this.canonicalUrl,
    required this.title,
    required this.kind,
    required this.enabled,
    this.etag,
    this.lastModified,
    this.lastRefreshedAt,
    this.folderId,
  });

  final String id;
  final Uri canonicalUrl;
  final String title;
  final FeedDocumentKind kind;
  final bool enabled;
  final String? etag;
  final String? lastModified;
  final DateTime? lastRefreshedAt;
  final String? folderId;
}

final class FeedArticleRecord {
  const FeedArticleRecord({
    required this.id,
    required this.feedId,
    required this.canonicalUrl,
    required this.title,
    required this.read,
    required this.starred,
    this.author,
    this.publishedAt,
    this.summary,
  });

  final String id;
  final String feedId;
  final Uri canonicalUrl;
  final String title;
  final String? author;
  final DateTime? publishedAt;
  final String? summary;
  final bool read;
  final bool starred;
}

final class FeedArticleDraft {
  const FeedArticleDraft({
    required this.id,
    required this.canonicalUrl,
    required this.title,
    this.author,
    this.publishedAt,
    this.summary,
  });

  final String id;
  final Uri canonicalUrl;
  final String title;
  final String? author;
  final DateTime? publishedAt;
  final String? summary;
}

abstract interface class FeedRepository {
  Future<FeedSubscriptionRecord?> findByCanonicalUrl(Uri canonicalUrl);

  Stream<List<FeedSubscriptionRecord>> watchSubscriptions();

  Stream<List<FeedArticleRecord>> watchArticles({String? feedId});

  Future<void> applyRefresh({
    required String feedId,
    required Uri canonicalUrl,
    required ParsedFeed feed,
    required List<FeedArticleDraft> articles,
    required DateTime refreshedAt,
    String? etag,
    String? lastModified,
  });

  Future<void> markNotModified({
    required String feedId,
    required DateTime refreshedAt,
  });

  Future<void> setEnabled(
    String feedId, {
    required bool enabled,
    required DateTime updatedAt,
  });

  Future<void> delete(String feedId);
}
