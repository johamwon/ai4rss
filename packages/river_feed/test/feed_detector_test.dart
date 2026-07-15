import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('detects RSS without network access', () {
    expect(
      detectFeedDocument('<?xml version="1.0"?><rss version="2.0"></rss>'),
      FeedDocumentKind.rss,
    );
  });
}
