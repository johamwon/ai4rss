import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

final class KnowledgeMarkdownDocument {
  const KnowledgeMarkdownDocument({
    required this.fileName,
    required this.contents,
  });

  final String fileName;
  final String contents;
}

/// Renders the connector-independent, portable Markdown representation of a
/// knowledge item.
///
/// Version 1 intentionally uses a fixed English document structure and YAML
/// keys. Connectors must not localize or reorder this representation because
/// its byte stability is used for exports, updates, and test fixtures.
final class KnowledgeMarkdownRenderer {
  const KnowledgeMarkdownRenderer();

  static const int schemaVersion = 1;

  KnowledgeMarkdownDocument render(KnowledgeItem item) {
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('river_schema: $schemaVersion')
      ..writeln('river_id: ${_yamlString(item.id)}')
      ..writeln('title: ${_yamlString(item.title)}')
      ..writeln('source: ${_yamlString(item.source.sourceTitle)}')
      ..writeln('source_kind: ${_yamlString(item.source.kind.name)}')
      ..writeln('source_id: ${_yamlString(item.source.sourceId)}')
      ..writeln(
        'original_url: ${_yamlString(item.source.originalUrl.toString())}',
      );
    final author = item.source.author?.trim();
    if (author != null && author.isNotEmpty) {
      buffer.writeln('author: ${_yamlString(author)}');
    }
    final publishedAt = item.source.publishedAt;
    if (publishedAt != null) {
      buffer.writeln('published_at: ${_yamlString(_date(publishedAt))}');
    }
    buffer
      ..writeln('saved_at: ${_yamlString(_date(item.savedAt))}')
      ..writeln('updated_at: ${_yamlString(_date(item.updatedAt))}')
      ..writeln('content_hash: ${_yamlString(item.contentHash)}')
      ..writeln('tags: ${_yamlStringList(item.tags)}')
      ..writeln('topics: ${_yamlStringList(item.topics)}')
      ..writeln('entities: ${_yamlStringList(item.entities)}')
      ..writeln('---')
      ..writeln()
      ..writeln('# ${_markdownInline(item.title)}')
      ..writeln()
      ..writeln(
        '> Source: [${_markdownInline(item.source.sourceTitle)}]'
        '(<${item.source.originalUrl}>)',
      );
    if (author != null && author.isNotEmpty) {
      buffer.writeln('> Author: ${_markdownInline(author)}');
    }
    if (publishedAt != null) {
      buffer.writeln('> Published: ${_date(publishedAt)}');
    }

    final summary = item.summary;
    if (summary != null) {
      buffer
        ..writeln()
        ..writeln('## Summary')
        ..writeln()
        ..writeln(_markdownParagraph(summary.oneLine));
      for (final point in summary.keyPoints) {
        buffer.writeln('- ${_markdownListItem(point)}');
      }
    }

    buffer
      ..writeln()
      ..writeln('## Article')
      ..writeln();
    final article = _normalizeBlock(item.markdown);
    if (article.isNotEmpty) {
      buffer.writeln(article);
    }

    if (item.excerpts.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Highlights');
      for (var index = 0; index < item.excerpts.length; index += 1) {
        final excerpt = item.excerpts[index];
        buffer
          ..writeln()
          ..writeln('### Highlight ${index + 1}')
          ..writeln()
          ..writeln(_markdownQuote(excerpt.quote));
        final note = excerpt.note?.trim();
        if (note != null && note.isNotEmpty) {
          buffer
            ..writeln()
            ..writeln('**Note:** ${_markdownParagraph(note)}');
        }
      }
    }

    if (item.notes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Notes')
        ..writeln();
      for (var index = 0; index < item.notes.length; index += 1) {
        buffer.writeln('${index + 1}. ${_markdownListItem(item.notes[index])}');
      }
    }

    return KnowledgeMarkdownDocument(
      fileName: _fileName(item),
      contents: '${buffer.toString().trimRight()}\n',
    );
  }
}

String _date(DateTime value) => value.toUtc().toIso8601String();

String _yamlString(String value) => jsonEncode(_normalizeInline(value));

String _yamlStringList(Iterable<String> values) {
  final canonical = values.map(_normalizeInline).toSet().toList()..sort();
  return jsonEncode(canonical);
}

String _normalizeInline(String value) => value
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _normalizeBlock(String value) => value
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
    .trim();

String _markdownInline(String value) {
  final normalized = _normalizeInline(value);
  final buffer = StringBuffer();
  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    if (r'\`*_[]<>'.contains(character)) {
      buffer.write(r'\');
    }
    buffer.write(character);
  }
  return buffer.toString();
}

String _markdownParagraph(String value) {
  return _normalizeBlock(value).split('\n').map(_markdownInline).join('  \n');
}

String _markdownListItem(String value) {
  return _normalizeBlock(value).split('\n').map(_markdownInline).join('\n   ');
}

String _markdownQuote(String value) {
  return _normalizeBlock(value)
      .split('\n')
      .map((line) => line.isEmpty ? '>' : '> ${_markdownInline(line)}')
      .join('\n');
}

String _fileName(KnowledgeItem item) {
  final title = _normalizeInline(item.title)
      .replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001F]'), '-')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  final suffix =
      sha256.convert(utf8.encode(item.id)).toString().substring(0, 12);
  final safeTitle = _truncateUtf8(title.isEmpty ? 'Knowledge' : title, 180);
  return '$safeTitle--$suffix.md';
}

String _truncateUtf8(String value, int maxBytes) {
  final buffer = StringBuffer();
  var bytes = 0;
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    final length = utf8.encode(character).length;
    if (bytes + length > maxBytes) {
      break;
    }
    buffer.write(character);
    bytes += length;
  }
  return buffer.toString();
}
