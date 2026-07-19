import 'dart:io';

import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

final class _Http implements HttpPort {
  _Http(this.responses);

  final Map<Uri, PortHttpResponse> responses;
  final List<Uri> requests = <Uri>[];

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    requests.add(uri);
    return responses[uri] ??
        PortHttpResponse(statusCode: 404, body: '', effectiveUri: uri);
  }
}

final class _Clock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 7, 15);
}

final class _Ids implements IdGenerator {
  var value = 0;

  @override
  String next() => 'id-${++value}';
}

final class _Repository implements FeedRepository {
  FeedSubscriptionRecord? subscription;

  @override
  Future<void> applyRefresh({
    required String feedId,
    required Uri canonicalUrl,
    required ParsedFeed feed,
    required List<FeedArticleDraft> articles,
    required DateTime refreshedAt,
    String? etag,
    String? lastModified,
  }) async {
    subscription = FeedSubscriptionRecord(
      id: feedId,
      canonicalUrl: canonicalUrl,
      title: feed.title,
      kind: feed.kind,
      enabled: true,
      etag: etag,
      lastModified: lastModified,
      lastRefreshedAt: refreshedAt,
    );
  }

  @override
  Future<void> delete(String feedId) async {
    subscription = null;
  }

  @override
  Future<FeedSubscriptionRecord?> findByCanonicalUrl(
    Uri canonicalUrl,
  ) async =>
      subscription?.canonicalUrl == canonicalUrl ? subscription : null;

  @override
  Future<void> markNotModified({
    required String feedId,
    required DateTime refreshedAt,
  }) async {}

  @override
  Future<void> setEnabled(
    String feedId, {
    required bool enabled,
    required DateTime updatedAt,
  }) async {}

  @override
  Stream<List<FeedArticleRecord>> watchArticles({
    FeedArticleQuery query = const FeedArticleQuery(),
  }) =>
      const Stream<List<FeedArticleRecord>>.empty();

  @override
  Stream<List<FeedSubscriptionRecord>> watchSubscriptions() =>
      const Stream<List<FeedSubscriptionRecord>>.empty();
}

const _rss = '''
  <rss version="2.0"><channel><title>River RSS</title>
    <item><guid>one</guid><title>First</title>
      <link>https://example.test/one</link>
      <pubDate>Tue, 14 Jul 2026 08:00:00 GMT</pubDate>
    </item>
  </channel></rss>
''';

const _atom = '''
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title>River Atom</title>
    <entry><id>two</id><title>Second</title>
      <updated>2026-07-15T09:30:00Z</updated>
      <link href="https://example.test/two" />
    </entry>
  </feed>
''';

FeedDiscoveryService _service(_Http http, _Repository repository) {
  final refresh = FeedRefreshService(
    http: http,
    repository: repository,
    clock: _Clock(),
    ids: _Ids(),
  );
  return FeedDiscoveryService(http: http, feedRefresh: refresh);
}

void main() {
  test('uses a direct feed response for subscription without downloading twice',
      () async {
    final uri = Uri.parse('https://example.test/feed.xml');
    final http = _Http(<Uri, PortHttpResponse>{
      uri: PortHttpResponse(
        statusCode: 200,
        body: _rss,
        headers: const <String, String>{
          'content-type': 'application/rss+xml',
          'etag': 'fixture-v1',
        },
        effectiveUri: uri,
      ),
    });
    final repository = _Repository();
    final service = _service(http, repository);

    final candidate = (await service.discover(uri)).single;
    await service.subscribe(candidate);

    expect(candidate.source, FeedDiscoverySource.direct);
    expect(candidate.kind, FeedDocumentKind.rss);
    expect(http.requests, <Uri>[uri]);
    expect(repository.subscription?.title, 'River RSS');
    expect(repository.subscription?.etag, 'fixture-v1');
  });

  test('discovers and deduplicates standard HTML alternate links', () async {
    final site = Uri.parse('https://example.test/');
    final rss = Uri.parse('https://example.test/feed.xml');
    final atom = Uri.parse('https://feeds.example.test/news.atom');
    final fixture = File(
      '../../fixtures/html/feed_discovery_synthetic.html',
    ).readAsStringSync();
    final http = _Http(<Uri, PortHttpResponse>{
      site: PortHttpResponse(
        statusCode: 200,
        body: fixture,
        headers: const <String, String>{
          'content-type': 'text/html; charset=utf-8',
        },
        effectiveUri: site,
      ),
      rss: PortHttpResponse(statusCode: 200, body: _rss, effectiveUri: rss),
      atom: PortHttpResponse(statusCode: 200, body: _atom, effectiveUri: atom),
    });

    final candidates = await _service(http, _Repository()).discover(site);

    expect(candidates.map((candidate) => candidate.uri), <Uri>[rss, atom]);
    expect(
      candidates.map((candidate) => candidate.source).toSet(),
      <FeedDiscoverySource>{FeedDiscoverySource.htmlLink},
    );
    expect(candidates.map((candidate) => candidate.title), <String>[
      'River RSS',
      'River Atom',
    ]);
    expect(candidates.first.latestUpdatedAt, DateTime.utc(2026, 7, 14, 8));
    expect(candidates.last.latestUpdatedAt, DateTime.utc(2026, 7, 15, 9, 30));
    expect(http.requests, <Uri>[site, rss, atom]);
  });

  test('falls back to common same-origin feed paths', () async {
    final site = Uri.parse('https://example.test/articles');
    final discovered = Uri.parse('https://example.test/feed.xml');
    final http = _Http(<Uri, PortHttpResponse>{
      site: PortHttpResponse(
        statusCode: 200,
        body: '<!doctype html><html><head><title>Site</title></head></html>',
        headers: const <String, String>{'content-type': 'text/html'},
        effectiveUri: site,
      ),
      discovered: PortHttpResponse(
        statusCode: 200,
        body: _rss,
        effectiveUri: discovered,
      ),
    });

    final candidate =
        (await _service(http, _Repository()).discover(site)).single;

    expect(candidate.uri, discovered);
    expect(candidate.source, FeedDiscoverySource.commonPath);
    expect(http.requests.every((uri) => uri.host == 'example.test'), isTrue);
  });

  test('returns an understandable not-found failure', () async {
    final site = Uri.parse('https://example.test/');
    final http = _Http(<Uri, PortHttpResponse>{
      site: PortHttpResponse(
        statusCode: 200,
        body: '<html><head><title>No feeds</title></head></html>',
        headers: const <String, String>{'content-type': 'text/html'},
        effectiveUri: site,
      ),
    });

    await expectLater(
      _service(http, _Repository()).discover(site),
      throwsA(
        isA<FeedDiscoveryException>()
            .having(
              (error) => error.failure,
              'failure',
              FeedDiscoveryFailure.notFound,
            )
            .having(
              (error) => error.message,
              'message',
              contains('没有在这个网站找到'),
            ),
      ),
    );
  });

  test('rejects non-HTTP addresses before making a request', () async {
    final http = _Http(<Uri, PortHttpResponse>{});

    await expectLater(
      _service(http, _Repository()).discover(Uri.parse('file:///feed.xml')),
      throwsA(
        isA<FeedDiscoveryException>().having(
          (error) => error.failure,
          'failure',
          FeedDiscoveryFailure.invalidAddress,
        ),
      ),
    );
    expect(http.requests, isEmpty);
  });
}
