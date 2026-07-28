import 'dart:convert';

import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  const renderer = KnowledgeMarkdownRenderer();

  test('renders canonical front matter and every knowledge section', () {
    final item = _item(
      markdown: '## Original\r\n\r\nBody\r\n',
      summary: const ArticleSummary(
        oneLine: 'A concise summary.',
        keyPoints: <String>['First insight', 'Second\nline'],
        language: 'en',
        model: 'test',
        promptVersion: 'v1',
      ),
      excerpts: <KnowledgeExcerpt>[
        KnowledgeExcerpt(
          quote: 'Line one\n\nLine *two*',
          note: 'Remember [this]',
          annotationId: 'annotation-1',
        ),
      ],
      notes: const <String>['Standalone\nnote'],
      tags: const <String>['rss', 'ai', 'rss'],
      topics: const <String>['Reading'],
      entities: const <String>['River'],
    );

    final document = renderer.render(item);

    expect(
      document.contents,
      '''---
river_schema: 1
river_id: "knowledge-1"
title: "River Weekly"
source: "Example Source"
source_kind: "article"
source_id: "article-1"
original_url: "https://example.test/articles/1"
author: "Alice"
published_at: "2026-07-27T08:30:00.000Z"
saved_at: "2026-07-28T01:00:00.000Z"
updated_at: "2026-07-28T02:00:00.000Z"
content_hash: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
tags: ["ai","rss"]
topics: ["Reading"]
entities: ["River"]
---

# River Weekly

> Source: [Example Source](<https://example.test/articles/1>)
> Author: Alice
> Published: 2026-07-27T08:30:00.000Z

## Summary

A concise summary.
- First insight
- Second
   line

## Article

## Original

Body

## Highlights

### Highlight 1

> Line one
>
> Line \\*two\\*

**Note:** Remember \\[this\\]

## Notes

1. Standalone
   note
''',
    );
    expect(document.contents.endsWith('\n'), isTrue);
    expect(document.contents, isNot(contains('\r')));
  });

  test('quotes front matter scalars and normalizes control characters', () {
    final item = _item(
      title: 'A "title"\n---',
      sourceTitle: 'Source:\nmalicious',
      markdown: 'Body\u0000\r\ntext',
      tags: const <String>['x: y', '---'],
    );

    final document = renderer.render(item);
    final frontMatter = document.contents.split('---\n')[1];

    expect(frontMatter, contains('title: "A \\"title\\" ---"\n'));
    expect(frontMatter, contains('source: "Source: malicious"\n'));
    expect(frontMatter, contains('tags: ["---","x: y"]\n'));
    expect(document.contents, isNot(contains('\u0000')));
    expect(document.contents, isNot(contains('\r')));
  });

  test('metadata sets have byte-stable ordering', () {
    final first = renderer.render(
      _item(
        tags: const <String>['rss', 'ai'],
        topics: const <String>['z', 'a'],
      ),
    );
    final second = renderer.render(
      _item(
        tags: const <String>['ai', 'rss', 'ai'],
        topics: const <String>['a', 'z'],
      ),
    );

    expect(second.contents, first.contents);
    expect(second.fileName, first.fileName);
  });

  test('safe file names are bounded and collision resistant', () {
    final longTitle = '${'知识：RSS/AI?*'.padRight(100, '很')}...   ';
    final first = renderer.render(_item(title: longTitle));
    final second = renderer.render(_item(id: 'knowledge-2', title: longTitle));

    expect(first.fileName, endsWith('.md'));
    expect(
      first.fileName,
      isNot(matches(RegExp(r'[<>:"/\\|?*\u0000-\u001F]'))),
    );
    expect(utf8.encode(first.fileName).length, lessThanOrEqualTo(200));
    expect(second.fileName, isNot(first.fileName));
  });
}

KnowledgeItem _item({
  String id = 'knowledge-1',
  String title = 'River Weekly',
  String sourceTitle = 'Example Source',
  String markdown = 'Body',
  ArticleSummary? summary,
  Iterable<KnowledgeExcerpt> excerpts = const <KnowledgeExcerpt>[],
  Iterable<String> notes = const <String>[],
  Iterable<String> tags = const <String>[],
  Iterable<String> topics = const <String>[],
  Iterable<String> entities = const <String>[],
}) {
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-1',
      originalUrl: Uri.parse('https://example.test/articles/1'),
      sourceTitle: sourceTitle,
      author: 'Alice',
      publishedAt: DateTime.utc(2026, 7, 27, 8, 30),
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: '<p>Body</p>',
    summary: summary,
    excerpts: excerpts,
    notes: notes,
    tags: tags,
    topics: topics,
    entities: entities,
    contentHash:
        'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    savedAt: DateTime.utc(2026, 7, 28, 1),
    updatedAt: DateTime.utc(2026, 7, 28, 2),
  );
}
