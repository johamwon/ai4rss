import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum AiHttpTransportFailureCode {
  offline,
  timeout,
  responseTooLarge,
  invalidResponse,
}

final class AiHttpTransportFailure implements Exception {
  const AiHttpTransportFailure(this.code);

  final AiHttpTransportFailureCode code;

  @override
  String toString() => 'AiHttpTransportFailure(${code.name})';
}

final class AiHttpRequest {
  AiHttpRequest({
    required this.uri,
    required Map<String, String> headers,
    required this.body,
    required this.timeout,
  }) : headers = Map<String, String>.unmodifiable(headers) {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw ArgumentError.value(uri, 'uri');
    }
    if (body.isEmpty || utf8.encode(body).length > 256 * 1024) {
      throw ArgumentError.value(body.length, 'body.length');
    }
    if (timeout < const Duration(seconds: 1) ||
        timeout > const Duration(minutes: 2)) {
      throw ArgumentError.value(timeout, 'timeout');
    }
  }

  final Uri uri;
  final Map<String, String> headers;
  final String body;
  final Duration timeout;

  @override
  String toString() => 'AiHttpRequest('
      'origin: ${uri.origin}, '
      'pathSegments: ${uri.pathSegments.length}, '
      'headerNames: ${headers.keys.toList(growable: false)}, '
      'bodyBytes: ${utf8.encode(body).length}, '
      'timeout: ${timeout.inSeconds}s'
      ')';
}

final class AiHttpResponse {
  AiHttpResponse({
    required this.statusCode,
    required this.body,
    Map<String, String> headers = const <String, String>{},
  }) : headers = Map<String, String>.unmodifiable(
          <String, String>{
            for (final entry in headers.entries)
              entry.key.toLowerCase(): entry.value,
          },
        ) {
    if (statusCode < 100 || statusCode > 599) {
      throw RangeError.value(statusCode, 'statusCode');
    }
  }

  final int statusCode;
  final String body;
  final Map<String, String> headers;

  @override
  String toString() => 'AiHttpResponse('
      'statusCode: $statusCode, '
      'bodyBytes: ${utf8.encode(body).length}, '
      'headerNames: ${headers.keys.toList(growable: false)}'
      ')';
}

abstract interface class AiHttpTransport {
  Future<AiHttpResponse> send(AiHttpRequest request);
}

final class PackageHttpAiTransport implements AiHttpTransport {
  PackageHttpAiTransport({
    http.Client? client,
    this.maxResponseBytes = 1024 * 1024,
  }) : _client = client ?? http.Client() {
    if (maxResponseBytes < 1024 || maxResponseBytes > 4 * 1024 * 1024) {
      throw RangeError.range(
        maxResponseBytes,
        1024,
        4 * 1024 * 1024,
        'maxResponseBytes',
      );
    }
  }

  final http.Client _client;
  final int maxResponseBytes;

  void close() => _client.close();

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    try {
      final outgoing = http.Request('POST', request.uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.addAll(request.headers)
        ..body = request.body;
      final streamed = await _client.send(outgoing).timeout(request.timeout);
      final bytes = <int>[];
      await for (final chunk in streamed.stream.timeout(request.timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > maxResponseBytes) {
          throw const AiHttpTransportFailure(
            AiHttpTransportFailureCode.responseTooLarge,
          );
        }
      }
      final headers = <String, String>{
        for (final entry in streamed.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };
      return AiHttpResponse(
        statusCode: streamed.statusCode,
        body: utf8.decode(bytes, allowMalformed: false),
        headers: headers,
      );
    } on AiHttpTransportFailure {
      rethrow;
    } on TimeoutException {
      throw const AiHttpTransportFailure(AiHttpTransportFailureCode.timeout);
    } on FormatException {
      throw const AiHttpTransportFailure(
        AiHttpTransportFailureCode.invalidResponse,
      );
    } on http.ClientException {
      throw const AiHttpTransportFailure(AiHttpTransportFailureCode.offline);
    }
  }
}
