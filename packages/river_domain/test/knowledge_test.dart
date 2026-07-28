import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('knowledge source key is stable and rejects unsafe URLs', () {
    final source = KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-1',
      originalUrl: Uri.parse('https://example.test/article'),
      sourceTitle: 'River Weekly',
    );

    expect(source.stableKey, 'article:article-1');
    expect(
      () => KnowledgeSourceReference(
        kind: KnowledgeSourceKind.webClip,
        sourceId: 'clip-1',
        originalUrl: Uri.parse('file:///private/article'),
        sourceTitle: 'Unsafe',
      ),
      throwsArgumentError,
    );
  });

  test('knowledge items normalize bounded metadata and validate revisions', () {
    final item = _item(
      tags: const <String>[' AI ', 'AI', 'RSS'],
    );

    expect(item.tags, <String>['AI', 'RSS']);
    expect(item.withId('stable-id').source, same(item.source));
    expect(
      () => _item(
        savedAt: DateTime.utc(2026, 7, 29),
        updatedAt: DateTime.utc(2026, 7, 28),
      ),
      throwsArgumentError,
    );
  });

  test('external mapping key is destination-scoped', () {
    final mapping = KnowledgeExternalMapping(
      knowledgeItemId: 'knowledge-1',
      connectorId: 'notion',
      destinationId: 'database-1',
      externalObjectId: 'page-1',
      externalUrl: Uri.parse('https://notion.so/page-1'),
      exportedContentHash: _hash('b'),
      createdAt: DateTime.utc(2026, 7, 28),
      updatedAt: DateTime.utc(2026, 7, 28),
    );

    expect(mapping.stableKey, 'knowledge-1:notion:database-1');
  });

  test('connector requests validate public identity and external URLs', () {
    final item = _item();
    final request = KnowledgeConnectorCreateRequest(
      item: item,
      destinationId: 'database-1',
      idempotencyKey: 'stable-create-key',
    );
    final target = KnowledgeExportTarget(
      knowledgeItemId: item.id,
      connectorId: 'notion',
      destinationId: 'database-1',
    );

    expect(request.item, same(item));
    expect(
      target.stableKey,
      '11:knowledge-16:notion10:database-1',
    );
    expect(
      () => KnowledgeConnectorObject(
        externalObjectId: 'page-1',
        externalUrl: Uri.parse('file:///private/page-1'),
      ),
      throwsArgumentError,
    );
    expect(
      () => KnowledgeConnectorStatusRequest(
        destinationId: '',
        externalObjectId: 'page-1',
      ),
      throwsArgumentError,
    );
  });
}

KnowledgeItem _item({
  Iterable<String> tags = const <String>[],
  DateTime? savedAt,
  DateTime? updatedAt,
}) {
  final saved = savedAt ?? DateTime.utc(2026, 7, 28);
  return KnowledgeItem(
    id: 'knowledge-1',
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-1',
      originalUrl: Uri.parse('https://example.test/article'),
      sourceTitle: 'River Weekly',
    ),
    title: 'Durable knowledge',
    markdown: '# Durable knowledge',
    sanitizedHtml: '<h1>Durable knowledge</h1>',
    contentHash: _hash('a'),
    savedAt: saved,
    updatedAt: updatedAt ?? saved,
    tags: tags,
  );
}

String _hash(String character) =>
    'sha256:${List<String>.filled(64, character).join()}';
