import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  const parser = FeedParser();

  test('normalizes RSS 2.0 extensions and RFC 822 dates', () {
    final feed = parser.parse(
      '''
      <rss version="2.0"
        xmlns:content="http://purl.org/rss/1.0/modules/content/"
        xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
          <title>RSS title</title><link>https://example.test/</link>
          <description>RSS description</description>
          <item>
            <guid>rss-1</guid><title>RSS item</title>
            <link>/items/1</link><dc:creator>Ada</dc:creator>
            <pubDate>Tue, 14 Jul 2026 08:30:00 +0800</pubDate>
            <description>Summary</description>
            <content:encoded><![CDATA[<p>Full text</p>]]></content:encoded>
            <enclosure url="/audio/1.mp3" type="audio/mpeg" />
          </item>
        </channel>
      </rss>
    ''',
      sourceUri: Uri.parse('https://example.test/feed.xml'),
    );

    expect(feed.kind, FeedDocumentKind.rss);
    expect(feed.title, 'RSS title');
    expect(feed.items, hasLength(1));
    expect(feed.items.single.id, 'rss-1');
    expect(feed.items.single.author, 'Ada');
    expect(feed.items.single.url, Uri.parse('https://example.test/items/1'));
    expect(feed.items.single.publishedAt, DateTime.utc(2026, 7, 14, 0, 30));
    expect(feed.items.single.contentHtml, '<p>Full text</p>');
    expect(
      feed.items.single.enclosureUrl,
      Uri.parse('https://example.test/audio/1.mp3'),
    );
  });

  test('normalizes Atom links, author, content, and dates', () {
    final feed = parser.parse(
      '''
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Atom title</title><link href="https://example.test/" />
        <link rel="self" href="/atom.xml" />
        <entry>
          <id>atom-1</id><title>Atom item</title><link href="items/1" />
          <published>2026-07-14T08:30:00+08:00</published>
          <author><name>Grace</name></author>
          <summary>Summary</summary>
          <content type="html">&lt;p&gt;Full text&lt;/p&gt;</content>
        </entry>
      </feed>
    ''',
      sourceUri: Uri.parse('https://example.test/feeds/atom.xml'),
    );

    expect(feed.kind, FeedDocumentKind.atom);
    expect(feed.feedUrl, Uri.parse('https://example.test/atom.xml'));
    expect(feed.items.single.author, 'Grace');
    expect(
      feed.items.single.url,
      Uri.parse('https://example.test/feeds/items/1'),
    );
    expect(feed.items.single.contentHtml, '<p>Full text</p>');
  });

  test('normalizes JSON Feed attachments and authors', () {
    final feed = parser.parse(
      '''
      {
        "version":"https://jsonfeed.org/version/1.1",
        "title":"JSON title",
        "items":[{
          "id":"json-1", "title":"JSON item", "url":"items/1",
          "authors":[{"name":"Lin"}],
          "date_published":"2026-07-14T00:30:00Z",
          "attachments":[{
            "url":"audio/1.mp3", "mime_type":"audio/mpeg",
            "duration_in_seconds":90.5
          }]
        }]
      }
    ''',
      sourceUri: Uri.parse('https://example.test/feed.json'),
    );

    expect(feed.kind, FeedDocumentKind.jsonFeed);
    expect(feed.items.single.author, 'Lin');
    expect(feed.items.single.duration, const Duration(milliseconds: 90500));
    expect(
      feed.items.single.enclosureUrl,
      Uri.parse('https://example.test/audio/1.mp3'),
    );
  });

  test('rejects unknown and malformed documents with typed failures', () {
    expect(
      () => parser.parse('<html></html>'),
      throwsA(isA<FeedParseException>()),
    );
    expect(
      () => parser.parse('<rss><channel>'),
      throwsA(isA<FeedParseException>()),
    );
  });
}
