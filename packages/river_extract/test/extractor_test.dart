import 'dart:io';

import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:test/test.dart';

void main() {
  group('HTML sanitizer', () {
    test('removes executable nodes, attributes, and dangerous URLs', () {
      final result = sanitizeHtmlFragment(
        '<article onclick="steal()"><p>Safe</p>'
        '<script>alert(1)</script><iframe src="https://bad.test"></iframe>'
        '<a href="java\nscript:steal()">bad</a>'
        '<img src="data:text/html,bad" onerror="steal()"></article>',
        baseUri: Uri.parse('https://example.test/article'),
      );

      expect(result.plainText, contains('Safe'));
      expect(result.html, isNot(contains('<script')));
      expect(result.html, isNot(contains('<iframe')));
      expect(result.html, isNot(contains('onclick')));
      expect(result.html, isNot(contains('onerror')));
      expect(result.html, isNot(contains('javascript:')));
      expect(result.html, isNot(contains('data:text')));
    });

    test('resolves safe relative resources', () {
      final result = sanitizeHtmlFragment(
        '<p><a href="/details">Details</a>'
        '<img src="images/river.png"></p>',
        baseUri: Uri.parse('https://example.test/articles/one'),
      );

      expect(result.html, contains('https://example.test/details'));
      expect(
        result.imageUrls.single,
        Uri.parse('https://example.test/articles/images/river.png'),
      );
    });
  });

  group('FeedContentAssessor', () {
    const assessor = FeedContentAssessor();

    test('accepts a structured complete feed body', () {
      final assessment = assessor.assess(
        contentHtml: _fixture('feed_full_synthetic.html'),
        summary: 'A much shorter summary.',
        sourceUri: Uri.parse('https://example.test/articles/full'),
      );

      expect(assessment.kind, FeedContentKind.full);
      expect(assessment.qualityScore, greaterThanOrEqualTo(0.62));
      expect(assessment.content.blockCount, greaterThanOrEqualTo(3));
    });

    test('rejects a short summary', () {
      final assessment = assessor.assess(
        summary: _fixture('feed_summary_synthetic.html'),
      );

      expect(assessment.kind, FeedContentKind.summary);
      expect(assessment.qualityScore, lessThan(0.62));
    });

    test('rejects explicit truncation markers despite enough structure', () {
      final assessment = assessor.assess(
        contentHtml: _fixture('feed_truncated_synthetic.html'),
      );

      expect(assessment.kind, FeedContentKind.truncated);
    });
  });

  group('ReadabilityExtractionStage', () {
    const extractor = LayeredFullTextExtractor();

    test('extracts a multicolumn article and preserves rich structures',
        () async {
      final result = await extractor.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://example.test/news/source'),
          pageHtml: _fixture('readability_multicolumn_en.html'),
        ),
      );

      expect(
        result,
        isA<ExtractionSuccess>(),
        reason:
            result is ExtractionFailureResult ? result.failure.code.name : null,
      );
      final article = (result as ExtractionSuccess).article;
      expect(article.extractor, 'readability');
      expect(article.title, 'How River keeps reading local-first');
      expect(article.author, 'Alex Example');
      expect(
        article.canonicalUri,
        Uri.parse('https://example.test/stories/local-first-river'),
      );
      expect(article.publishedAt, DateTime.utc(2026, 7, 16, 9, 15));
      expect(article.plainText, contains('trustworthy feed content'));
      expect(article.plainText, contains('deterministic test corpus'));
      expect(article.plainText, isNot(contains('unrelated product')));
      expect(article.plainText, isNot(contains('unrelated stories')));
      expect(article.html, contains('<blockquote>'));
      expect(article.html, contains('<pre>'));
      expect(article.html, contains('<table>'));
      expect(
        article.html,
        contains('https://example.test/news/images/reader.png'),
      );
      expect(article.html, isNot(contains('<script')));
    });

    test('scores Chinese punctuation and excludes comments and sharing',
        () async {
      final result = await extractor.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://cn.example.test/posts/local-first'),
          pageHtml: _fixture('readability_chinese_long.html'),
        ),
      );

      expect(
        result,
        isA<ExtractionSuccess>(),
        reason:
            result is ExtractionFailureResult ? result.failure.code.name : null,
      );
      final article = (result as ExtractionSuccess).article;
      expect(article.extractor, 'readability');
      expect(article.author, 'River 研究组');
      expect(article.plainText, contains('快速不等于草率'));
      expect(article.plainText, contains('Android、iOS 与 Windows'));
      expect(article.plainText, isNot(contains('评论区内容')));
      expect(article.plainText, isNot(contains('分享按钮')));
      expect(article.qualityScore, greaterThanOrEqualTo(0.50));
    });

    test('extracts substantial paragraphs placed directly under body',
        () async {
      final result = await extractor.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://plain.example.test/story'),
          pageHtml: '<html><body>'
              '<p>This direct paragraph contains enough coherent article text, punctuation, and detail to become a candidate even without semantic article markup.</p>'
              '<p>The second paragraph confirms that body-level content is copied as children instead of producing an invalid nested body element.</p>'
              '<p>A final paragraph makes the result trustworthy for the reader and stable for this deterministic regression test.</p>'
              '</body></html>',
        ),
      );

      expect(
        result,
        isA<ExtractionSuccess>(),
        reason:
            result is ExtractionFailureResult ? result.failure.code.name : null,
      );
      final article = (result as ExtractionSuccess).article;
      expect(article.extractor, 'readability');
      expect(article.plainText, contains('body-level content'));
      expect(article.html, isNot(contains('<body')));
    });

    test('falls back from a missing WeChat body to Readability', () async {
      final result = await extractor.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://mp.weixin.qq.com/s/fallback'),
          pageHtml: _fixture('wechat_readability_fallback_synthetic.html'),
        ),
      );

      expect(result, isA<ExtractionSuccess>());
      final success = result as ExtractionSuccess;
      expect(success.article.extractor, 'readability');
      expect(success.article.author, 'River Fallback Lab');
      expect(success.article.imageUrls.single.path, '/wechat-fallback.png');
      expect(success.attempts, hasLength(3));
      expect(success.attempts[1].extractor, 'wechat-static');
      expect(
        success.attempts[1].failureCode,
        ExtractionFailureCode.articleBodyMissing,
      );
      expect(
        success.attempts.last.outcome,
        ExtractionAttemptOutcome.succeeded,
      );
    });

    test('rejects input above the configured character limit', () async {
      const pipeline = ExtractionPipeline(
        stages: <ExtractionStage>[
          ReadabilityExtractionStage(maxInputCharacters: 32),
        ],
      );
      final result = await pipeline.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://example.test/oversized'),
          pageHtml: '<article><p>${'x' * 80}</p></article>',
        ),
      );

      expect(result, isA<ExtractionFailureResult>());
      expect(
        (result as ExtractionFailureResult).failure.code,
        ExtractionFailureCode.responseTooLarge,
      );
    });

    test('rejects a DOM above the configured element limit', () async {
      const pipeline = ExtractionPipeline(
        stages: <ExtractionStage>[
          ReadabilityExtractionStage(maxElements: 3),
        ],
      );
      final result = await pipeline.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://example.test/dom-limit'),
          pageHtml:
              '<article><section><p>one</p><p>two</p></section></article>',
        ),
      );

      expect(result, isA<ExtractionFailureResult>());
      expect(
        (result as ExtractionFailureResult).failure.code,
        ExtractionFailureCode.responseTooLarge,
      );
    });

    test('applies the input limit before parsing a WeChat page', () async {
      const pipeline = ExtractionPipeline(
        stages: <ExtractionStage>[
          WeChatStaticExtractionStage(maxInputCharacters: 32),
        ],
      );
      final result = await pipeline.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://mp.weixin.qq.com/s/oversized'),
          pageHtml: '<div id="js_content">${'x' * 80}</div>',
        ),
      );

      expect(result, isA<ExtractionFailureResult>());
      expect(
        (result as ExtractionFailureResult).failure.code,
        ExtractionFailureCode.responseTooLarge,
      );
    });
  });

  group('ExtractionPipeline', () {
    const extractor = LayeredFullTextExtractor();

    test('stops at trusted feed content', () async {
      final result = await extractor.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://example.test/articles/full'),
          title: 'Full feed fixture',
          feedContentHtml: _fixture('feed_full_synthetic.html'),
          pageHtml: '<html><body>should not be used</body></html>',
        ),
      );

      expect(result, isA<ExtractionSuccess>());
      final success = result as ExtractionSuccess;
      expect(success.article.extractor, 'feed-full-content');
      expect(success.article.title, 'Full feed fixture');
      expect(success.attempts, hasLength(1));
      expect(
        success.attempts.single.outcome,
        ExtractionAttemptOutcome.succeeded,
      );
    });

    test('falls through truncated feed content to the WeChat adapter',
        () async {
      final result = await extractor.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://mp.weixin.qq.com/s/synthetic'),
          feedContentHtml: _fixture('feed_truncated_synthetic.html'),
          pageHtml: _fixture('wechat_synthetic.html'),
        ),
      );

      expect(result, isA<ExtractionSuccess>());
      final success = result as ExtractionSuccess;
      expect(success.article.extractor, 'wechat-static');
      expect(success.article.author, 'River Lab');
      expect(
        success.article.canonicalUri,
        Uri.parse('https://mp.weixin.qq.com/s/canonical-synthetic'),
      );
      expect(
        success.article.publishedAt,
        DateTime.utc(2026, 7, 15, 0, 30),
      );
      expect(success.article.imageUrls.single.host, 'images.example.test');
      expect(success.article.html, contains('[Video content]'));
      expect(success.article.html, isNot(contains('js_pc_qr_code')));
      expect(success.article.html, isNot(contains('<script')));
      expect(success.article.html, isNot(contains('onclick')));
      expect(success.attempts, hasLength(2));
      expect(
        success.attempts.first.failureCode,
        ExtractionFailureCode.truncatedContent,
      );
    });

    test('rejects unsupported source schemes before running stages', () async {
      final result = await extractor.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('file:///private/article.html'),
          pageHtml: '<article>Local content</article>',
        ),
      );

      expect(result, isA<ExtractionFailureResult>());
      final failure = result as ExtractionFailureResult;
      expect(failure.failure.code, ExtractionFailureCode.invalidInput);
      expect(failure.attempts, isEmpty);
    });

    test('classifies unexpected stage failures', () async {
      const pipeline = ExtractionPipeline(
        stages: <ExtractionStage>[_ThrowingStage()],
      );
      final result = await pipeline.extract(
        ExtractionRequest(
          sourceUri: Uri.parse('https://example.test/article'),
          pageHtml: '<article>synthetic input</article>',
        ),
      );

      expect(result, isA<ExtractionFailureResult>());
      final failure = result as ExtractionFailureResult;
      expect(failure.failure.code, ExtractionFailureCode.unexpected);
      expect(failure.failure.retryable, isTrue);
      expect(failure.attempts.single.extractor, 'throwing-test-stage');
    });
  });
}

String _fixture(String name) =>
    File('../../fixtures/html/$name').readAsStringSync();

final class _ThrowingStage implements ExtractionStage {
  const _ThrowingStage();

  @override
  String get id => 'throwing-test-stage';

  @override
  String get version => '1';

  @override
  StageExtractionResult extract(ExtractionRequest request) =>
      throw StateError('synthetic failure');
}
