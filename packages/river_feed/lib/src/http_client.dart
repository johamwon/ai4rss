import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:river_domain/river_domain.dart';

final class BoundedHttpPort implements HttpPort {
  BoundedHttpPort({
    required http.Client client,
    required this.resolver,
    this.requestTimeout = const Duration(seconds: 12),
    this.maxResponseBytes = 5 * 1024 * 1024,
    this.maxRedirects = 5,
    this.userAgent = 'River/0.1 (+https://river.local)',
  }) : _client = client {
    if (requestTimeout <= Duration.zero ||
        maxResponseBytes < 1 ||
        maxResponseBytes > 100 * 1024 * 1024 ||
        maxRedirects < 0 ||
        maxRedirects > 20 ||
        userAgent.trim().isEmpty ||
        userAgent.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError('Invalid bounded HTTP policy.');
    }
  }

  factory BoundedHttpPort.standard() {
    const resolver = SystemFeedAddressResolver();
    const timeout = Duration(seconds: 12);
    return BoundedHttpPort(
      client: _pinnedHttpClient(resolver, timeout),
      resolver: resolver,
      requestTimeout: timeout,
    );
  }

  final http.Client _client;
  final FeedAddressResolver resolver;
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
    _validateHeaders(headers);
    final visited = <Uri>{};
    var current = uri;
    var currentHeaders = headers;

    for (var redirectCount = 0;; redirectCount += 1) {
      if (!visited.add(current)) {
        throw const HttpBoundaryException('Redirect loop detected');
      }
      await _validatePublicResolution(current);
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(<String, String>{
          'accept':
              'application/atom+xml, application/rss+xml, application/feed+json, application/xml, text/xml, text/html;q=0.8, */*;q=0.2',
          'user-agent': userAgent,
          ...currentHeaders,
        });

      late final http.StreamedResponse response;
      try {
        response = await _client.send(request).timeout(requestTimeout);
      } on TimeoutException catch (error) {
        throw HttpBoundaryException(
          'Request timed out',
          cause: error,
        );
      }
      final responseHeaders = <String, String>{
        for (final entry in response.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };
      final bytes = await _readBounded(
        _decodeContentStream(
          response.stream,
          responseHeaders['content-encoding'],
        ),
      );

      if (_isRedirect(response.statusCode)) {
        if (redirectCount >= maxRedirects) {
          throw const HttpBoundaryException('Too many redirects');
        }
        final location = responseHeaders['location'];
        if (location == null) {
          throw HttpBoundaryException(
            'Redirect response has no Location header',
          );
        }
        final next = current.resolve(location);
        _validateUri(next);
        if (!_sameOrigin(current, next))
          currentHeaders = const <String, String>{};
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
  ) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    try {
      await for (final chunk in stream.timeout(requestTimeout)) {
        total += chunk.length;
        if (total > maxResponseBytes) {
          throw HttpBoundaryException(
            'Response exceeds the configured byte limit',
          );
        }
        builder.add(chunk);
      }
    } on TimeoutException catch (error) {
      throw HttpBoundaryException(
        'Response body timed out',
        cause: error,
      );
    }
    return builder.takeBytes();
  }

  Future<void> _validatePublicResolution(Uri uri) async {
    await _resolvePublicAddresses(resolver, uri.host, requestTimeout);
  }
}

abstract interface class FeedAddressResolver {
  Future<List<String>> resolve(String host);
}

final class SystemFeedAddressResolver implements FeedAddressResolver {
  const SystemFeedAddressResolver();

  @override
  Future<List<String>> resolve(String host) async =>
      (await InternetAddress.lookup(host))
          .map((address) => address.address)
          .toList(growable: false);
}

http.Client _pinnedHttpClient(
  FeedAddressResolver resolver,
  Duration timeout,
) {
  final client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = timeout
    ..findProxy = (_) => 'DIRECT';
  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    if (proxyHost != null || proxyPort != null) {
      throw const HttpBoundaryException('HTTP proxies are not permitted');
    }
    final addresses = await _resolvePublicAddresses(
      resolver,
      uri.host,
      timeout,
    );
    final task =
        await Socket.startConnect(addresses.first, uri.port).timeout(timeout);
    if (uri.scheme == 'https') {
      final secureSocket = task.socket.timeout(timeout).then(
            (socket) =>
                SecureSocket.secure(socket, host: uri.host).timeout(timeout),
          );
      return ConnectionTask.fromSocket<Socket>(secureSocket, task.cancel);
    }
    return ConnectionTask.fromSocket<Socket>(
      task.socket.timeout(timeout),
      task.cancel,
    );
  };
  return IOClient(client);
}

Future<List<InternetAddress>> _resolvePublicAddresses(
  FeedAddressResolver resolver,
  String host,
  Duration timeout,
) async {
  List<String> values;
  try {
    values = await resolver.resolve(host).timeout(timeout);
  } on HttpBoundaryException {
    rethrow;
  } on Object catch (error) {
    throw HttpBoundaryException('DNS resolution failed', cause: error);
  }
  if (values.isEmpty || values.length > 32) {
    throw const HttpBoundaryException('DNS resolution is invalid');
  }
  final addresses = <InternetAddress>[];
  for (final value in values) {
    final address = InternetAddress.tryParse(value);
    if (address == null || !_isPublicAddress(address)) {
      throw const HttpBoundaryException(
        'Private network targets are blocked',
      );
    }
    addresses.add(address);
  }
  return addresses;
}

final class HttpBoundaryException implements Exception {
  const HttpBoundaryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'HttpBoundaryException: $message';
}

void _validateUri(Uri uri) {
  if (!uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const HttpBoundaryException(
      'Only credential-free HTTP(S) URLs are allowed',
    );
  }
}

void _validateHeaders(Map<String, String> headers) {
  const allowed = <String>{'if-none-match', 'if-modified-since'};
  for (final entry in headers.entries) {
    if (!allowed.contains(entry.key.toLowerCase()) ||
        entry.value.contains(RegExp(r'[\r\n]')) ||
        entry.value.length > 4096) {
      throw const HttpBoundaryException('Unsafe request header');
    }
  }
}

bool _sameOrigin(Uri first, Uri second) =>
    first.scheme == second.scheme &&
    first.host == second.host &&
    first.port == second.port;

Stream<List<int>> _decodeContentStream(
  Stream<List<int>> stream,
  String? contentEncoding,
) {
  final normalized = contentEncoding?.trim().toLowerCase();
  return switch (normalized) {
    null || '' || 'identity' => stream,
    'gzip' || 'x-gzip' => stream.transform(gzip.decoder),
    'deflate' => stream.transform(zlib.decoder),
    _ => throw const HttpBoundaryException(
        'Unsupported response content encoding',
      ),
  };
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
  final encoding = encodingName == null ? utf8 : _encoding(encodingName);
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

Encoding? _encoding(String name) {
  final normalized = name.trim().toLowerCase().replaceAll('_', '-');
  final builtIn = Encoding.getByName(normalized);
  if (builtIn != null) return builtIn;
  return switch (normalized) {
    'gbk' || 'gb2312' || 'gb-2312' => const GbkCodec(),
    'big5' || 'big-5' => const Big5Codec(),
    'windows-1252' || 'cp1252' || 'cp-1252' => const Windows1252Codec(),
    'windows-1251' || 'cp1251' || 'cp-1251' => const Windows1251Codec(),
    'iso-8859-2' || 'latin2' || 'latin-2' => const Latin2Codec(),
    _ => null,
  };
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

bool _isPublicAddress(InternetAddress address) {
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return _isPublicIpv4(bytes);
  }
  if (address.type != InternetAddressType.IPv6 || bytes.length != 16) {
    return false;
  }
  if (bytes.every((value) => value == 0) ||
      bytes.take(15).every((value) => value == 0) && bytes[15] == 1 ||
      (bytes[0] & 0xfe) == 0xfc ||
      bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 ||
      bytes[0] == 0xff ||
      bytes[0] == 0x20 &&
          bytes[1] == 0x01 &&
          bytes[2] == 0x0d &&
          bytes[3] == 0xb8) {
    return false;
  }
  final ipv4Mapped = bytes.take(10).every((value) => value == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff;
  return !ipv4Mapped || _isPublicIpv4(bytes.sublist(12));
}

bool _isPublicIpv4(List<int> bytes) {
  if (bytes.length != 4) return false;
  final first = bytes[0];
  final second = bytes[1];
  if (first == 0 ||
      first == 10 ||
      first == 127 ||
      first >= 224 ||
      (first == 100 && second >= 64 && second <= 127) ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168) ||
      (first == 192 && second == 0 && bytes[2] == 0) ||
      (first == 192 && second == 0 && bytes[2] == 2) ||
      (first == 198 && (second == 18 || second == 19)) ||
      (first == 198 && second == 51 && bytes[2] == 100) ||
      (first == 203 && second == 0 && bytes[2] == 113)) {
    return false;
  }
  return true;
}
