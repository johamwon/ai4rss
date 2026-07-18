import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:river_domain/river_domain.dart';

final class RenderedPageSnapshot {
  const RenderedPageSnapshot({required this.html, required this.finalUri});

  final String html;
  final Uri finalUri;
}

abstract interface class HeadlessPageLoader {
  Future<RenderedPageSnapshot> load(
    Uri sourceUri, {
    required Duration timeout,
  });
}

final class HeadlessPageLoadException implements Exception {
  const HeadlessPageLoadException({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final ExtractionFailureCode code;
  final String message;
  final bool retryable;
}

final class InAppWebViewDynamicPageRenderer implements DynamicPageRenderer {
  InAppWebViewDynamicPageRenderer({HeadlessPageLoader? loader})
      : _loader = loader ?? const InAppWebViewHeadlessPageLoader();

  final HeadlessPageLoader _loader;

  @override
  Future<DynamicPageRenderResult> render(
    DynamicPageRenderRequest request,
  ) async {
    if (!_isHttpUri(request.sourceUri) ||
        request.timeout <= Duration.zero ||
        request.maxHtmlCharacters <= 0) {
      return const DynamicPageRenderFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.invalidInput,
          message: 'Dynamic rendering requires a bounded HTTP or HTTPS URL.',
        ),
      );
    }

    try {
      final page = await _loader.load(
        request.sourceUri,
        timeout: request.timeout,
      );
      if (!_isHttpUri(page.finalUri)) {
        return const DynamicPageRenderFailure(
          ExtractionFailure(
            code: ExtractionFailureCode.unsafeContent,
            message: 'Dynamic rendering navigated to a blocked URL scheme.',
          ),
        );
      }
      if (page.html.length > request.maxHtmlCharacters) {
        return const DynamicPageRenderFailure(
          ExtractionFailure(
            code: ExtractionFailureCode.responseTooLarge,
            message: 'The rendered page exceeds the extraction size limit.',
          ),
        );
      }
      return DynamicPageRenderSuccess(
        html: page.html,
        finalUri: page.finalUri,
      );
    } on TimeoutException {
      return const DynamicPageRenderFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.timeout,
          message: 'Dynamic page rendering timed out.',
          retryable: true,
        ),
      );
    } on HeadlessPageLoadException catch (error) {
      return DynamicPageRenderFailure(
        ExtractionFailure(
          code: error.code,
          message: error.message,
          retryable: error.retryable,
        ),
      );
    } catch (_) {
      return const DynamicPageRenderFailure(
        ExtractionFailure(
          code: ExtractionFailureCode.unavailable,
          message: 'Dynamic page rendering is unavailable on this device.',
          retryable: true,
        ),
      );
    }
  }
}

final class InAppWebViewHeadlessPageLoader implements HeadlessPageLoader {
  const InAppWebViewHeadlessPageLoader({
    this.domSettleDelay = const Duration(milliseconds: 250),
    this.maxMainFrameNavigations = 8,
  });

  final Duration domSettleDelay;
  final int maxMainFrameNavigations;

  @override
  Future<RenderedPageSnapshot> load(
    Uri sourceUri, {
    required Duration timeout,
  }) async {
    final completion = Completer<RenderedPageSnapshot>();
    var mainFrameNavigations = 0;

    void fail(HeadlessPageLoadException error) {
      if (!completion.isCompleted) completion.completeError(error);
    }

    late final HeadlessInAppWebView webView;
    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(sourceUri.toString())),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: false,
        useShouldOverrideUrlLoading: true,
        allowFileAccess: false,
        allowContentAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        geolocationEnabled: false,
        mediaPlaybackRequiresUserGesture: true,
        thirdPartyCookiesEnabled: false,
        cacheEnabled: true,
      ),
      shouldOverrideUrlLoading: (controller, navigation) async {
        final target = navigation.request.url;
        if (target == null || !_isHttpUri(target)) {
          fail(
            const HeadlessPageLoadException(
              code: ExtractionFailureCode.unsafeContent,
              message: 'The page attempted to navigate to a blocked URL.',
            ),
          );
          return NavigationActionPolicy.CANCEL;
        }
        if (navigation.isForMainFrame &&
            ++mainFrameNavigations > maxMainFrameNavigations) {
          fail(
            const HeadlessPageLoadException(
              code: ExtractionFailureCode.network,
              message: 'The page exceeded the navigation limit.',
              retryable: true,
            ),
          );
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onCreateWindow: (_, __) async => false,
      onReceivedError: (_, request, __) {
        if (request.isForMainFrame ?? true) {
          fail(
            const HeadlessPageLoadException(
              code: ExtractionFailureCode.network,
              message: 'The page failed to load in the platform WebView.',
              retryable: true,
            ),
          );
        }
      },
      onReceivedHttpError: (_, request, response) {
        if ((request.isForMainFrame ?? true) &&
            (response.statusCode ?? 0) >= 400) {
          fail(
            const HeadlessPageLoadException(
              code: ExtractionFailureCode.network,
              message: 'The page returned an unsuccessful HTTP response.',
              retryable: true,
            ),
          );
        }
      },
      onLoadStop: (controller, url) async {
        await Future<void>.delayed(domSettleDelay);
        if (completion.isCompleted) return;
        final html = await controller.getHtml();
        final finalUri = Uri.tryParse(url?.toString() ?? '');
        if (html == null || html.trim().isEmpty || finalUri == null) {
          fail(
            const HeadlessPageLoadException(
              code: ExtractionFailureCode.malformedDocument,
              message: 'The platform WebView returned an empty document.',
            ),
          );
          return;
        }
        completion.complete(
          RenderedPageSnapshot(html: html, finalUri: finalUri),
        );
      },
    );

    try {
      await webView.run();
      return await completion.future.timeout(timeout);
    } finally {
      await webView.dispose();
    }
  }
}

bool _isHttpUri(Uri uri) =>
    uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
