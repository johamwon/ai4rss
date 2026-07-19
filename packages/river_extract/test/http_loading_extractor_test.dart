import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:test/test.dart';

void main() {
  test('complete feed content bypasses the article page request', () async {
    final http = _FakeHttp(
      const PortHttpResponse(statusCode: 200, body: '<p>unused</p>'),
    );
    final delegate = _RecordingExtractor();
    final extractor = HttpLoadingFullTextExtractor(
      http: http,
      delegate: delegate,
    );

    await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        feedContentHtml:
            '<p>${'Complete feed paragraph. ' * 40}</p><p>End.</p>',
      ),
    );

    expect(http.calls, 0);
    expect(delegate.requests.single.pageHtml, isNull);
  });

  test('summary content loads the static page before extraction', () async {
    final http = _FakeHttp(
      PortHttpResponse(
        statusCode: 200,
        body: '<article>Downloaded body</article>',
        effectiveUri: Uri.parse('https://example.test/final'),
      ),
    );
    final delegate = _RecordingExtractor();
    final extractor = HttpLoadingFullTextExtractor(
      http: http,
      delegate: delegate,
    );

    await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        articleId: 'article-1',
        feedSummary: 'Short summary',
      ),
    );

    expect(http.calls, 1);
    expect(delegate.requests.single.sourceUri.path, '/final');
    expect(delegate.requests.single.pageHtml, contains('Downloaded body'));
    expect(delegate.requests.single.articleId, 'article-1');
  });

  test('static request failure leaves platform fallback available', () async {
    final delegate = _RecordingExtractor();
    final extractor = HttpLoadingFullTextExtractor(
      http: _ThrowingHttp(),
      delegate: delegate,
    );

    await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.test/article'),
        feedSummary: 'Short summary',
      ),
    );

    expect(delegate.requests.single.pageHtml, isNull);
  });
}

final class _FakeHttp implements HttpPort {
  _FakeHttp(this.response);

  final PortHttpResponse response;
  var calls = 0;

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    calls += 1;
    return response;
  }
}

final class _ThrowingHttp implements HttpPort {
  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) =>
      Future<PortHttpResponse>.error(StateError('offline'));
}

final class _RecordingExtractor implements FullTextExtractor {
  final requests = <ExtractionRequest>[];

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) async {
    requests.add(request);
    return const ExtractionFailureResult(
      failure: ExtractionFailure(
        code: ExtractionFailureCode.unavailable,
        message: 'fixture',
      ),
      attempts: <ExtractionAttempt>[],
    );
  }
}
