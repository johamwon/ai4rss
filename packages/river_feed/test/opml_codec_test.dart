import 'dart:io';

import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  const codec = OpmlCodec();

  test('parses nested folders and reports invalid and duplicate sources', () {
    final source = File(
      '../../fixtures/opml/subscriptions_nested.opml',
    ).readAsStringSync();

    final document = codec.parse(source);

    expect(document.title, 'River OPML Fixture');
    expect(document.feeds, hasLength(2));
    expect(document.skippedDuplicateEntries, 1);
    expect(document.skippedInvalidEntries, 1);
    expect(
      document.feeds.first.xmlUrl,
      Uri.parse('https://example.test/feed.xml'),
    );
    expect(document.feeds.first.folderPath, <String>['技术', 'AI & 工具']);
    expect(document.feeds.last.folderPath, isEmpty);
  });

  test('round trip preserves feed URLs, titles, and folder hierarchy', () {
    final original = OpmlDocument(
      title: 'River & Friends',
      feeds: <OpmlFeedEntry>[
        OpmlFeedEntry(
          title: 'AI <Today>',
          xmlUrl: Uri.parse('https://example.test/ai.xml'),
          htmlUrl: Uri.parse('https://example.test/ai'),
          folderPath: const <String>['技术', 'AI / 工具'],
        ),
        OpmlFeedEntry(
          title: 'Daily',
          xmlUrl: Uri.parse('https://news.test/feed'),
          folderPath: const <String>['新闻'],
        ),
        OpmlFeedEntry(
          title: 'Loose',
          xmlUrl: Uri.parse('https://loose.test/rss'),
        ),
      ],
    );

    final reparsed = codec.parse(codec.encode(original));

    expect(reparsed.title, original.title);
    expect(
      reparsed.feeds
          .map(
            (feed) => (
              feed.title,
              feed.xmlUrl.toString(),
              feed.folderPath.join('\u001f'),
            ),
          )
          .toList(),
      original.feeds
          .map(
            (feed) => (
              feed.title,
              feed.xmlUrl.toString(),
              feed.folderPath.join('\u001f'),
            ),
          )
          .toList(),
    );
  });

  test('rejects malformed and unsafe XML', () {
    expect(
      () => codec.parse('<opml><body>'),
      throwsA(
        isA<OpmlException>().having(
          (error) => error.failure,
          'failure',
          OpmlFailure.invalidDocument,
        ),
      ),
    );
    expect(
      () => codec.parse(
        '<!DOCTYPE opml [<!ENTITY x "unsafe">]>'
        '<opml><body>&x;</body></opml>',
      ),
      throwsA(
        isA<OpmlException>().having(
          (error) => error.failure,
          'failure',
          OpmlFailure.unsafeDocument,
        ),
      ),
    );
  });

  test('enforces input size, source count, and nesting limits', () {
    const smallInputCodec = OpmlCodec(maxInputBytes: 64);
    expect(
      () => smallInputCodec.parse('x' * 65),
      throwsA(
        isA<OpmlException>().having(
          (error) => error.failure,
          'failure',
          OpmlFailure.tooLarge,
        ),
      ),
    );

    const oneFeedCodec = OpmlCodec(maxFeeds: 1);
    expect(
      () => oneFeedCodec.parse(
        '<opml><body>'
        '<outline xmlUrl="https://one.test/rss" />'
        '<outline xmlUrl="https://two.test/rss" />'
        '</body></opml>',
      ),
      throwsA(
        isA<OpmlException>().having(
          (error) => error.failure,
          'failure',
          OpmlFailure.tooLarge,
        ),
      ),
    );

    const shallowCodec = OpmlCodec(maxDepth: 1);
    expect(
      () => shallowCodec.parse(
        '<opml><body><outline text="one">'
        '<outline xmlUrl="https://deep.test/rss" />'
        '</outline></body></opml>',
      ),
      throwsA(
        isA<OpmlException>().having(
          (error) => error.failure,
          'failure',
          OpmlFailure.tooDeep,
        ),
      ),
    );
  });
}
