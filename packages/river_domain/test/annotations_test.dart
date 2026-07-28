import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  const resolver = ArticleAnchorResolver();
  final createdAt = DateTime.utc(2026, 7, 28);

  test('DOM points restore a selection across multiple text nodes', () {
    final original = DocumentTextSnapshot(<DocumentTextNode>[
      const DocumentTextNode(path: '/article/p[1]', text: 'Opening. '),
      const DocumentTextNode(path: '/article/p[2]', text: 'Important fact.'),
    ]);
    final anchor = ArticleTextAnchor.capture(
      document: original,
      start: 9,
      end: 23,
      contentRevision: 'revision-1',
    );
    final annotation = ArticleAnnotation(
      id: 'annotation-1',
      articleId: 'article-1',
      anchor: anchor,
      color: ArticleAnnotationColor.yellow,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final resolved = resolver.resolve(
      annotation,
      original,
      contentRevision: 'revision-1',
    );

    expect(resolved.kind, ArticleAnchorResolutionKind.domPath);
    expect(
      original.text.substring(resolved.start!, resolved.end!),
      anchor.exact,
    );
    expect(anchor.startDomPath, '/article/p[2]');
  });

  test('text quote context disambiguates repeated text after a reparse', () {
    const repeated = 'shared sentence';
    final originalText = 'First context $repeated first ending. '
        'Target context $repeated target ending.';
    final original = DocumentTextSnapshot.single(originalText);
    final start = originalText.lastIndexOf(repeated);
    final annotation = ArticleAnnotation(
      id: 'annotation-1',
      articleId: 'article-1',
      anchor: ArticleTextAnchor.capture(
        document: original,
        start: start,
        end: start + repeated.length,
        contentRevision: 'revision-1',
      ),
      color: ArticleAnnotationColor.green,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final reparsed = DocumentTextSnapshot.single(
      'New lead. First context $repeated first ending. '
      'Target context $repeated target ending. New tail.',
      path: '/new/body/text()[1]',
    );

    final resolved = resolver.resolve(
      annotation,
      reparsed,
      contentRevision: 'revision-2',
    );

    expect(resolved.kind, ArticleAnchorResolutionKind.textQuote);
    expect(
      reparsed.text.substring(resolved.start!, resolved.end!),
      repeated,
    );
    expect(
      reparsed.text.substring(0, resolved.start!),
      endsWith('Target context '),
    );
  });

  test('a removed or ambiguous quote becomes orphaned without false binding',
      () {
    final original = DocumentTextSnapshot.single('left quote right');
    final annotation = ArticleAnnotation(
      id: 'annotation-1',
      articleId: 'article-1',
      anchor: ArticleTextAnchor.capture(
        document: original,
        start: 5,
        end: 10,
        contentRevision: 'revision-1',
        contextCharacters: 0,
      ),
      color: ArticleAnnotationColor.blue,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final missing = resolver.resolve(
      annotation,
      DocumentTextSnapshot.single('left changed right'),
      contentRevision: 'revision-2',
    );
    final ambiguous = resolver.resolve(
      annotation,
      DocumentTextSnapshot.single(
        'quotequote',
        path: '/reparsed/text()[1]',
      ),
      contentRevision: 'revision-3',
    );

    expect(missing.kind, ArticleAnchorResolutionKind.orphaned);
    expect(ambiguous.kind, ArticleAnchorResolutionKind.orphaned);
    expect(ambiguous.start, isNull);
  });

  test('overlapping repeated quotes never bind by offset alone', () {
    final original = DocumentTextSnapshot.single('left aaa right');
    final annotation = ArticleAnnotation(
      id: 'annotation-1',
      articleId: 'article-1',
      anchor: ArticleTextAnchor.capture(
        document: original,
        start: 5,
        end: 8,
        contentRevision: 'revision-1',
        contextCharacters: 0,
      ),
      color: ArticleAnnotationColor.pink,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final resolved = resolver.resolve(
      annotation,
      DocumentTextSnapshot.single(
        'aaaa',
        path: '/reparsed/text()[1]',
      ),
      contentRevision: 'revision-2',
    );

    expect(resolved.kind, ArticleAnchorResolutionKind.orphaned);
  });
}
