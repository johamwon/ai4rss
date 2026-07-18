import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('returns a rendered HTTP document through the domain contract',
      () async {
    final renderer = InAppWebViewDynamicPageRenderer(
      loader: _FakeLoader(
        (_) async => RenderedPageSnapshot(
          html: '<html><body>rendered</body></html>',
          finalUri: Uri.parse('https://example.com/final'),
        ),
      ),
    );

    final result = await renderer.render(
      DynamicPageRenderRequest(sourceUri: Uri.parse('https://example.com')),
    );

    expect(result, isA<DynamicPageRenderSuccess>());
    expect(
      (result as DynamicPageRenderSuccess).finalUri,
      Uri.parse('https://example.com/final'),
    );
  });

  test('rejects local URL schemes before invoking the platform loader',
      () async {
    var invoked = false;
    final renderer = InAppWebViewDynamicPageRenderer(
      loader: _FakeLoader((_) async {
        invoked = true;
        throw StateError('must not run');
      }),
    );

    final result = await renderer.render(
      DynamicPageRenderRequest(sourceUri: Uri.parse('file:///secret')),
    );

    expect(invoked, isFalse);
    expect(_failureCode(result), ExtractionFailureCode.invalidInput);
  });

  test('enforces timeout and rendered HTML size bounds', () async {
    final timeoutRenderer = InAppWebViewDynamicPageRenderer(
      loader: _FakeLoader((_) => Completer<RenderedPageSnapshot>().future),
    );
    final timeout = await timeoutRenderer.render(
      DynamicPageRenderRequest(
        sourceUri: Uri.parse('https://example.com'),
        timeout: const Duration(milliseconds: 1),
      ),
    );
    expect(_failureCode(timeout), ExtractionFailureCode.timeout);

    final largeRenderer = InAppWebViewDynamicPageRenderer(
      loader: _FakeLoader(
        (_) async => RenderedPageSnapshot(
          html: '12345',
          finalUri: Uri.parse('https://example.com'),
        ),
      ),
    );
    final tooLarge = await largeRenderer.render(
      DynamicPageRenderRequest(
        sourceUri: Uri.parse('https://example.com'),
        maxHtmlCharacters: 4,
      ),
    );
    expect(_failureCode(tooLarge), ExtractionFailureCode.responseTooLarge);
  });

  test('maps typed platform failures without exposing platform errors',
      () async {
    final renderer = InAppWebViewDynamicPageRenderer(
      loader: _FakeLoader(
        (_) async => throw const HeadlessPageLoadException(
          code: ExtractionFailureCode.network,
          message: 'bounded failure',
          retryable: true,
        ),
      ),
    );

    final result = await renderer.render(
      DynamicPageRenderRequest(sourceUri: Uri.parse('https://example.com')),
    );

    expect(_failureCode(result), ExtractionFailureCode.network);
    expect(
      (result as DynamicPageRenderFailure).failure.retryable,
      isTrue,
    );
  });
}

ExtractionFailureCode? _failureCode(DynamicPageRenderResult result) =>
    result is DynamicPageRenderFailure ? result.failure.code : null;

final class _FakeLoader implements HeadlessPageLoader {
  const _FakeLoader(this.operation);

  final Future<RenderedPageSnapshot> Function(Uri sourceUri) operation;

  @override
  Future<RenderedPageSnapshot> load(
    Uri sourceUri, {
    required Duration timeout,
  }) =>
      operation(sourceUri).timeout(timeout);
}
