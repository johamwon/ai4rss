import 'package:html/parser.dart' as html_parser;
import 'package:river_domain/river_domain.dart';

import 'feed_models.dart';
import 'feed_parser.dart';
import 'feed_refresh_service.dart';

enum FeedDiscoverySource { direct, htmlLink, commonPath }

enum FeedDiscoveryFailure { invalidAddress, unavailable, notFound }

final class FeedDiscoveryCandidate {
  const FeedDiscoveryCandidate._({
    required this.uri,
    required this.title,
    required this.kind,
    required this.source,
    required PortHttpResponse response,
    this.latestUpdatedAt,
  }) : _response = response;

  final Uri uri;
  final String title;
  final FeedDocumentKind kind;
  final FeedDiscoverySource source;
  final DateTime? latestUpdatedAt;
  final PortHttpResponse _response;
}

final class FeedDiscoveryException implements Exception {
  const FeedDiscoveryException(this.failure, this.message, {this.cause});

  final FeedDiscoveryFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class FeedDiscoveryService {
  const FeedDiscoveryService({
    required this.http,
    required this.feedRefresh,
    this.parser = const FeedParser(),
    this.maxConcurrentProbes = 4,
  }) : assert(maxConcurrentProbes > 0);

  static const _commonPaths = <String>[
    'feed',
    'feed.xml',
    'rss',
    'rss.xml',
    'atom.xml',
    'index.xml',
    'feed.json',
  ];

  static const _declaredFeedTypes = <String>{
    'application/atom+xml',
    'application/feed+json',
    'application/json',
    'application/rdf+xml',
    'application/rss+xml',
  };

  final HttpPort http;
  final FeedRefreshService feedRefresh;
  final FeedParser parser;
  final int maxConcurrentProbes;

  Future<List<FeedDiscoveryCandidate>> discover(Uri requestedUri) async {
    final requested = _canonicalizeRequestedUri(requestedUri);
    late final PortHttpResponse response;
    try {
      response = await http.get(requested);
    } catch (error) {
      throw FeedDiscoveryException(
        FeedDiscoveryFailure.unavailable,
        '无法访问这个地址，请检查网络后重试',
        cause: error,
      );
    }
    if (!_isSuccess(response.statusCode)) {
      throw FeedDiscoveryException(
        FeedDiscoveryFailure.unavailable,
        '网站暂时无法访问（HTTP ${response.statusCode}）',
      );
    }

    final effectiveUri = _canonicalizeEffectiveUri(
      response.effectiveUri ?? requested,
    );
    final direct = _candidateFromResponse(
      response,
      effectiveUri,
      FeedDiscoverySource.direct,
    );
    if (direct != null) {
      return <FeedDiscoveryCandidate>[direct];
    }

    if (!_isHtmlResponse(response)) {
      throw const FeedDiscoveryException(
        FeedDiscoveryFailure.notFound,
        '这个地址不是可识别的 RSS、Atom、JSON Feed 或网站首页',
      );
    }

    final declaredTargets = _declaredTargets(response.body, effectiveUri);
    final declared = await _probe(declaredTargets);
    if (declared.isNotEmpty) {
      return _deduplicateCandidates(declared);
    }

    final commonTargets = _commonTargets(effectiveUri, declaredTargets);
    final common = await _probe(commonTargets);
    if (common.isNotEmpty) {
      return _deduplicateCandidates(common);
    }

    throw const FeedDiscoveryException(
      FeedDiscoveryFailure.notFound,
      '没有在这个网站找到可订阅的 Feed，请尝试粘贴 RSS 地址',
    );
  }

  Future<FeedRefreshResult> subscribe(FeedDiscoveryCandidate candidate) =>
      feedRefresh.subscribeOrRefresh(
        candidate.uri,
        prefetchedResponse: candidate._response,
      );

  Uri _canonicalizeRequestedUri(Uri uri) {
    try {
      return canonicalizeFeedUrl(uri);
    } on FeedRefreshException catch (error) {
      throw FeedDiscoveryException(
        FeedDiscoveryFailure.invalidAddress,
        '请输入有效且不包含账号密码的 HTTP(S) 地址',
        cause: error,
      );
    }
  }

  Uri _canonicalizeEffectiveUri(Uri uri) {
    try {
      return canonicalizeFeedUrl(uri);
    } on FeedRefreshException catch (error) {
      throw FeedDiscoveryException(
        FeedDiscoveryFailure.unavailable,
        '网站跳转到了不受支持的地址',
        cause: error,
      );
    }
  }

  List<_ProbeTarget> _declaredTargets(String html, Uri effectiveUri) {
    final document =
        html_parser.parse(html, sourceUrl: effectiveUri.toString());
    var baseUri = effectiveUri;
    final baseHref = document.querySelector('base[href]')?.attributes['href'];
    if (baseHref != null) {
      final parsedBase = _safeResolve(effectiveUri, baseHref);
      if (parsedBase != null) {
        baseUri = parsedBase;
      }
    }

    final targets = <_ProbeTarget>[];
    final seen = <Uri>{};
    for (final link in document.querySelectorAll('link[href]')) {
      final relations =
          (link.attributes['rel'] ?? '').toLowerCase().split(RegExp(r'\s+'));
      final type = _mediaType(link.attributes['type']);
      if (!relations.contains('alternate') ||
          !_declaredFeedTypes.contains(type)) {
        continue;
      }
      final uri = _safeResolve(baseUri, link.attributes['href']);
      if (uri == null || !seen.add(uri)) {
        continue;
      }
      targets.add(
        _ProbeTarget(
          uri: uri,
          source: FeedDiscoverySource.htmlLink,
          hintedTitle: _nonEmpty(link.attributes['title']),
        ),
      );
    }
    return targets;
  }

  List<_ProbeTarget> _commonTargets(
    Uri effectiveUri,
    List<_ProbeTarget> declaredTargets,
  ) {
    final origin = Uri(
      scheme: effectiveUri.scheme,
      host: effectiveUri.host,
      port: effectiveUri.hasPort ? effectiveUri.port : null,
      path: '/',
    );
    final seen = <Uri>{
      effectiveUri,
      ...declaredTargets.map((target) => target.uri),
    };
    final targets = <_ProbeTarget>[];
    for (final path in _commonPaths) {
      final uri = canonicalizeFeedUrl(origin.resolve(path));
      if (seen.add(uri)) {
        targets.add(
          _ProbeTarget(uri: uri, source: FeedDiscoverySource.commonPath),
        );
      }
    }
    return targets;
  }

  Future<List<FeedDiscoveryCandidate>> _probe(
    List<_ProbeTarget> targets,
  ) async {
    final candidates = <FeedDiscoveryCandidate>[];
    for (var start = 0; start < targets.length; start += maxConcurrentProbes) {
      final end = (start + maxConcurrentProbes).clamp(0, targets.length);
      final batch = targets.sublist(start, end);
      final results = await Future.wait(batch.map(_probeOne));
      candidates.addAll(results.nonNulls);
    }
    return candidates;
  }

  Future<FeedDiscoveryCandidate?> _probeOne(_ProbeTarget target) async {
    try {
      final response = await http.get(target.uri);
      if (!_isSuccess(response.statusCode)) {
        return null;
      }
      final effectiveUri = _canonicalizeEffectiveUri(
        response.effectiveUri ?? target.uri,
      );
      return _candidateFromResponse(
        response,
        effectiveUri,
        target.source,
        hintedTitle: target.hintedTitle,
      );
    } on Object {
      return null;
    }
  }

  FeedDiscoveryCandidate? _candidateFromResponse(
    PortHttpResponse response,
    Uri effectiveUri,
    FeedDiscoverySource source, {
    String? hintedTitle,
  }) {
    if (detectFeedDocument(response.body) == FeedDocumentKind.unknown) {
      return null;
    }
    try {
      final feed = parser.parse(response.body, sourceUri: effectiveUri);
      return FeedDiscoveryCandidate._(
        uri: effectiveUri,
        title: feed.title == '(untitled feed)'
            ? hintedTitle ?? effectiveUri.host
            : feed.title,
        kind: feed.kind,
        source: source,
        latestUpdatedAt: _latestItemDate(feed),
        response: response,
      );
    } on FeedParseException {
      return null;
    }
  }
}

final class _ProbeTarget {
  const _ProbeTarget({
    required this.uri,
    required this.source,
    this.hintedTitle,
  });

  final Uri uri;
  final FeedDiscoverySource source;
  final String? hintedTitle;
}

List<FeedDiscoveryCandidate> _deduplicateCandidates(
  List<FeedDiscoveryCandidate> candidates,
) {
  final seen = <Uri>{};
  return candidates
      .where((candidate) => seen.add(candidate.uri))
      .toList(growable: false);
}

Uri? _safeResolve(Uri baseUri, String? rawValue) {
  final value = _nonEmpty(rawValue);
  if (value == null) {
    return null;
  }
  try {
    return canonicalizeFeedUrl(baseUri.resolve(value));
  } on Object {
    return null;
  }
}

DateTime? _latestItemDate(ParsedFeed feed) {
  DateTime? latest;
  for (final item in feed.items) {
    for (final candidate in <DateTime?>[item.publishedAt, item.updatedAt]) {
      if (candidate != null && (latest == null || candidate.isAfter(latest))) {
        latest = candidate;
      }
    }
  }
  return latest;
}

bool _isHtmlResponse(PortHttpResponse response) {
  final type = _mediaType(_header(response.headers, 'content-type'));
  if (type == 'text/html' || type == 'application/xhtml+xml') {
    return true;
  }
  final prefix = response.body.trimLeft().toLowerCase();
  return prefix.startsWith('<!doctype html') ||
      prefix.startsWith('<html') ||
      prefix.startsWith('<head');
}

bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

String _mediaType(String? contentType) =>
    (contentType ?? '').split(';').first.trim().toLowerCase();

String? _header(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name) {
      return entry.value;
    }
  }
  return null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
