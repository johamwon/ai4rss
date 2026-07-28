import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

final class _Connector implements KnowledgeConnector {
  @override
  String get id => 'test-notion';

  @override
  Future<Uri> upsert(KnowledgeItem item) async {
    return Uri.parse('https://notion.test/${item.id}');
  }
}

void main() {
  test('connector idempotency key is stable per knowledge object', () {
    final service = KnowledgeExportService(_Connector());
    final item = _item();

    expect(service.idempotencyKey(item), 'test-notion:knowledge-1');
  });

  test('content hash is canonical for metadata sets and changes with notes',
      () {
    const hasher = KnowledgeContentHasher();
    final first = hasher.hash(
      title: 'Knowledge',
      markdown: '# Knowledge',
      sanitizedHtml: '<h1>Knowledge</h1>',
      tags: const <String>['rss', 'ai'],
      notes: const <String>['First note'],
    );
    final reordered = hasher.hash(
      title: 'Knowledge',
      markdown: '# Knowledge',
      sanitizedHtml: '<h1>Knowledge</h1>',
      tags: const <String>['ai', 'rss', 'ai'],
      notes: const <String>['First note'],
    );
    final changed = hasher.hash(
      title: 'Knowledge',
      markdown: '# Knowledge',
      sanitizedHtml: '<h1>Knowledge</h1>',
      tags: const <String>['ai', 'rss'],
      notes: const <String>['Changed note'],
    );

    expect(first, matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
    expect(reordered, first);
    expect(changed, isNot(first));
  });
}

KnowledgeItem _item() {
  const hasher = KnowledgeContentHasher();
  const title = 'Knowledge';
  const markdown = '# Knowledge';
  const html = '<h1>Knowledge</h1>';
  return KnowledgeItem(
    id: 'knowledge-1',
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-1',
      originalUrl: Uri.parse('https://example.test/article-1'),
      sourceTitle: 'River Weekly',
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: html,
    contentHash: hasher.hash(
      title: title,
      markdown: markdown,
      sanitizedHtml: html,
    ),
    savedAt: DateTime.utc(2026, 7, 28),
    updatedAt: DateTime.utc(2026, 7, 28),
  );
}
