import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enough_convert/enough_convert.dart';
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
      resolver: const _Resolver(),
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
      resolver: const _Resolver(),
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
      resolver: const _Resolver(),
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
      resolver: const _Resolver(),
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
      resolver: const _Resolver(),
      requestTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(port.close);

    await expectLater(
      port.get(Uri.parse('https://example.test/feed')),
      throwsA(isA<HttpBoundaryException>()),
    );
  });

  test('decodes gzip and deflate before enforcing the expanded byte limit',
      () async {
    for (final scenario in <(String, List<int>)>[
      ('gzip', gzip.encode(utf8.encode('compressed feed'))),
      ('deflate', zlib.encode(utf8.encode('compressed feed'))),
    ]) {
      final port = BoundedHttpPort(
        client: MockClient(
          (request) async => http.Response.bytes(
            scenario.$2,
            200,
            headers: <String, String>{'content-encoding': scenario.$1},
          ),
        ),
        resolver: const _Resolver(),
      );
      addTearDown(port.close);
      final response = await port.get(Uri.parse('https://example.test/feed'));
      expect(response.body, 'compressed feed');
    }

    final bomb = BoundedHttpPort(
      client: MockClient(
        (request) async => http.Response.bytes(
          gzip.encode(utf8.encode('x' * 1000)),
          200,
          headers: const <String, String>{'content-encoding': 'gzip'},
        ),
      ),
      resolver: const _Resolver(),
      maxResponseBytes: 100,
    );
    addTearDown(bomb.close);
    await expectLater(
      bomb.get(Uri.parse('https://example.test/feed')),
      throwsA(isA<HttpBoundaryException>()),
    );
  });

  test('decodes GBK, Big5 and Windows-1252 declarations', () async {
    for (final scenario in <(String, Encoding, String)>[
      ('gbk', const GbkCodec(), '中文订阅'),
      ('big5', const Big5Codec(), '中文訂閱'),
      ('windows-1252', const Windows1252Codec(), 'café €'),
    ]) {
      final port = BoundedHttpPort(
        client: MockClient(
          (request) async => http.Response.bytes(
            scenario.$2.encode(scenario.$3),
            200,
            headers: <String, String>{
              'content-type': 'application/xml; charset=${scenario.$1}',
            },
          ),
        ),
        resolver: const _Resolver(),
      );
      addTearDown(port.close);
      final response = await port.get(Uri.parse('https://example.test/feed'));
      expect(response.body, scenario.$3);
    }
  });

  test('blocks private, mixed, empty and credential-bearing targets', () async {
    Future<void> blocked(List<String> addresses) async {
      final port = BoundedHttpPort(
        client: MockClient((request) async => http.Response('never', 200)),
        resolver: _Resolver(addresses),
      );
      addTearDown(port.close);
      await expectLater(
        port.get(Uri.parse('https://example.test/feed')),
        throwsA(isA<HttpBoundaryException>()),
      );
    }

    await blocked(const <String>['127.0.0.1']);
    await blocked(const <String>['93.184.216.34', '10.0.0.2']);
    await blocked(const <String>[]);
    final safe = BoundedHttpPort(
      client: MockClient((request) async => http.Response('never', 200)),
      resolver: const _Resolver(),
    );
    addTearDown(safe.close);
    await expectLater(
      safe.get(Uri.parse('https://user:secret@example.test/feed')),
      throwsA(isA<HttpBoundaryException>()),
    );
  });

  test('drops validators on cross-origin redirects', () async {
    final seen = <http.Request>[];
    final port = BoundedHttpPort(
      client: MockClient((request) async {
        seen.add(request);
        return request.url.host == 'one.example'
            ? http.Response(
                '',
                302,
                headers: const <String, String>{
                  'location': 'https://two.example/feed',
                },
              )
            : http.Response('ok', 200);
      }),
      resolver: const _Resolver(),
    );
    addTearDown(port.close);

    await port.get(
      Uri.parse('https://one.example/feed'),
      headers: const <String, String>{'if-none-match': 'private-etag'},
    );

    expect(seen.first.headers['if-none-match'], 'private-etag');
    expect(seen.last.headers, isNot(contains('if-none-match')));
  });
}

final class _Resolver implements FeedAddressResolver {
  const _Resolver([this.addresses = const <String>['93.184.216.34']]);

  final List<String> addresses;

  @override
  Future<List<String>> resolve(String host) async => addresses;
}
