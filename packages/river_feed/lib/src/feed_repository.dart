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
    required this.feedTitle,
    required this.canonicalUrl,
    required this.title,
    required this.read,
    required this.starred,
    required this.readLater,
    this.author,
    this.publishedAt,
    this.summary,
    this.folderId,
    this.estimatedReadingMinutes,
  });

  final String id;
  final String feedId;
  final String feedTitle;
  final Uri canonicalUrl;
  final String title;
  final String? author;
  final DateTime? publishedAt;
  final String? summary;
  final bool read;
  final bool starred;
  final bool readLater;
  final String? folderId;
  final int? estimatedReadingMinutes;
}

final class FeedArticleContentRecord {
  const FeedArticleContentRecord({
    required this.sanitizedHtml,
    required this.markdown,
    required this.plainText,
    required this.extractorName,
    required this.extractorVersion,
    required this.extractedAt,
    this.contentHash,
    this.failureCode,
  });

  final String sanitizedHtml;
  final String markdown;
  final String plainText;
  final String extractorName;
  final String extractorVersion;
  final DateTime extractedAt;
  final String? contentHash;
  final String? failureCode;

  bool get isReadable =>
      sanitizedHtml.trim().isNotEmpty && plainText.trim().isNotEmpty;
}

final class FeedArticleDetailRecord {
  const FeedArticleDetailRecord({
    required this.id,
    required this.feedId,
    required this.feedTitle,
    required this.canonicalUrl,
    required this.title,
    required this.read,
    required this.starred,
    required this.readLater,
    this.author,
    this.publishedAt,
    this.summary,
    this.feedContentHtml,
    this.content,
  });

  final String id;
  final String feedId;
  final String feedTitle;
  final Uri canonicalUrl;
  final String title;
  final String? author;
  final DateTime? publishedAt;
  final String? summary;
  final String? feedContentHtml;
  final bool read;
  final bool starred;
  final bool readLater;
  final FeedArticleContentRecord? content;
}

enum FeedArticleView { inbox, unread, starred, readLater, folder }

enum FeedArticleSort { newest, oldest }

final class FeedArticleQuery {
  const FeedArticleQuery({
    this.view = FeedArticleView.inbox,
    this.sort = FeedArticleSort.newest,
    this.feedId,
    this.folderId,
  }) : assert(
          view != FeedArticleView.folder || folderId != null,
          'Folder view requires a folderId.',
        );

  final FeedArticleView view;
  final FeedArticleSort sort;
  final String? feedId;
  final String? folderId;

  FeedArticleQuery copyWith({
    FeedArticleView? view,
    FeedArticleSort? sort,
    String? feedId,
    String? folderId,
    bool clearFeedId = false,
    bool clearFolderId = false,
  }) =>
      FeedArticleQuery(
        view: view ?? this.view,
        sort: sort ?? this.sort,
        feedId: clearFeedId ? null : feedId ?? this.feedId,
        folderId: clearFolderId ? null : folderId ?? this.folderId,
      );

  @override
  bool operator ==(Object other) =>
      other is FeedArticleQuery &&
      other.view == view &&
      other.sort == sort &&
      other.feedId == feedId &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(view, sort, feedId, folderId);
}

int? estimateReadingMinutes(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final hanCharacters =
      RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff]').allMatches(text).length;
  final latinWords =
      RegExp(r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)*").allMatches(text).length;
  final minutes = (hanCharacters / 400) + (latinWords / 220);
  return minutes.ceil().clamp(1, 999);
}

int? estimateReadingMinutesFromCharacterCount(int? characterCount) {
  if (characterCount == null || characterCount <= 0) return null;
  return (characterCount / 400).ceil().clamp(1, 999);
}

final class FeedArticleDraft {
  const FeedArticleDraft({
    required this.id,
    required this.canonicalUrl,
    required this.title,
    this.author,
    this.publishedAt,
    this.summary,
    this.contentHtml,
  });

  final String id;
  final Uri canonicalUrl;
  final String title;
  final String? author;
  final DateTime? publishedAt;
  final String? summary;
  final String? contentHtml;
}

abstract interface class ArticleReaderRepository {
  Stream<FeedArticleDetailRecord?> watchArticle(String articleId);
}

abstract interface class FeedRepository {
  Future<FeedSubscriptionRecord?> findByCanonicalUrl(Uri canonicalUrl);

  Stream<List<FeedSubscriptionRecord>> watchSubscriptions();

  Stream<List<FeedArticleRecord>> watchArticles({
    FeedArticleQuery query = const FeedArticleQuery(),
  });

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
