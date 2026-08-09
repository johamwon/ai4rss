import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:river_domain/river_domain.dart';

import 'extraction_pipeline.dart';

enum CloudExtractionFailureCode {
  invalidUrl,
  blockedHost,
  blockedAddress,
  dnsFailure,
  connectedAddressMismatch,
  redirectRejected,
  redirectLimit,
  timeout,
  responseTooLarge,
  invalidResponse,
  unsupportedContent,
  upstreamFailure,
  extractionFailed,
}

final class CloudExtractionFailure {
  const CloudExtractionFailure({
    required this.code,
    required this.retryable,
    this.retryAfter,
  }) : assert(retryable || retryAfter == null);

  final CloudExtractionFailureCode code;
  final bool retryable;
  final Duration? retryAfter;

  @override
  String toString() => 'CloudExtractionFailure('
      'code: ${code.name}, '
      'retryable: $retryable, '
      'retryAfterSeconds: ${retryAfter?.inSeconds}'
      ')';
}

sealed class CloudExtractionResult {
  const CloudExtractionResult();
}

final class CloudExtractionSuccess extends CloudExtractionResult {
  const CloudExtractionSuccess({
    required this.article,
    required this.effectiveUri,
    required this.redirects,
    required this.downloadedBytes,
    required this.attempts,
  });

  final ExtractedArticle article;
  final Uri effectiveUri;
  final int redirects;
  final int downloadedBytes;
  final List<ExtractionAttempt> attempts;
}

final class CloudExtractionFailureResult extends CloudExtractionResult {
  const CloudExtractionFailureResult(this.failure);

  final CloudExtractionFailure failure;
}

abstract interface class CloudExtractionDnsResolver {
  Future<List<String>> resolve(String host);
}

final class CloudExtractionFetchRequest {
  CloudExtractionFetchRequest({
    required this.uri,
    required this.resolvedAddress,
    required this.timeout,
    required this.maximumResponseBytes,
  }) {
    if (_validateCloudUri(uri) != null ||
        !isPublicCloudExtractionAddress(resolvedAddress)) {
      throw ArgumentError('A host and pinned address are required');
    }
    if (timeout <= Duration.zero || timeout > const Duration(seconds: 30)) {
      throw ArgumentError.value(timeout, 'timeout');
    }
    if (maximumResponseBytes < 1 || maximumResponseBytes > 5 * 1024 * 1024) {
      throw RangeError.range(
        maximumResponseBytes,
        1,
        5 * 1024 * 1024,
        'maximumResponseBytes',
      );
    }
  }

  final Uri uri;
  final String resolvedAddress;
  final Duration timeout;
  final int maximumResponseBytes;

  String get hostHeader => uri.authority;

  @override
  String toString() => 'CloudExtractionFetchRequest('
      'scheme: ${uri.scheme}, '
      'hostHash: ${_stableHostHash(uri.host)}, '
      'pathSegments: ${uri.pathSegments.length}, '
      'addressFamily: ${resolvedAddress.contains(':') ? 'ipv6' : 'ipv4'}, '
      'timeoutSeconds: ${timeout.inSeconds}, '
      'maximumResponseBytes: $maximumResponseBytes'
      ')';
}

final class CloudExtractionFetchResponse {
  CloudExtractionFetchResponse({
    required this.statusCode,
    required this.connectedAddress,
    required List<int> bodyBytes,
    Map<String, String> headers = const <String, String>{},
  })  : bodyBytes = Uint8List.fromList(bodyBytes),
        headers = Map<String, String>.unmodifiable(
          <String, String>{
            for (final entry in headers.entries)
              entry.key.toLowerCase(): entry.value,
          },
        ) {
    if (statusCode < 100 || statusCode > 599) {
      throw RangeError.value(statusCode, 'statusCode');
    }
    if (connectedAddress.trim().isEmpty) {
      throw ArgumentError.value(connectedAddress, 'connectedAddress');
    }
    var headerBytes = 0;
    for (final entry in headers.entries) {
      if (entry.key.length > 128 ||
          !_headerName.hasMatch(entry.key) ||
          entry.value.length > 8192 ||
          entry.value.codeUnits.any(
            (unit) => unit == 0x7f || (unit < 0x20 && unit != 0x09),
          )) {
        throw ArgumentError('Cloud extraction response header is too large');
      }
      headerBytes += entry.key.length + entry.value.length;
    }
    if (headerBytes > 32768) {
      throw ArgumentError('Cloud extraction response headers are too large');
    }
  }

  final int statusCode;
  final String connectedAddress;
  final Uint8List bodyBytes;
  final Map<String, String> headers;

  static final RegExp _headerName = RegExp(r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+$");

  @override
  String toString() => 'CloudExtractionFetchResponse('
      'statusCode: $statusCode, '
      'bodyBytes: ${bodyBytes.length}, '
      'headerNames: ${headers.keys.toList(growable: false)}, '
      'addressFamily: ${connectedAddress.contains(':') ? 'ipv6' : 'ipv4'}'
      ')';
}

/// The transport must connect to [CloudExtractionFetchRequest.resolvedAddress]
/// while preserving the original URI host for the HTTP Host header and TLS SNI.
/// It must not perform redirects or a second DNS lookup.
abstract interface class CloudExtractionPinnedTransport {
  Future<CloudExtractionFetchResponse> get(
    CloudExtractionFetchRequest request,
  );
}

abstract interface class CloudExtractionClock {
  Duration elapsed();
}

abstract interface class CloudExtractionTimeoutGuard {
  Future<T> within<T>(Future<T> future, Duration timeout);
}

final class FutureCloudExtractionTimeoutGuard
    implements CloudExtractionTimeoutGuard {
  const FutureCloudExtractionTimeoutGuard();

  @override
  Future<T> within<T>(Future<T> future, Duration timeout) =>
      future.timeout(timeout);
}

final class CloudExtractionPolicy {
  const CloudExtractionPolicy({
    this.totalTimeout = const Duration(seconds: 20),
    this.perHopTimeout = const Duration(seconds: 8),
    this.maximumRedirects = 3,
    this.maximumResponseBytes = 2 * 1024 * 1024,
    this.maximumTotalBytes = 3 * 1024 * 1024,
    this.maximumDnsAnswers = 8,
  });

  final Duration totalTimeout;
  final Duration perHopTimeout;
  final int maximumRedirects;
  final int maximumResponseBytes;
  final int maximumTotalBytes;
  final int maximumDnsAnswers;

  void validate() {
    if (totalTimeout < const Duration(seconds: 1) ||
        totalTimeout > const Duration(seconds: 60)) {
      throw ArgumentError.value(totalTimeout, 'totalTimeout');
    }
    if (perHopTimeout < const Duration(seconds: 1) ||
        perHopTimeout > totalTimeout) {
      throw ArgumentError.value(perHopTimeout, 'perHopTimeout');
    }
    if (maximumRedirects < 0 || maximumRedirects > 5) {
      throw RangeError.range(maximumRedirects, 0, 5, 'maximumRedirects');
    }
    if (maximumResponseBytes < 1024 || maximumResponseBytes > 5 * 1024 * 1024) {
      throw RangeError.range(
        maximumResponseBytes,
        1024,
        5 * 1024 * 1024,
        'maximumResponseBytes',
      );
    }
    if (maximumTotalBytes < maximumResponseBytes ||
        maximumTotalBytes > 10 * 1024 * 1024) {
      throw RangeError.range(
        maximumTotalBytes,
        maximumResponseBytes,
        10 * 1024 * 1024,
        'maximumTotalBytes',
      );
    }
    if (maximumDnsAnswers < 1 || maximumDnsAnswers > 16) {
      throw RangeError.range(
        maximumDnsAnswers,
        1,
        16,
        'maximumDnsAnswers',
      );
    }
  }
}

final class CloudFullTextRescueService {
  CloudFullTextRescueService({
    required CloudExtractionDnsResolver dns,
    required CloudExtractionPinnedTransport transport,
    required CloudExtractionClock clock,
    FullTextExtractor extractor = const LayeredFullTextExtractor(),
    CloudExtractionTimeoutGuard timeoutGuard =
        const FutureCloudExtractionTimeoutGuard(),
    CloudExtractionPolicy policy = const CloudExtractionPolicy(),
  })  : _dns = dns,
        _transport = transport,
        _clock = clock,
        _extractor = extractor,
        _timeoutGuard = timeoutGuard,
        _policy = policy {
    policy.validate();
  }

  final CloudExtractionDnsResolver _dns;
  final CloudExtractionPinnedTransport _transport;
  final CloudExtractionClock _clock;
  final FullTextExtractor _extractor;
  final CloudExtractionTimeoutGuard _timeoutGuard;
  final CloudExtractionPolicy _policy;

  Future<CloudExtractionResult> rescue({
    required Uri sourceUri,
    String? articleId,
    String? title,
    String? author,
    DateTime? publishedAt,
  }) async {
    final initialFailure = _validateCloudUri(sourceUri);
    if (initialFailure != null)
      return CloudExtractionFailureResult(initialFailure);

    final started = _clock.elapsed();
    final visited = <String>{};
    var current = sourceUri.removeFragment();
    var redirects = 0;
    var downloadedBytes = 0;

    while (true) {
      final canonical = _canonicalFetchUri(current);
      if (!visited.add(canonical)) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.redirectRejected,
            retryable: false,
          ),
        );
      }

      final remaining = _remaining(started);
      if (remaining < const Duration(milliseconds: 1)) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.timeout,
            retryable: true,
          ),
        );
      }
      final hopTimeout =
          remaining < _policy.perHopTimeout ? remaining : _policy.perHopTimeout;

      late final List<String> addresses;
      try {
        addresses = await _timeoutGuard.within(
          _resolveAddresses(current.host),
          hopTimeout,
        );
      } on TimeoutException {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.timeout,
            retryable: true,
          ),
        );
      } on Object {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.dnsFailure,
            retryable: true,
          ),
        );
      }
      if (addresses.isEmpty || addresses.length > _policy.maximumDnsAnswers) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.dnsFailure,
            retryable: true,
          ),
        );
      }
      if (addresses
          .any((address) => !isPublicCloudExtractionAddress(address))) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.blockedAddress,
            retryable: false,
          ),
        );
      }
      final pinnedAddress = (addresses.toSet().toList()..sort()).first;
      final remainingAfterDns = _remaining(started);
      if (remainingAfterDns < const Duration(milliseconds: 1)) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.timeout,
            retryable: true,
          ),
        );
      }
      final requestTimeout = remainingAfterDns < _policy.perHopTimeout
          ? remainingAfterDns
          : _policy.perHopTimeout;
      final bytesRemaining = _policy.maximumTotalBytes - downloadedBytes;
      if (bytesRemaining <= 0) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.responseTooLarge,
            retryable: false,
          ),
        );
      }

      late final CloudExtractionFetchResponse response;
      try {
        response = await _timeoutGuard.within(
          _transport.get(
            CloudExtractionFetchRequest(
              uri: current,
              resolvedAddress: pinnedAddress,
              timeout: requestTimeout,
              maximumResponseBytes:
                  bytesRemaining < _policy.maximumResponseBytes
                      ? bytesRemaining
                      : _policy.maximumResponseBytes,
            ),
          ),
          requestTimeout,
        );
      } on TimeoutException {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.timeout,
            retryable: true,
          ),
        );
      } on Object {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.upstreamFailure,
            retryable: true,
          ),
        );
      }

      if (_remaining(started) < const Duration(milliseconds: 1)) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.timeout,
            retryable: true,
          ),
        );
      }

      if (!_sameAddress(response.connectedAddress, pinnedAddress)) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.connectedAddressMismatch,
            retryable: false,
          ),
        );
      }
      final contentLength =
          int.tryParse(response.headers['content-length'] ?? '');
      if (contentLength != null &&
          (contentLength < 0 ||
              contentLength > _policy.maximumResponseBytes ||
              contentLength > bytesRemaining)) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.responseTooLarge,
            retryable: false,
          ),
        );
      }
      if (response.bodyBytes.length > _policy.maximumResponseBytes ||
          response.bodyBytes.length > bytesRemaining) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.responseTooLarge,
            retryable: false,
          ),
        );
      }
      downloadedBytes += response.bodyBytes.length;

      if (_isRedirect(response.statusCode)) {
        if (redirects >= _policy.maximumRedirects) {
          return const CloudExtractionFailureResult(
            CloudExtractionFailure(
              code: CloudExtractionFailureCode.redirectLimit,
              retryable: false,
            ),
          );
        }
        final location = response.headers['location'];
        if (location == null || location.isEmpty || location.length > 4096) {
          return const CloudExtractionFailureResult(
            CloudExtractionFailure(
              code: CloudExtractionFailureCode.redirectRejected,
              retryable: false,
            ),
          );
        }
        final next = Uri.tryParse(location);
        if (next == null) {
          return const CloudExtractionFailureResult(
            CloudExtractionFailure(
              code: CloudExtractionFailureCode.redirectRejected,
              retryable: false,
            ),
          );
        }
        final resolved = current.resolveUri(next).removeFragment();
        final redirectFailure = _validateCloudUri(resolved);
        if (redirectFailure != null ||
            (current.scheme == 'https' && resolved.scheme != 'https')) {
          return const CloudExtractionFailureResult(
            CloudExtractionFailure(
              code: CloudExtractionFailureCode.redirectRejected,
              retryable: false,
            ),
          );
        }
        redirects += 1;
        current = resolved;
        continue;
      }

      if (response.statusCode != 200) {
        final retryable = response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500;
        return CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.upstreamFailure,
            retryable: retryable,
            retryAfter:
                retryable ? _retryAfter(response.headers['retry-after']) : null,
          ),
        );
      }
      if (!_isHtmlContentType(response.headers['content-type'])) {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.unsupportedContent,
            retryable: false,
          ),
        );
      }

      late final String html;
      try {
        html =
            _decodeHtml(response.bodyBytes, response.headers['content-type']);
      } on FormatException {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.invalidResponse,
            retryable: false,
          ),
        );
      }
      late final ExtractionResult extraction;
      try {
        extraction = await _extractor.extract(
          ExtractionRequest(
            sourceUri: current,
            articleId: articleId,
            pageHtml: html,
            title: title,
            author: author,
            publishedAt: publishedAt,
          ),
        );
      } on Object {
        return const CloudExtractionFailureResult(
          CloudExtractionFailure(
            code: CloudExtractionFailureCode.extractionFailed,
            retryable: false,
          ),
        );
      }
      return switch (extraction) {
        ExtractionSuccess(:final article, :final attempts) =>
          CloudExtractionSuccess(
            article: article,
            effectiveUri: current,
            redirects: redirects,
            downloadedBytes: downloadedBytes,
            attempts: attempts,
          ),
        ExtractionFailureResult() => const CloudExtractionFailureResult(
            CloudExtractionFailure(
              code: CloudExtractionFailureCode.extractionFailed,
              retryable: false,
            ),
          ),
      };
    }
  }

  Future<List<String>> _resolveAddresses(String host) async {
    if (_parseAddress(host) != null) return <String>[host];
    return _dns.resolve(host);
  }

  Duration _remaining(Duration started) {
    final spent = _clock.elapsed() - started;
    if (spent.isNegative) return Duration.zero;
    return _policy.totalTimeout - spent;
  }
}

CloudExtractionFailure? _validateCloudUri(Uri uri) {
  if (uri.toString().length > 4096 ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.host.isEmpty) {
    return const CloudExtractionFailure(
      code: CloudExtractionFailureCode.invalidUrl,
      retryable: false,
    );
  }
  final expectedPort = uri.scheme == 'https' ? 443 : 80;
  if (uri.port != expectedPort) {
    return const CloudExtractionFailure(
      code: CloudExtractionFailureCode.invalidUrl,
      retryable: false,
    );
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (_isBlockedHostname(host)) {
    return const CloudExtractionFailure(
      code: CloudExtractionFailureCode.blockedHost,
      retryable: false,
    );
  }
  if (_parseAddress(host) == null && !_validDnsName(host)) {
    return const CloudExtractionFailure(
      code: CloudExtractionFailureCode.invalidUrl,
      retryable: false,
    );
  }
  return null;
}

bool _validDnsName(String host) {
  if (host.length > 253 || !RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
    return false;
  }
  final labels = host.split('.');
  return labels.length >= 2 &&
      labels.every(
        (label) =>
            label.isNotEmpty &&
            label.length <= 63 &&
            !label.startsWith('-') &&
            !label.endsWith('-'),
      );
}

bool _isBlockedHostname(String host) =>
    host == 'localhost' ||
    host.endsWith('.localhost') ||
    host.endsWith('.local') ||
    host.endsWith('.internal') ||
    host == 'home.arpa' ||
    host.endsWith('.home.arpa');

bool isPublicCloudExtractionAddress(String value) {
  final bytes = _parseAddress(value);
  if (bytes == null) return false;
  if (bytes.length == 4) return _publicIpv4(bytes);
  return _publicIpv6(bytes);
}

List<int>? _parseAddress(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty || normalized.contains('%')) return null;
  return normalized.contains(':')
      ? _parseIpv6(normalized)
      : _parseIpv4(normalized);
}

List<int>? _parseIpv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return null;
  final bytes = <int>[];
  for (final part in parts) {
    if (part.isEmpty ||
        part.length > 3 ||
        !RegExp(r'^\d+$').hasMatch(part) ||
        (part.length > 1 && part.startsWith('0'))) {
      return null;
    }
    final byte = int.tryParse(part);
    if (byte == null || byte > 255) return null;
    bytes.add(byte);
  }
  return bytes;
}

List<int>? _parseIpv6(String value) {
  if (value.split('::').length > 2) return null;
  var normalized = value;
  if (normalized.contains('.')) {
    final separator = normalized.lastIndexOf(':');
    if (separator < 0) return null;
    final ipv4 = _parseIpv4(normalized.substring(separator + 1));
    if (ipv4 == null) return null;
    normalized = '${normalized.substring(0, separator)}:'
        '${((ipv4[0] << 8) | ipv4[1]).toRadixString(16)}:'
        '${((ipv4[2] << 8) | ipv4[3]).toRadixString(16)}';
  }
  final hasCompression = normalized.contains('::');
  final halves = normalized.split('::');
  final left = halves.first.isEmpty ? <String>[] : halves.first.split(':');
  final right = halves.length == 1 || halves.last.isEmpty
      ? <String>[]
      : halves.last.split(':');
  if (left.any(_invalidHextet) || right.any(_invalidHextet)) return null;
  final explicit = left.length + right.length;
  if ((!hasCompression && explicit != 8) || (hasCompression && explicit >= 8)) {
    return null;
  }
  final hextets = <String>[
    ...left,
    if (hasCompression) ...List<String>.filled(8 - explicit, '0'),
    ...right,
  ];
  if (hextets.length != 8) return null;
  return <int>[
    for (final hextet in hextets) ...<int>[
      int.parse(hextet, radix: 16) >> 8,
      int.parse(hextet, radix: 16) & 0xff,
    ],
  ];
}

bool _invalidHextet(String value) =>
    value.isEmpty ||
    value.length > 4 ||
    !RegExp(r'^[0-9a-f]+$').hasMatch(value);

bool _publicIpv4(List<int> b) {
  if (b[0] == 0 ||
      b[0] == 10 ||
      b[0] == 127 ||
      b[0] >= 224 ||
      (b[0] == 100 && b[1] >= 64 && b[1] <= 127) ||
      (b[0] == 169 && b[1] == 254) ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168) ||
      (b[0] == 198 && (b[1] == 18 || b[1] == 19))) {
    return false;
  }
  const documentation = <List<int>>[
    <int>[192, 0, 0],
    <int>[192, 0, 2],
    <int>[192, 88, 99],
    <int>[198, 51, 100],
    <int>[203, 0, 113],
  ];
  return !documentation.any(
    (prefix) => b[0] == prefix[0] && b[1] == prefix[1] && b[2] == prefix[2],
  );
}

bool _publicIpv6(List<int> b) {
  final allZero = b.every((byte) => byte == 0);
  final loopback = b.take(15).every((byte) => byte == 0) && b[15] == 1;
  final ipv4Mapped =
      b.take(10).every((byte) => byte == 0) && b[10] == 0xff && b[11] == 0xff;
  final compatible = b.take(12).every((byte) => byte == 0);
  final uniqueLocal = (b[0] & 0xfe) == 0xfc;
  final linkLocal = b[0] == 0xfe && (b[1] & 0xc0) == 0x80;
  final multicast = b[0] == 0xff;
  final documentation =
      b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8;
  final nat64 = b.take(12).toList().join(',') ==
      <int>[0x00, 0x64, 0xff, 0x9b, 0, 0, 0, 0, 0, 0, 0, 0].join(',');
  final globalUnicast = (b[0] & 0xe0) == 0x20;
  return globalUnicast &&
      !allZero &&
      !loopback &&
      !ipv4Mapped &&
      !compatible &&
      !uniqueLocal &&
      !linkLocal &&
      !multicast &&
      !documentation &&
      !nat64;
}

bool _sameAddress(String left, String right) {
  final leftBytes = _parseAddress(left);
  final rightBytes = _parseAddress(right);
  if (leftBytes == null ||
      rightBytes == null ||
      leftBytes.length != rightBytes.length) {
    return false;
  }
  for (var index = 0; index < leftBytes.length; index += 1) {
    if (leftBytes[index] != rightBytes[index]) return false;
  }
  return true;
}

String _canonicalFetchUri(Uri uri) => uri
    .removeFragment()
    .replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
    )
    .toString();

bool _isRedirect(int statusCode) =>
    statusCode == 301 ||
    statusCode == 302 ||
    statusCode == 303 ||
    statusCode == 307 ||
    statusCode == 308;

bool _isHtmlContentType(String? value) {
  final mediaType = value?.split(';').first.trim().toLowerCase();
  return mediaType == 'text/html' || mediaType == 'application/xhtml+xml';
}

String _decodeHtml(Uint8List bytes, String? contentType) {
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
          (bytes[0] == 0xfe && bytes[1] == 0xff))) {
    throw const FormatException('UTF-16 is not accepted');
  }
  final charset = RegExp(
    r'''charset\s*=\s*["']?([^;"'\s]+)''',
    caseSensitive: false,
  ).firstMatch(contentType ?? '')?.group(1)?.toLowerCase();
  if (charset != null && charset != 'utf-8' && charset != 'utf8') {
    throw const FormatException('Unsupported HTML encoding');
  }
  final offset = bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf
      ? 3
      : 0;
  return utf8.decode(bytes.sublist(offset), allowMalformed: false);
}

Duration? _retryAfter(String? value) {
  final seconds = int.tryParse(value?.trim() ?? '');
  if (seconds == null || seconds < 0 || seconds > 3600) return null;
  return Duration(seconds: seconds);
}

String _stableHostHash(String host) {
  var hash = 0x811c9dc5;
  for (final unit in host.toLowerCase().codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
