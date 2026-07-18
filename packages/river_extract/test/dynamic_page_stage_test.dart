import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:test/test.dart';

void main() {
  test('dynamic rendering runs only after all static stages fail', () async {
    var calls = 0;
    final extractor = LayeredFullTextExtractor.withDynamicPageRenderer(
      _Renderer((_) async {
        calls++;
        return DynamicPageRenderSuccess(
          html: _articleHtml,
          finalUri: Uri.parse('https://example.com/rendered'),
        );
      }),
    );

    final result = await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.com/article'),
        pageHtml: '<html><body><div id="app"></div></body></html>',
      ),
    );

    expect(calls, 1);
    expect(result, isA<ExtractionSuccess>());
    final success = result as ExtractionSuccess;
    expect(success.article.extractor, 'dynamic-page');
    expect(success.article.plainText, contains('Rendered article'));
    expect(success.attempts.last.extractor, 'dynamic-page');
    expect(success.attempts.last.outcome, ExtractionAttemptOutcome.succeeded);
  });

  test('trusted feed content avoids the platform renderer', () async {
    var calls = 0;
    final extractor = LayeredFullTextExtractor.withDynamicPageRenderer(
      _Renderer((_) async {
        calls++;
        throw StateError('must not render');
      }),
    );

    final result = await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.com/article'),
        feedContentHtml: _articleHtml,
      ),
    );

    expect(result, isA<ExtractionSuccess>());
    expect(calls, 0);
  });

  test('classified renderer failures are preserved in attempt history',
      () async {
    final extractor = LayeredFullTextExtractor.withDynamicPageRenderer(
      _Renderer(
        (_) async => const DynamicPageRenderFailure(
          ExtractionFailure(
            code: ExtractionFailureCode.timeout,
            message: 'timed out',
            retryable: true,
          ),
        ),
      ),
    );

    final result = await extractor.extract(
      ExtractionRequest(
        sourceUri: Uri.parse('https://example.com/article'),
        pageHtml: '<html><body><div id="app"></div></body></html>',
      ),
    );

    expect(result, isA<ExtractionFailureResult>());
    expect(
      (result as ExtractionFailureResult).failure.code,
      ExtractionFailureCode.timeout,
    );
    expect(result.attempts.last.extractor, 'dynamic-page');
    expect(result.attempts.last.failureCode, ExtractionFailureCode.timeout);
  });
}

final class _Renderer implements DynamicPageRenderer {
  const _Renderer(this.operation);

  final Future<DynamicPageRenderResult> Function(
    DynamicPageRenderRequest request,
  ) operation;

  @override
  Future<DynamicPageRenderResult> render(DynamicPageRenderRequest request) =>
      operation(request);
}

const _articleHtml = '''
<!doctype html><html><head><title>Rendered article</title></head><body>
<article><h1>Rendered article</h1>
<p>This rendered article contains substantial explanatory text for a reader.
It is intentionally long enough for the extraction quality gate to trust.</p>
<p>Dynamic rendering happens only when feed content, source adapters, and the
static Readability pass cannot recover a complete article from the page.</p>
<p>The final content still passes through the shared sanitizer before storage,
so scripts, forms, event handlers, and unsafe resource URLs are removed.</p>
</article></body></html>
''';
