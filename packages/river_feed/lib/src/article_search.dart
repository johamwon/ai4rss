import 'feed_repository.dart';

enum ArticleSearchSort { relevance, newest, oldest }

final class ArticleSearchQuery {
  const ArticleSearchQuery({
    required this.text,
    this.view = FeedArticleView.inbox,
    this.sort = ArticleSearchSort.relevance,
    this.feedId,
    this.folderId,
    this.limit = 200,
  })  : assert(
          view != FeedArticleView.folder || folderId != null,
          'Folder view requires a folderId.',
        ),
        assert(limit > 0 && limit <= 500);

  final String text;
  final FeedArticleView view;
  final ArticleSearchSort sort;
  final String? feedId;
  final String? folderId;
  final int limit;

  String get normalizedText => text.trim();

  ArticleSearchQuery copyWith({
    String? text,
    FeedArticleView? view,
    ArticleSearchSort? sort,
    String? feedId,
    String? folderId,
    bool clearFeedId = false,
    bool clearFolderId = false,
    int? limit,
  }) =>
      ArticleSearchQuery(
        text: text ?? this.text,
        view: view ?? this.view,
        sort: sort ?? this.sort,
        feedId: clearFeedId ? null : feedId ?? this.feedId,
        folderId: clearFolderId ? null : folderId ?? this.folderId,
        limit: limit ?? this.limit,
      );

  @override
  bool operator ==(Object other) =>
      other is ArticleSearchQuery &&
      other.text == text &&
      other.view == view &&
      other.sort == sort &&
      other.feedId == feedId &&
      other.folderId == folderId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(text, view, sort, feedId, folderId, limit);
}

final class ArticleSearchResult {
  const ArticleSearchResult({
    required this.article,
    required this.excerpt,
  });

  final FeedArticleRecord article;
  final String excerpt;
}

final class SearchHighlightRange {
  const SearchHighlightRange(this.start, this.end)
      : assert(start >= 0),
        assert(end >= start);

  final int start;
  final int end;
}

List<SearchHighlightRange> literalHighlightRanges(String text, String query) {
  final needle = query.trim();
  if (needle.isEmpty || text.isEmpty) return const <SearchHighlightRange>[];
  final literal = RegExp(
    RegExp.escape(needle),
    caseSensitive: false,
    unicode: true,
  );
  return List<SearchHighlightRange>.unmodifiable(
    literal
        .allMatches(text)
        .map((match) => SearchHighlightRange(match.start, match.end)),
  );
}

abstract interface class ArticleSearchRepository {
  Stream<List<ArticleSearchResult>> watchSearch(ArticleSearchQuery query);
}
