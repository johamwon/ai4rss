import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'notion_models.dart';

final class IoNotionHttpTransport implements NotionHttpTransport {
  IoNotionHttpTransport({
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 30),
    this.maxResponseBytes = 2 * 1024 * 1024,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  final Duration timeout;
  final int maxResponseBytes;

  @override
  Future<NotionHttpResponse> send(NotionHttpRequest request) async {
    final client = _clientFactory()
      ..connectionTimeout = timeout
      ..autoUncompress = true;
    try {
      final ioRequest =
          await client.openUrl(request.method, request.uri).timeout(timeout);
      ioRequest.followRedirects = false;
      request.headers.forEach(ioRequest.headers.set);
      if (request.body case final body?) {
        ioRequest.add(utf8.encode(body));
      }
      final response = await ioRequest.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in response.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > maxResponseBytes) {
          throw const NotionTransportFailure(
            NotionTransportFailureCode.responseTooLarge,
          );
        }
      }
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.join(',');
      });
      return NotionHttpResponse(
        statusCode: response.statusCode,
        body: utf8.decode(bytes, allowMalformed: false),
        headers: headers,
      );
    } on NotionTransportFailure {
      rethrow;
    } on TimeoutException {
      throw const NotionTransportFailure(NotionTransportFailureCode.timeout);
    } on SocketException {
      throw const NotionTransportFailure(NotionTransportFailureCode.offline);
    } on HandshakeException {
      throw const NotionTransportFailure(NotionTransportFailureCode.offline);
    } on FormatException {
      throw const NotionTransportFailure(NotionTransportFailureCode.invalid);
    } on HttpException {
      throw const NotionTransportFailure(NotionTransportFailureCode.invalid);
    } finally {
      client.close(force: true);
    }
  }
}
