import 'package:river_domain/river_domain.dart';
import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('fake connector satisfies create update delete and status contract',
      () async {
    final connector = FakeKnowledgeConnector();
    final item = _item();

    final connection = await connector.testConnection();
    final created = await connector.create(
      KnowledgeConnectorCreateRequest(
        item: item,
        destinationId: 'destination-1',
        idempotencyKey: 'create-1',
      ),
    );
    final available = await connector.status(
      KnowledgeConnectorStatusRequest(
        destinationId: 'destination-1',
        externalObjectId: created.externalObjectId,
      ),
    );
    final updated = await connector.update(
      KnowledgeConnectorUpdateRequest(
        item: item,
        destinationId: 'destination-1',
        externalObjectId: created.externalObjectId,
        idempotencyKey: 'update-1',
      ),
    );
    await connector.delete(
      KnowledgeConnectorDeleteRequest(
        knowledgeItemId: item.id,
        destinationId: 'destination-1',
        externalObjectId: updated.externalObjectId,
        idempotencyKey: 'delete-1',
      ),
    );
    final missing = await connector.status(
      KnowledgeConnectorStatusRequest(
        destinationId: 'destination-1',
        externalObjectId: created.externalObjectId,
      ),
    );

    expect(connection.phase, KnowledgeConnectorConnectionPhase.connected);
    expect(available.phase, KnowledgeConnectorObjectPhase.available);
    expect(updated.externalObjectId, created.externalObjectId);
    expect(missing.phase, KnowledgeConnectorObjectPhase.missing);
    expect(connector.idempotencyKeys, <String>['create-1', 'update-1']);
  });
}

KnowledgeItem _item() {
  return KnowledgeItem(
    id: 'knowledge-1',
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-1',
      originalUrl: Uri.parse('https://example.test/article-1'),
      sourceTitle: 'River Weekly',
    ),
    title: 'Knowledge',
    markdown: '# Knowledge',
    sanitizedHtml: '<h1>Knowledge</h1>',
    contentHash:
        'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    savedAt: DateTime.utc(2026, 7, 28),
    updatedAt: DateTime.utc(2026, 7, 28),
  );
}
