import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('reading estimate handles Chinese, Latin, mixed, and empty text', () {
    expect(estimateReadingMinutes(null), isNull);
    expect(estimateReadingMinutes('   '), isNull);
    expect(estimateReadingMinutes('中' * 400), 1);
    expect(estimateReadingMinutes('中' * 401), 2);
    expect(
      estimateReadingMinutes(List<String>.filled(220, 'word').join(' ')),
      1,
    );
    expect(
      estimateReadingMinutes(
        '${'中' * 200} ${List<String>.filled(110, 'word').join(' ')}',
      ),
      1,
    );
    expect(estimateReadingMinutesFromCharacterCount(0), isNull);
    expect(estimateReadingMinutesFromCharacterCount(400), 1);
    expect(estimateReadingMinutesFromCharacterCount(401), 2);
  });

  test('article query equality includes every filtering dimension', () {
    const first = FeedArticleQuery(
      view: FeedArticleView.folder,
      sort: FeedArticleSort.oldest,
      feedId: 'feed-1',
      folderId: 'folder-1',
    );
    const same = FeedArticleQuery(
      view: FeedArticleView.folder,
      sort: FeedArticleSort.oldest,
      feedId: 'feed-1',
      folderId: 'folder-1',
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(first.copyWith(sort: FeedArticleSort.newest)));
  });
}
