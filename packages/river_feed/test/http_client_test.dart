import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test('sets bounded feed headers and decodes declared charset', () async {
    late http.Request captured;
    final port = BoundedHttpPort(
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          latin1.encode('café'),
          200,
          headers: const {'content-type': 'text/plain; charset=iso-8859-1'},
        );
      }),
      userAgent: 'River-Test/1',
    );
    addTearDown(port.close);

    final response = await port.get(Uri.parse('https://example.test/feed'));

    expect(response.body, 'café');
    expect(captured.headers['user-agent'], 'River-Test/1');
    expect(captured.followRedirects, isFalse);
  });

  test('follows bounded relative redirects', () async {
    final seen = <Uri>[];
    final port = BoundedHttpPort(
      client: MockClient((request) async {
        seen.add(request.url);
        if (request.url.path == '/start') {
          return http.Response('', 302, headers: const {'location': '/feed'});
        }
        return http.Response('ok', 200);
      }),
    );
    addTearDown(port.close);

    final response = await port.get(Uri.parse('https://example.test/start'));

    expect(response.body, 'ok');
    expect(seen, <Uri>[
      Uri.parse('https://example.test/start'),
      Uri.parse('https://example.test/feed'),
    ]);
  });

  test('rejects redirect loops and non-HTTP URLs', () async {
    final port = BoundedHttpPort(
      client: MockClient(
        (request) async =>
            http.Response('', 302, headers: const {'location': '/loop'}),
      ),
    );
    addTearDown(port.close);

    await expectLater(
      port.get(Uri.parse('https://example.test/loop')),
      throwsA(isA<HttpBoundaryException>()),
    );
    await expectLater(
      port.get(Uri.parse('file:///private/feed.xml')),
      throwsA(isA<HttpBoundaryException>()),
    );
  });

  test('rejects responses above the configured byte limit', () async {
    final port = BoundedHttpPort(
      client: MockClient((request) async => http.Response('12345', 200)),
      maxResponseBytes: 4,
    );
    addTearDown(port.close);

    await expectLater(
      port.get(Uri.parse('https://example.test/feed')),
      throwsA(isA<HttpBoundaryException>()),
    );
  });

  test('times out a request that never produces headers', () async {
    final pending = Completer<http.Response>();
    final port = BoundedHttpPort(
      client: MockClient((request) => pending.future),
      requestTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(port.close);

    await expectLater(
      port.get(Uri.parse('https://example.test/feed')),
      throwsA(isA<HttpBoundaryException>()),
    );
  });
}
