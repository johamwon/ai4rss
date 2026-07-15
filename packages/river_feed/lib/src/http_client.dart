import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:river_domain/river_domain.dart';

final class BoundedHttpPort implements HttpPort {
  BoundedHttpPort({
    required http.Client client,
    this.requestTimeout = const Duration(seconds: 12),
    this.maxResponseBytes = 5 * 1024 * 1024,
    this.maxRedirects = 5,
    this.userAgent = 'River/0.1 (+https://river.local)',
  }) : _client = client;

  factory BoundedHttpPort.standard() => BoundedHttpPort(client: http.Client());

  final http.Client _client;
  final Duration requestTimeout;
  final int maxResponseBytes;
  final int maxRedirects;
  final String userAgent;

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    _validateUri(uri);
    final visited = <Uri>{};
    var current = uri;

    for (var redirectCount = 0;; redirectCount += 1) {
      if (!visited.add(current)) {
        throw HttpBoundaryException('Redirect loop detected at $current');
      }
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(<String, String>{
          'accept':
              'application/atom+xml, application/rss+xml, application/feed+json, application/xml, text/xml, text/html;q=0.8, */*;q=0.2',
          'user-agent': userAgent,
          ...headers,
        });

      late final http.StreamedResponse response;
      try {
        response = await _client.send(request).timeout(requestTimeout);
      } on TimeoutException catch (error) {
        throw HttpBoundaryException(
          'Request timed out: $current',
          cause: error,
        );
      }
      final responseHeaders = <String, String>{
        for (final entry in response.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };
      final bytes = await _readBounded(response.stream, current);

      if (_isRedirect(response.statusCode)) {
        if (redirectCount >= maxRedirects) {
          throw HttpBoundaryException('Too many redirects from $uri');
        }
        final location = responseHeaders['location'];
        if (location == null) {
          throw HttpBoundaryException(
            'Redirect response has no Location header: $current',
          );
        }
        final next = current.resolve(location);
        _validateUri(next);
        current = next;
        continue;
      }

      return PortHttpResponse(
        statusCode: response.statusCode,
        body: _decode(bytes, responseHeaders['content-type']),
        headers: responseHeaders,
        effectiveUri: current,
      );
    }
  }

  void close() => _client.close();

  Future<Uint8List> _readBounded(
    Stream<List<int>> stream,
    Uri uri,
  ) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    try {
      await for (final chunk in stream.timeout(requestTimeout)) {
        total += chunk.length;
        if (total > maxResponseBytes) {
          throw HttpBoundaryException(
            'Response from $uri exceeds $maxResponseBytes bytes',
          );
        }
        builder.add(chunk);
      }
    } on TimeoutException catch (error) {
      throw HttpBoundaryException(
        'Response body timed out: $uri',
        cause: error,
      );
    }
    return builder.takeBytes();
  }
}

final class HttpBoundaryException implements Exception {
  const HttpBoundaryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'HttpBoundaryException: $message';
}

void _validateUri(Uri uri) {
  if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw HttpBoundaryException('Only HTTP(S) URLs are allowed: $uri');
  }
}

bool _isRedirect(int statusCode) =>
    statusCode == 301 ||
    statusCode == 302 ||
    statusCode == 303 ||
    statusCode == 307 ||
    statusCode == 308;

String _decode(Uint8List bytes, String? contentType) {
  if (_hasUtf16Bom(bytes)) {
    throw const HttpBoundaryException(
      'UTF-16 feeds are not supported by the HTTP boundary',
    );
  }
  final headerEncoding = RegExp(
    r'''charset\s*=\s*["']?([^;"'\s]+)''',
    caseSensitive: false,
  ).firstMatch(contentType ?? '')?.group(1);
  final declaration = utf8.decode(
    bytes.take(256).toList(growable: false),
    allowMalformed: true,
  );
  final xmlEncoding = RegExp(
    r'''<\?xml[^>]*encoding\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(declaration)?.group(1);
  final encodingName = headerEncoding ?? xmlEncoding;
  final encoding =
      encodingName == null ? utf8 : Encoding.getByName(encodingName);
  if (encoding == null) {
    throw HttpBoundaryException('Unsupported response encoding: $encodingName');
  }
  final offset = _hasUtf8Bom(bytes) ? 3 : 0;
  try {
    return encoding.decode(bytes.sublist(offset));
  } on FormatException catch (error) {
    throw HttpBoundaryException('Malformed response encoding', cause: error);
  }
}

bool _hasUtf8Bom(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xEF &&
    bytes[1] == 0xBB &&
    bytes[2] == 0xBF;

bool _hasUtf16Bom(Uint8List bytes) =>
    bytes.length >= 2 &&
    ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
        (bytes[0] == 0xFE && bytes[1] == 0xFF));
