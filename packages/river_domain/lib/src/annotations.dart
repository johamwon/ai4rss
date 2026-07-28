enum ArticleAnnotationColor { yellow, green, blue, pink }

enum ArticleAnchorResolutionKind { domPath, textQuote, orphaned }

final class DocumentTextNode {
  const DocumentTextNode({required this.path, required this.text})
      : assert(path.length > 0);

  final String path;
  final String text;
}

final class DocumentTextSnapshot {
  DocumentTextSnapshot(Iterable<DocumentTextNode> nodes)
      : nodes = List<DocumentTextNode>.unmodifiable(nodes) {
    if (this.nodes.isEmpty) {
      throw ArgumentError.value(nodes, 'nodes', 'must not be empty');
    }
    final paths = <String>{};
    for (final node in this.nodes) {
      if (node.path.isEmpty || !paths.add(node.path)) {
        throw ArgumentError.value(node.path, 'path', 'must be unique');
      }
    }
  }

  factory DocumentTextSnapshot.single(
    String text, {
    String path = '/article/text()[1]',
  }) =>
      DocumentTextSnapshot(<DocumentTextNode>[
        DocumentTextNode(path: path, text: text),
      ]);

  final List<DocumentTextNode> nodes;

  late final String text = nodes.map((node) => node.text).join();

  int? globalOffset(String path, int nodeOffset) {
    var offset = 0;
    for (final node in nodes) {
      if (node.path == path) {
        return nodeOffset >= 0 && nodeOffset <= node.text.length
            ? offset + nodeOffset
            : null;
      }
      offset += node.text.length;
    }
    return null;
  }

  ({String path, int offset}) pointAt(int globalOffset, {bool end = false}) {
    if (globalOffset < 0 || globalOffset > text.length) {
      throw RangeError.range(globalOffset, 0, text.length, 'globalOffset');
    }
    var nodeStart = 0;
    for (var index = 0; index < nodes.length; index += 1) {
      final node = nodes[index];
      final nodeEnd = nodeStart + node.text.length;
      if (globalOffset < nodeEnd ||
          globalOffset == nodeEnd && (end || index == nodes.length - 1)) {
        return (
          path: node.path,
          offset: globalOffset - nodeStart,
        );
      }
      nodeStart = nodeEnd;
    }
    final last = nodes.last;
    return (path: last.path, offset: last.text.length);
  }
}

final class ArticleTextAnchor {
  const ArticleTextAnchor({
    required this.exact,
    required this.prefix,
    required this.suffix,
    required this.originalStart,
    required this.originalEnd,
    required this.contentRevision,
    required this.startDomPath,
    required this.startDomOffset,
    required this.endDomPath,
    required this.endDomOffset,
  });

  factory ArticleTextAnchor.capture({
    required DocumentTextSnapshot document,
    required int start,
    required int end,
    required String contentRevision,
    int contextCharacters = 64,
  }) {
    if (contentRevision.trim().isEmpty || contentRevision.length > 256) {
      throw ArgumentError.value(contentRevision, 'contentRevision');
    }
    if (start < 0 || end <= start || end > document.text.length) {
      throw RangeError('The selected range must be inside the document.');
    }
    if (end - start > 16384) {
      throw RangeError('An annotation cannot exceed 16384 characters.');
    }
    final exact = document.text.substring(start, end);
    if (exact.trim().isEmpty) {
      throw ArgumentError.value(exact, 'selection', 'must contain text');
    }
    final startPoint = document.pointAt(start);
    final endPoint = document.pointAt(end, end: true);
    return ArticleTextAnchor(
      exact: exact,
      prefix: document.text.substring(
        (start - contextCharacters).clamp(0, start),
        start,
      ),
      suffix: document.text.substring(
        end,
        (end + contextCharacters).clamp(end, document.text.length),
      ),
      originalStart: start,
      originalEnd: end,
      contentRevision: contentRevision,
      startDomPath: startPoint.path,
      startDomOffset: startPoint.offset,
      endDomPath: endPoint.path,
      endDomOffset: endPoint.offset,
    );
  }

  final String exact;
  final String prefix;
  final String suffix;
  final int originalStart;
  final int originalEnd;
  final String contentRevision;
  final String startDomPath;
  final int startDomOffset;
  final String endDomPath;
  final int endDomOffset;
}

final class ArticleAnnotation {
  const ArticleAnnotation({
    required this.id,
    required this.articleId,
    required this.anchor,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String articleId;
  final ArticleTextAnchor anchor;
  final ArticleAnnotationColor color;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  ArticleAnnotation copyWith({
    ArticleAnnotationColor? color,
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
  }) =>
      ArticleAnnotation(
        id: id,
        articleId: articleId,
        anchor: anchor,
        color: color ?? this.color,
        note: clearNote ? null : note ?? this.note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

final class ResolvedArticleAnnotation {
  const ResolvedArticleAnnotation({
    required this.annotation,
    required this.kind,
    this.start,
    this.end,
  }) : assert(
          kind == ArticleAnchorResolutionKind.orphaned
              ? start == null && end == null
              : start != null && end != null,
        );

  final ArticleAnnotation annotation;
  final ArticleAnchorResolutionKind kind;
  final int? start;
  final int? end;

  bool get isAttached => kind != ArticleAnchorResolutionKind.orphaned;
}

final class ArticleAnchorResolver {
  const ArticleAnchorResolver();

  ResolvedArticleAnnotation resolve(
    ArticleAnnotation annotation,
    DocumentTextSnapshot document, {
    required String contentRevision,
  }) {
    final anchor = annotation.anchor;
    if (anchor.exact.isEmpty || anchor.exact.length > 16384) {
      return _orphaned(annotation);
    }
    if (contentRevision == anchor.contentRevision &&
        _matches(
          document.text,
          anchor.originalStart,
          anchor.originalEnd,
          anchor.exact,
        )) {
      return _attached(
        annotation,
        ArticleAnchorResolutionKind.domPath,
        anchor.originalStart,
        anchor.originalEnd,
      );
    }

    final domStart = document.globalOffset(
      anchor.startDomPath,
      anchor.startDomOffset,
    );
    final domEnd = document.globalOffset(
      anchor.endDomPath,
      anchor.endDomOffset,
    );
    if (domStart != null &&
        domEnd != null &&
        _matches(document.text, domStart, domEnd, anchor.exact)) {
      return _attached(
        annotation,
        ArticleAnchorResolutionKind.domPath,
        domStart,
        domEnd,
      );
    }

    final candidates = <_AnchorCandidate>[];
    var from = 0;
    while (from <= document.text.length - anchor.exact.length &&
        candidates.length < 256) {
      final start = document.text.indexOf(anchor.exact, from);
      if (start < 0) break;
      final end = start + anchor.exact.length;
      candidates.add(
        _AnchorCandidate(
          start: start,
          end: end,
          contextScore: _contextScore(document.text, anchor, start, end),
          distance: (start - anchor.originalStart).abs(),
        ),
      );
      from = start + 1;
    }
    if (candidates.isEmpty) return _orphaned(annotation);
    if (candidates.length == 256 &&
        document.text.indexOf(anchor.exact, candidates.last.start + 1) >= 0) {
      return _orphaned(annotation);
    }
    candidates.sort((left, right) {
      final context = right.contextScore.compareTo(left.contextScore);
      return context != 0 ? context : left.distance.compareTo(right.distance);
    });
    if (candidates.length > 1 &&
        candidates[0].contextScore == candidates[1].contextScore) {
      return _orphaned(annotation);
    }
    final best = candidates.first;
    return _attached(
      annotation,
      ArticleAnchorResolutionKind.textQuote,
      best.start,
      best.end,
    );
  }
}

final class _AnchorCandidate {
  const _AnchorCandidate({
    required this.start,
    required this.end,
    required this.contextScore,
    required this.distance,
  });

  final int start;
  final int end;
  final int contextScore;
  final int distance;
}

bool _matches(String text, int start, int end, String exact) =>
    start >= 0 &&
    end > start &&
    end <= text.length &&
    text.substring(start, end) == exact;

int _contextScore(
  String text,
  ArticleTextAnchor anchor,
  int start,
  int end,
) {
  var prefixScore = 0;
  while (prefixScore < anchor.prefix.length &&
      start - prefixScore - 1 >= 0 &&
      anchor.prefix[anchor.prefix.length - prefixScore - 1] ==
          text[start - prefixScore - 1]) {
    prefixScore += 1;
  }
  var suffixScore = 0;
  while (suffixScore < anchor.suffix.length &&
      end + suffixScore < text.length &&
      anchor.suffix[suffixScore] == text[end + suffixScore]) {
    suffixScore += 1;
  }
  return prefixScore + suffixScore;
}

ResolvedArticleAnnotation _attached(
  ArticleAnnotation annotation,
  ArticleAnchorResolutionKind kind,
  int start,
  int end,
) =>
    ResolvedArticleAnnotation(
      annotation: annotation,
      kind: kind,
      start: start,
      end: end,
    );

ResolvedArticleAnnotation _orphaned(ArticleAnnotation annotation) =>
    ResolvedArticleAnnotation(
      annotation: annotation,
      kind: ArticleAnchorResolutionKind.orphaned,
    );
