import 'dart:async';
import 'dart:convert';

import 'package:river_extract/river_extract.dart';
import 'package:test/test.dart';

void main() {
  group('cloud full-text rescue', () {
    test('pins a public address and sanitizes malicious remote HTML', () async {
      final fixture = _Fixture(
        responses: <CloudExtractionFetchResponse>[
          _htmlResponse(_maliciousArticle),
        ],
      );

      final result = await fixture.service.rescue(
        sourceUri: Uri.parse('https://news.example.test/private-path'),
        articleId: 'article-1',
      );

      expect(result, isA<CloudExtractionSuccess>());
      final success = result as CloudExtractionSuccess;
      expect(success.article.plainText, contains('安全正文段落'));
      expect(success.article.html, isNot(contains('<script')));
      expect(success.article.html, isNot(contains('<iframe')));
      expect(success.article.html, isNot(contains('javascript:')));
      expect(success.article.html, isNot(contains('onerror')));
      expect(success.article.imageUrls.single.scheme, 'https');
      expect(
        fixture.transport.requests.single.resolvedAddress,
        '93.184.216.34',
      );
      expect(fixture.transport.requests.single.uri.host, 'news.example.test');
    });

    test('rejects local hostnames and credential URLs before DNS', () async {
      final fixture = _Fixture();
      for (final uri in <Uri>[
        Uri.parse('https://localhost/article'),
        Uri.parse('https://service.internal/article'),
        Uri.parse('https://printer.local/article'),
        Uri.parse('https://user:secret@example.test/article'),
        Uri.parse('https://example.test:8443/article'),
      ]) {
        final result = await fixture.service.rescue(sourceUri: uri);
        expect(result, isA<CloudExtractionFailureResult>());
      }
      expect(fixture.dns.lookups, isEmpty);
      expect(fixture.transport.requests, isEmpty);
    });

    test('rejects non-global IPv4 and IPv6 address families', () {
      const blocked = <String>[
        '0.0.0.0',
        '10.0.0.1',
        '100.64.0.1',
        '127.0.0.1',
        '169.254.169.254',
        '172.16.0.1',
        '192.168.1.1',
        '198.18.0.1',
        '192.0.2.1',
        '198.51.100.1',
        '203.0.113.1',
        '224.0.0.1',
        '255.255.255.255',
        '::',
        '::1',
        '::ffff:127.0.0.1',
        '64:ff9b::127.0.0.1',
        'fc00::1',
        'fe80::1',
        'ff02::1',
        '2001:db8::1',
      ];
      for (final address in blocked) {
        expect(
          isPublicCloudExtractionAddress(address),
          isFalse,
          reason: address,
        );
      }
      expect(isPublicCloudExtractionAddress('8.8.8.8'), isTrue);
      expect(isPublicCloudExtractionAddress('2606:4700:4700::1111'), isTrue);
      expect(isPublicCloudExtractionAddress('010.0.0.1'), isFalse);
      expect(isPublicCloudExtractionAddress('not-an-address'), isFalse);
    });

    test('rejects a mixed public and private DNS answer set', () async {
      final fixture = _Fixture(
        dnsAnswers: <List<String>>[
          <String>['93.184.216.34', '10.0.0.7'],
        ],
      );

      final result = await fixture.rescue();

      _expectFailure(result, CloudExtractionFailureCode.blockedAddress);
      expect(fixture.transport.requests, isEmpty);
    });

    test('rejects transport connections that do not use the pinned address',
        () async {
      final fixture = _Fixture(
        responses: <CloudExtractionFetchResponse>[
          _htmlResponse(_maliciousArticle, connectedAddress: '1.1.1.1'),
        ],
      );

      final result = await fixture.rescue();

      _expectFailure(
        result,
        CloudExtractionFailureCode.connectedAddressMismatch,
      );
    });

    test('re-resolves every redirect and blocks DNS rebinding', () async {
      final fixture = _Fixture(
        dnsAnswers: <List<String>>[
          <String>['93.184.216.34'],
          <String>['127.0.0.1'],
        ],
        responses: <CloudExtractionFetchResponse>[
          _redirect('/second-hop'),
        ],
      );

      final result = await fixture.rescue();

      _expectFailure(result, CloudExtractionFailureCode.blockedAddress);
      expect(fixture.dns.lookups, hasLength(2));
      expect(fixture.transport.requests, hasLength(1));
    });

    test('rejects private redirects, HTTPS downgrade, loops, and overflow',
        () async {
      final cases =
          <({List<CloudExtractionFetchResponse> responses, int limit})>[
        (
          responses: <CloudExtractionFetchResponse>[
            _redirect('http://news.example.test/insecure'),
          ],
          limit: 3,
        ),
        (
          responses: <CloudExtractionFetchResponse>[
            _redirect('https://127.0.0.1/metadata'),
          ],
          limit: 3,
        ),
        (
          responses: <CloudExtractionFetchResponse>[_redirect('/article')],
          limit: 3,
        ),
        (
          responses: <CloudExtractionFetchResponse>[
            _redirect('/two'),
            _redirect('/three'),
          ],
          limit: 1,
        ),
      ];

      for (final item in cases) {
        final fixture = _Fixture(
          responses: item.responses,
          maximumRedirects: item.limit,
        );
        final result = await fixture.rescue();
        expect(result, isA<CloudExtractionFailureResult>());
        expect(
          (result as CloudExtractionFailureResult).failure.code,
          anyOf(
            CloudExtractionFailureCode.redirectRejected,
            CloudExtractionFailureCode.redirectLimit,
            CloudExtractionFailureCode.blockedAddress,
          ),
        );
      }
    });

    test('enforces declared, actual, and cumulative response byte bounds',
        () async {
      final declared = _Fixture(
        responses: <CloudExtractionFetchResponse>[
          CloudExtractionFetchResponse(
            statusCode: 200,
            connectedAddress: '93.184.216.34',
            bodyBytes: utf8.encode('small'),
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-8',
              'content-length': '2049',
            },
          ),
        ],
        maximumResponseBytes: 2048,
        maximumTotalBytes: 3072,
      );
      _expectFailure(
        await declared.rescue(),
        CloudExtractionFailureCode.responseTooLarge,
      );

      final actual = _Fixture(
        responses: <CloudExtractionFetchResponse>[
          _htmlResponse(_repeat('x', 2049)),
        ],
        maximumResponseBytes: 2048,
        maximumTotalBytes: 3072,
      );
      _expectFailure(
        await actual.rescue(),
        CloudExtractionFailureCode.responseTooLarge,
      );

      final cumulative = _Fixture(
        responses: <CloudExtractionFetchResponse>[
          _redirect('/next', body: _repeat('x', 1500)),
          _htmlResponse(_repeat('y', 1600)),
        ],
        maximumResponseBytes: 2048,
        maximumTotalBytes: 3000,
      );
      _expectFailure(
        await cumulative.rescue(),
        CloudExtractionFailureCode.responseTooLarge,
      );
      expect(cumulative.transport.requests.last.maximumResponseBytes, 1500);
    });

    test('maps DNS and transport timeouts to one stable retryable failure',
        () async {
      final dnsTimeout = _Fixture(dnsError: TimeoutException('private DNS'));
      final dnsResult = await dnsTimeout.rescue();
      _expectFailure(dnsResult, CloudExtractionFailureCode.timeout);
      expect(
        (dnsResult as CloudExtractionFailureResult).failure.retryable,
        isTrue,
      );

      final transportTimeout = _Fixture(
        transportError: TimeoutException('private socket'),
      );
      _expectFailure(
        await transportTimeout.rescue(),
        CloudExtractionFailureCode.timeout,
      );
    });

    test('DNS time is deducted from the total transport deadline', () async {
      final clock = _MutableClock();
      final dns = _AdvancingDns(clock, const Duration(seconds: 7));
      final transport = _Transport(<CloudExtractionFetchResponse>[
        _htmlResponse(_maliciousArticle),
      ]);
      final service = CloudFullTextRescueService(
        dns: dns,
        transport: transport,
        clock: clock,
        policy: const CloudExtractionPolicy(
          totalTimeout: Duration(seconds: 10),
          perHopTimeout: Duration(seconds: 8),
        ),
      );

      final result = await service.rescue(
        sourceUri: Uri.parse('https://news.example.test/article'),
      );

      expect(result, isA<CloudExtractionSuccess>());
      expect(
        transport.requests.single.timeout,
        const Duration(seconds: 3),
      );
    });

    test('rejects unsupported media types and malformed encodings', () async {
      final binary = _Fixture(
        responses: <CloudExtractionFetchResponse>[
          CloudExtractionFetchResponse(
            statusCode: 200,
            connectedAddress: '93.184.216.34',
            bodyBytes: const <int>[0, 1, 2],
            headers: const <String, String>{
              'content-type': 'application/octet-stream',
            },
          ),
        ],
      );
      _expectFailure(
        await binary.rescue(),
        CloudExtractionFailureCode.unsupportedContent,
      );

      final malformed = _Fixture(
        responses: <CloudExtractionFetchResponse>[
          CloudExtractionFetchResponse(
            statusCode: 200,
            connectedAddress: '93.184.216.34',
            bodyBytes: const <int>[0xff, 0xfe, 0, 0],
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-16',
            },
          ),
        ],
      );
      _expectFailure(
        await malformed.rescue(),
        CloudExtractionFailureCode.invalidResponse,
      );
    });

    test('request and response diagnostics exclude host, path, and body', () {
      final request = CloudExtractionFetchRequest(
        uri: Uri.parse('https://private.example.test/secret/path'),
        resolvedAddress: '93.184.216.34',
        timeout: const Duration(seconds: 5),
        maximumResponseBytes: 2048,
      );
      final response = _htmlResponse('private response body');

      expect(request.toString(), isNot(contains('private.example.test')));
      expect(request.toString(), isNot(contains('secret/path')));
      expect(response.toString(), isNot(contains('private response body')));
      expect(response.toString(), isNot(contains('93.184.216.34')));
    });

    test('response headers reject control characters before diagnostics', () {
      expect(
        () => CloudExtractionFetchResponse(
          statusCode: 302,
          connectedAddress: '93.184.216.34',
          bodyBytes: const <int>[],
          headers: const <String, String>{
            'location': 'https://example.test/ok\r\ninjected: value',
          },
        ),
        throwsArgumentError,
      );
    });
  });
}

final class _Fixture {
  _Fixture({
    List<List<String>> dnsAnswers = const <List<String>>[
      <String>['93.184.216.34'],
    ],
    List<CloudExtractionFetchResponse> responses =
        const <CloudExtractionFetchResponse>[],
    Exception? dnsError,
    Exception? transportError,
    int maximumRedirects = 3,
    int maximumResponseBytes = 2 * 1024 * 1024,
    int maximumTotalBytes = 3 * 1024 * 1024,
  })  : dns = _Dns(dnsAnswers, error: dnsError),
        transport = _Transport(responses, error: transportError) {
    service = CloudFullTextRescueService(
      dns: dns,
      transport: transport,
      clock: const _Clock(),
      policy: CloudExtractionPolicy(
        maximumRedirects: maximumRedirects,
        maximumResponseBytes: maximumResponseBytes,
        maximumTotalBytes: maximumTotalBytes,
      ),
    );
  }

  final _Dns dns;
  final _Transport transport;
  late final CloudFullTextRescueService service;

  Future<CloudExtractionResult> rescue() => service.rescue(
        sourceUri: Uri.parse('https://news.example.test/article'),
      );
}

final class _Dns implements CloudExtractionDnsResolver {
  _Dns(List<List<String>> answers, {this.error})
      : _answers = answers.map(List<String>.from).toList();

  final List<List<String>> _answers;
  final Exception? error;
  final List<String> lookups = <String>[];

  @override
  Future<List<String>> resolve(String host) async {
    lookups.add(host);
    if (error case final Exception value) throw value;
    if (_answers.isEmpty) return const <String>[];
    return _answers.length == 1 ? _answers.single : _answers.removeAt(0);
  }
}

final class _Transport implements CloudExtractionPinnedTransport {
  _Transport(List<CloudExtractionFetchResponse> responses, {this.error})
      : _responses = List<CloudExtractionFetchResponse>.from(responses);

  final List<CloudExtractionFetchResponse> _responses;
  final Exception? error;
  final List<CloudExtractionFetchRequest> requests =
      <CloudExtractionFetchRequest>[];

  @override
  Future<CloudExtractionFetchResponse> get(
    CloudExtractionFetchRequest request,
  ) async {
    requests.add(request);
    if (error case final Exception value) throw value;
    if (_responses.isEmpty) return _htmlResponse(_maliciousArticle);
    return _responses.removeAt(0);
  }
}

final class _Clock implements CloudExtractionClock {
  const _Clock();

  @override
  Duration elapsed() => Duration.zero;
}

final class _MutableClock implements CloudExtractionClock {
  Duration value = Duration.zero;

  @override
  Duration elapsed() => value;
}

final class _AdvancingDns implements CloudExtractionDnsResolver {
  _AdvancingDns(this.clock, this.advance);

  final _MutableClock clock;
  final Duration advance;

  @override
  Future<List<String>> resolve(String host) async {
    clock.value += advance;
    return <String>['93.184.216.34'];
  }
}

CloudExtractionFetchResponse _htmlResponse(
  String html, {
  String connectedAddress = '93.184.216.34',
}) =>
    CloudExtractionFetchResponse(
      statusCode: 200,
      connectedAddress: connectedAddress,
      bodyBytes: utf8.encode(html),
      headers: <String, String>{
        'content-type': 'text/html; charset=utf-8',
        'content-length': utf8.encode(html).length.toString(),
      },
    );

CloudExtractionFetchResponse _redirect(String location, {String body = ''}) =>
    CloudExtractionFetchResponse(
      statusCode: 302,
      connectedAddress: '93.184.216.34',
      bodyBytes: utf8.encode(body),
      headers: <String, String>{
        'location': location,
        'content-length': utf8.encode(body).length.toString(),
      },
    );

void _expectFailure(
  CloudExtractionResult result,
  CloudExtractionFailureCode code,
) {
  expect(result, isA<CloudExtractionFailureResult>());
  expect((result as CloudExtractionFailureResult).failure.code, code);
}

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();

final _longParagraph = List<String>.filled(
  20,
  '安全正文段落包含足够多的可读文字，用于验证云端救援解析与净化流程。',
).join();

final _maliciousArticle = '''
<html><head><title>云端救援测试</title></head><body>
<article>
  <h1>云端救援测试</h1>
  <p>$_longParagraph</p>
  <script>fetch('https://attacker.invalid')</script>
  <iframe src="https://attacker.invalid/frame"></iframe>
  <form action="https://attacker.invalid"><input name="secret"></form>
  <a href="javascript:alert(1)">危险链接</a>
  <img src="https://images.example.test/safe.png"
       onerror="alert(1)" alt="safe">
  <img src="file:///private/token" alt="blocked">
</article>
</body></html>
''';
