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

  test('normalizes RSS 1.0 namespace aliases, rdf identity and xml base', () {
    final feed = parser.parse(
      '''
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
        xmlns="http://purl.org/rss/1.0/"
        xmlns:dublin="http://purl.org/dc/elements/1.1/"
        xmlns:body="http://purl.org/rss/1.0/modules/content/"
        xml:base="https://example.test/root/">
        <channel rdf:about="https://example.test/feed">
          <title>RDF title</title><link>../</link><description>RDF feed</description>
        </channel>
        <item rdf:about="https://example.test/items/rdf-1" xml:base="posts/">
          <title>RDF item</title><link>one</link>
          <dublin:creator>Ada</dublin:creator>
          <dublin:date>2026-08-06T10:00:00+08:00</dublin:date>
          <body:encoded><![CDATA[<p>Full RDF content</p>]]></body:encoded>
        </item>
      </rdf:RDF>
      ''',
      sourceUri: Uri.parse('https://fallback.example/feed.xml'),
    );

    expect(feed.title, 'RDF title');
    expect(feed.homePageUrl, Uri.parse('https://example.test/'));
    expect(feed.items.single.id, 'https://example.test/items/rdf-1');
    expect(
      feed.items.single.url,
      Uri.parse('https://example.test/root/posts/one'),
    );
    expect(feed.items.single.author, 'Ada');
    expect(feed.items.single.publishedAt, DateTime.utc(2026, 8, 6, 2));
    expect(feed.items.single.contentHtml, '<p>Full RDF content</p>');
  });

  test('preserves Atom XHTML and inherits feed author and xml base', () {
    final feed = parser.parse(
      '''
      <feed xmlns="http://www.w3.org/2005/Atom"
        xml:base="https://example.test/articles/">
        <title>Atom XHTML</title><author><name>Feed Author</name></author>
        <entry xml:base="2026/">
          <id>xhtml-1</id><title>XHTML item</title><link href="one" />
          <content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p>Rich text</p></div></content>
        </entry>
      </feed>
      ''',
    );

    expect(feed.items.single.author, 'Feed Author');
    expect(
      feed.items.single.url,
      Uri.parse('https://example.test/articles/2026/one'),
    );
    expect(feed.items.single.contentHtml, contains('<p>Rich text</p>'));
  });

  test('drops unsafe item URLs and enforces parser limits', () {
    final feed = parser.parse(
      '<rss><channel><title>Safe</title><item><title>One</title>'
      '<link>file:///private</link><enclosure url="javascript:bad" />'
      '</item></channel></rss>',
    );
    expect(feed.items.single.url, isNull);
    expect(feed.items.single.enclosureUrl, isNull);

    expect(
      () => const FeedParser(maximumDocumentCharacters: 8).parse(
        '<rss><channel /></rss>',
      ),
      throwsA(isA<FeedParseException>()),
    );
    expect(
      () => const FeedParser(maximumItems: 1).parse(
        '<rss><channel><item/><item/></channel></rss>',
      ),
      throwsA(isA<FeedParseException>()),
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
