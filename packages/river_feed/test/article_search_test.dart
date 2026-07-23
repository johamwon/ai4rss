import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('search query preserves filters and validates folder views', () {
    const query = ArticleSearchQuery(
      text: '  River  ',
      view: FeedArticleView.unread,
      sort: ArticleSearchSort.newest,
      feedId: 'feed-1',
    );

    expect(query.normalizedText, 'River');
    expect(
      query.copyWith(sort: ArticleSearchSort.oldest),
      const ArticleSearchQuery(
        text: '  River  ',
        view: FeedArticleView.unread,
        sort: ArticleSearchSort.oldest,
        feedId: 'feed-1',
      ),
    );
    expect(
      () => ArticleSearchQuery(
        text: 'River',
        view: FeedArticleView.folder,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('literal highlights are case-insensitive and never overlap', () {
    final ranges = literalHighlightRanges(
      'River river RIVER',
      'river',
    );

    expect(
      ranges.map((range) => (range.start, range.end)),
      <(int, int)>[(0, 5), (6, 11), (12, 17)],
    );
    expect(literalHighlightRanges('<b>safe</b>', '<b>'), hasLength(1));
    expect(
      literalHighlightRanges('İstanbul and İstanbul', 'İstanbul')
          .map((range) => (range.start, range.end)),
      <(int, int)>[(0, 8), (13, 21)],
    );
    expect(literalHighlightRanges('text', ' '), isEmpty);
  });
}
