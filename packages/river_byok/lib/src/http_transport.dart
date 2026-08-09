import 'dart:async';

import 'package:http/http.dart' as http;

enum ByokHttpFailureCode { offline, timeout, responseTooLarge, invalidResponse }

final class ByokHttpFailure implements Exception {
  const ByokHttpFailure(this.code);

  final ByokHttpFailureCode code;

  @override
  String toString() => 'ByokHttpFailure(${code.name})';
}

final class ByokHttpRequest {
  ByokHttpRequest({
    required this.method,
    required this.uri,
    required Map<String, String> headers,
    List<int> body = const <int>[],
    this.timeout = const Duration(seconds: 45),
    this.maximumResponseBytes = 1024 * 1024,
  })  : headers = Map<String, String>.unmodifiable(headers),
        body = List<int>.unmodifiable(body) {
    if (method != 'GET' && method != 'POST') {
      throw ArgumentError.value(method, 'method');
    }
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw ArgumentError.value(uri, 'uri');
    }
    if (method == 'GET' && body.isNotEmpty) {
      throw ArgumentError('GET request cannot contain a body');
    }
    // Leave room for multipart headers around the documented 100 MiB podcast
    // asset limit. Individual asset validation remains stricter.
    if (body.length > 128 * 1024 * 1024) {
      throw ArgumentError.value(body.length, 'body.length');
    }
    if (timeout < const Duration(seconds: 1) ||
        timeout > const Duration(minutes: 15)) {
      throw ArgumentError.value(timeout, 'timeout');
    }
    if (maximumResponseBytes < 1024 ||
        maximumResponseBytes > 32 * 1024 * 1024) {
      throw ArgumentError.value(maximumResponseBytes, 'maximumResponseBytes');
    }
  }

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int> body;
  final Duration timeout;
  final int maximumResponseBytes;

  @override
  String toString() => 'ByokHttpRequest('
      'method: $method, pathSegments: ${uri.pathSegments.length}, '
      'headerNames: ${headers.keys.toList(growable: false)}, '
      'bodyBytes: ${body.length}, timeout: ${timeout.inSeconds}s)';
}

final class ByokHttpResponse {
  ByokHttpResponse({
    required this.statusCode,
    required List<int> body,
    Map<String, String> headers = const <String, String>{},
  })  : body = List<int>.unmodifiable(body),
        headers = Map<String, String>.unmodifiable(<String, String>{
          for (final entry in headers.entries)
            entry.key.toLowerCase(): entry.value,
        }) {
    if (statusCode < 100 || statusCode > 599) {
      throw RangeError.value(statusCode, 'statusCode');
    }
  }

  final int statusCode;
  final List<int> body;
  final Map<String, String> headers;

  @override
  String toString() => 'ByokHttpResponse('
      'statusCode: $statusCode, bodyBytes: ${body.length}, '
      'headerNames: ${headers.keys.toList(growable: false)})';
}

abstract interface class ByokHttpTransport {
  Future<ByokHttpResponse> send(ByokHttpRequest request);
}

final class PackageByokHttpTransport implements ByokHttpTransport {
  PackageByokHttpTransport({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  @override
  Future<ByokHttpResponse> send(ByokHttpRequest request) async {
    try {
      final outgoing = http.Request(request.method, request.uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.addAll(request.headers);
      if (request.body.isNotEmpty) outgoing.bodyBytes = request.body;
      final streamed = await _client.send(outgoing).timeout(request.timeout);
      final bytes = <int>[];
      await for (final chunk in streamed.stream.timeout(request.timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > request.maximumResponseBytes) {
          throw const ByokHttpFailure(ByokHttpFailureCode.responseTooLarge);
        }
      }
      return ByokHttpResponse(
        statusCode: streamed.statusCode,
        body: bytes,
        headers: streamed.headers,
      );
    } on ByokHttpFailure {
      rethrow;
    } on TimeoutException {
      throw const ByokHttpFailure(ByokHttpFailureCode.timeout);
    } on http.ClientException {
      throw const ByokHttpFailure(ByokHttpFailureCode.offline);
    } on Object {
      throw const ByokHttpFailure(ByokHttpFailureCode.invalidResponse);
    }
  }
}
