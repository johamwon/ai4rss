import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

enum ReaderSemanticKind {
  heading1,
  heading2,
  heading3,
  heading4,
  strong,
  emphasis,
  quote,
  code,
  link,
  listItem,
  caption,
  table,
}

final class ReaderSemanticRange {
  const ReaderSemanticRange({
    required this.start,
    required this.end,
    required this.kind,
  });

  final int start;
  final int end;
  final ReaderSemanticKind kind;
}

final class ReaderSemanticDocument {
  const ReaderSemanticDocument({
    required this.text,
    required this.ranges,
  });

  final String text;
  final List<ReaderSemanticRange> ranges;
}

/// Maps safe HTML semantics onto the canonical plain-text offsets used by
/// annotations, TTS and reading progress.
///
/// Publisher CSS and class names are intentionally ignored. The sanitizer has
/// already removed executable content and unsafe attributes; this mapper only
/// restores structural emphasis without changing [plainText].
ReaderSemanticDocument parseReaderSemanticDocument({
  required String sanitizedHtml,
  required String plainText,
}) {
  if (sanitizedHtml.trim().isEmpty || plainText.isEmpty) {
    return ReaderSemanticDocument(
      text: plainText,
      ranges: const <ReaderSemanticRange>[],
    );
  }
  final fragment = html_parser.parseFragment(sanitizedHtml);
  final ranges = <ReaderSemanticRange>[];
  var cursor = 0;

  void visit(Node node, List<ReaderSemanticKind> inherited) {
    final kinds = node is Element
        ? <ReaderSemanticKind>[
            ...inherited,
            ..._semanticKinds(node.localName),
          ]
        : inherited;
    if (node is Text) {
      final candidate = node.data.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (candidate.isEmpty) return;
      var start = plainText.indexOf(candidate, cursor);
      if (start < 0) start = plainText.indexOf(candidate);
      if (start < 0) return;
      final end = start + candidate.length;
      for (final kind in kinds.toSet()) {
        ranges.add(ReaderSemanticRange(start: start, end: end, kind: kind));
      }
      cursor = end;
      return;
    }
    for (final child in node.nodes) {
      visit(child, kinds);
    }
  }

  visit(fragment, const <ReaderSemanticKind>[]);
  ranges.sort((left, right) {
    final start = left.start.compareTo(right.start);
    if (start != 0) return start;
    final end = left.end.compareTo(right.end);
    if (end != 0) return end;
    return left.kind.index.compareTo(right.kind.index);
  });
  return ReaderSemanticDocument(
    text: plainText,
    ranges: List<ReaderSemanticRange>.unmodifiable(ranges),
  );
}

Iterable<ReaderSemanticKind> _semanticKinds(String? tag) => switch (tag) {
      'h1' => const <ReaderSemanticKind>[ReaderSemanticKind.heading1],
      'h2' => const <ReaderSemanticKind>[ReaderSemanticKind.heading2],
      'h3' => const <ReaderSemanticKind>[ReaderSemanticKind.heading3],
      'h4' || 'h5' || 'h6' => const <ReaderSemanticKind>[
          ReaderSemanticKind.heading4,
        ],
      'strong' || 'b' => const <ReaderSemanticKind>[ReaderSemanticKind.strong],
      'em' || 'i' => const <ReaderSemanticKind>[ReaderSemanticKind.emphasis],
      'blockquote' => const <ReaderSemanticKind>[ReaderSemanticKind.quote],
      'pre' || 'code' => const <ReaderSemanticKind>[ReaderSemanticKind.code],
      'a' => const <ReaderSemanticKind>[ReaderSemanticKind.link],
      'li' => const <ReaderSemanticKind>[ReaderSemanticKind.listItem],
      'figcaption' => const <ReaderSemanticKind>[ReaderSemanticKind.caption],
      'table' || 'th' || 'td' => const <ReaderSemanticKind>[
          ReaderSemanticKind.table,
        ],
      _ => const <ReaderSemanticKind>[],
    };
