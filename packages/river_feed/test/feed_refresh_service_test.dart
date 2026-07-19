import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

final class _Clock implements Clock {
  _Clock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _Ids implements IdGenerator {
  var value = 0;

  @override
  String next() => 'id-${++value}';
}

final class _Http implements HttpPort {
  _Http(this.response);

  PortHttpResponse response;
  Map<String, String>? lastHeaders;

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    lastHeaders = headers;
    return response;
  }
}

final class _Repository implements FeedRepository {
  FeedSubscriptionRecord? subscription;
  List<FeedArticleDraft> articles = <FeedArticleDraft>[];
  DateTime? notModifiedAt;

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
    this.articles = articles;
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
  }) async {
    notModifiedAt = refreshedAt;
  }

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

void main() {
  const rss = '''
    <rss version="2.0"><channel><title>Example</title>
      <item><guid>one</guid><title>First</title><link>/one</link></item>
    </channel></rss>
  ''';

  test('downloads, normalizes, and commits a feed atomically', () async {
    final repository = _Repository();
    final http = _Http(
      PortHttpResponse(
        statusCode: 200,
        body: rss,
        headers: const <String, String>{'etag': 'v1'},
        effectiveUri: Uri.parse('https://example.test/feeds/rss.xml'),
      ),
    );
    final service = FeedRefreshService(
      http: http,
      repository: repository,
      clock: _Clock(DateTime.utc(2026, 7, 15)),
      ids: _Ids(),
    );

    final result = await service.subscribeOrRefresh(
      Uri.parse('HTTPS://EXAMPLE.TEST:443/feeds/rss.xml#fragment'),
    );

    expect(result.feedId, 'id-1');
    expect(result.articleCount, 1);
    expect(repository.subscription?.etag, 'v1');
    expect(
      repository.subscription?.canonicalUrl,
      Uri.parse('https://example.test/feeds/rss.xml'),
    );
    expect(
      repository.articles.single.canonicalUrl,
      Uri.parse('https://example.test/one'),
    );
  });

  test('sends validators and handles 304 without rewriting articles', () async {
    final repository = _Repository()
      ..subscription = FeedSubscriptionRecord(
        id: 'feed-1',
        canonicalUrl: Uri.parse('https://example.test/feed.xml'),
        title: 'Example',
        kind: FeedDocumentKind.rss,
        enabled: true,
        etag: 'v1',
        lastModified: 'Tue, 14 Jul 2026 00:00:00 GMT',
      );
    final http = _Http(
      const PortHttpResponse(statusCode: 304, body: ''),
    );
    final service = FeedRefreshService(
      http: http,
      repository: repository,
      clock: _Clock(DateTime.utc(2026, 7, 16)),
      ids: _Ids(),
    );

    final result = await service.subscribeOrRefresh(
      Uri.parse('https://example.test/feed.xml'),
    );

    expect(result.notModified, isTrue);
    expect(http.lastHeaders, <String, String>{
      'if-none-match': 'v1',
      'if-modified-since': 'Tue, 14 Jul 2026 00:00:00 GMT',
    });
    expect(repository.notModifiedAt, DateTime.utc(2026, 7, 16));
  });

  test('preserves feed content for progressive reading', () async {
    const body = '''
      <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel><title>Example</title><item>
          <guid>one</guid><title>First</title><link>/one</link>
          <description>Preview</description>
          <content:encoded><![CDATA[<p>Immediate feed body</p>]]></content:encoded>
        </item></channel>
      </rss>
    ''';
    final repository = _Repository();
    final service = FeedRefreshService(
      http: _Http(const PortHttpResponse(statusCode: 200, body: body)),
      repository: repository,
      clock: _Clock(DateTime.utc(2026, 7, 19)),
      ids: _Ids(),
    );

    await service.subscribeOrRefresh(Uri.parse('https://example.test/rss'));

    expect(repository.articles.single.summary, 'Preview');
    expect(
      repository.articles.single.contentHtml,
      '<p>Immediate feed body</p>',
    );
  });

  test('canonical URL rejects embedded credentials', () {
    expect(
      () =>
          canonicalizeFeedUrl(Uri.parse('https://user:pass@example.test/rss')),
      throwsA(isA<FeedRefreshException>()),
    );
  });
}
