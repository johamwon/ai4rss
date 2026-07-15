import 'package:river_domain/river_domain.dart';

import 'feed_parser.dart';
import 'feed_repository.dart';

final class FeedRefreshService {
  const FeedRefreshService({
    required this.http,
    required this.repository,
    required this.clock,
    required this.ids,
    this.parser = const FeedParser(),
  });

  final HttpPort http;
  final FeedRepository repository;
  final Clock clock;
  final IdGenerator ids;
  final FeedParser parser;

  Future<void> setEnabled(String feedId, {required bool enabled}) =>
      repository.setEnabled(
        feedId,
        enabled: enabled,
        updatedAt: clock.now().toUtc(),
      );

  Future<void> delete(String feedId) => repository.delete(feedId);

  Future<FeedRefreshResult> subscribeOrRefresh(Uri requestedUri) async {
    final canonicalUrl = canonicalizeFeedUrl(requestedUri);
    final existing = await repository.findByCanonicalUrl(canonicalUrl);
    final headers = <String, String>{
      if (existing?.etag case final etag?) 'if-none-match': etag,
      if (existing?.lastModified case final modified?)
        'if-modified-since': modified,
    };
    final response = await http.get(canonicalUrl, headers: headers);
    final refreshedAt = clock.now().toUtc();
    if (response.statusCode == 304 && existing != null) {
      await repository.markNotModified(
        feedId: existing.id,
        refreshedAt: refreshedAt,
      );
      return FeedRefreshResult(
        feedId: existing.id,
        articleCount: 0,
        notModified: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FeedRefreshException(
        'Feed request failed with HTTP ${response.statusCode}',
      );
    }

    final effectiveUri = response.effectiveUri ?? canonicalUrl;
    final feed = parser.parse(response.body, sourceUri: effectiveUri);
    final feedId = existing?.id ?? ids.next();
    final articles = feed.items
        .map(
          (item) => FeedArticleDraft(
            id: ids.next(),
            canonicalUrl:
                item.url ?? _fallbackArticleUri(canonicalUrl, item.id),
            title: item.title,
            author: item.author,
            publishedAt: item.publishedAt ?? item.updatedAt,
            summary: item.summary,
          ),
        )
        .toList(growable: false);
    await repository.applyRefresh(
      feedId: feedId,
      canonicalUrl: canonicalUrl,
      feed: feed,
      articles: articles,
      refreshedAt: refreshedAt,
      etag: _header(response.headers, 'etag'),
      lastModified: _header(response.headers, 'last-modified'),
    );
    return FeedRefreshResult(
      feedId: feedId,
      articleCount: articles.length,
      notModified: false,
    );
  }
}

final class FeedRefreshResult {
  const FeedRefreshResult({
    required this.feedId,
    required this.articleCount,
    required this.notModified,
  });

  final String feedId;
  final int articleCount;
  final bool notModified;
}

final class FeedRefreshException implements Exception {
  const FeedRefreshException(this.message);

  final String message;

  @override
  String toString() => 'FeedRefreshException: $message';
}

Uri canonicalizeFeedUrl(Uri uri) {
  if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw FeedRefreshException('Feed URL must use HTTP(S): $uri');
  }
  if (uri.userInfo.isNotEmpty) {
    throw const FeedRefreshException(
      'Credentials are not allowed in feed URLs',
    );
  }
  final scheme = uri.scheme.toLowerCase();
  final isDefaultPort = (scheme == 'http' && uri.port == 80) ||
      (scheme == 'https' && uri.port == 443);
  return Uri(
    scheme: scheme,
    host: uri.host.toLowerCase(),
    port: isDefaultPort ? null : uri.port,
    path: uri.path.isEmpty ? '/' : uri.path,
    query: uri.hasQuery ? uri.query : null,
  );
}

Uri _fallbackArticleUri(Uri feedUri, String externalId) => Uri.parse(
      '${feedUri.toString()}#river-item=${Uri.encodeComponent(externalId)}',
    );

String? _header(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name) {
      return entry.value;
    }
  }
  return null;
}
