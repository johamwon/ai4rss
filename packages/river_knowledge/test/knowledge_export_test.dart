import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

final class _Manager implements KnowledgeExportManager {
  KnowledgeExportTarget? upserted;
  KnowledgeExportTarget? deleted;

  @override
  Future<void> enqueueDelete(KnowledgeExportTarget target) async {
    deleted = target;
  }

  @override
  Future<void> enqueueUpsert(KnowledgeExportTarget target) async {
    upserted = target;
  }

  @override
  Future<void> retry(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {}

  @override
  Future<KnowledgeExportState> status(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) async {
    return KnowledgeExportState(
      target: target,
      operation: operation,
      phase: KnowledgeExportPhase.notQueued,
    );
  }

  @override
  Stream<KnowledgeExportState> watch(
    KnowledgeExportTarget target,
    KnowledgeExportOperation operation,
  ) =>
      const Stream<KnowledgeExportState>.empty();
}

void main() {
  test('export service always submits work through the durable manager',
      () async {
    final manager = _Manager();
    final service = KnowledgeExportService(manager);
    final item = _item();

    await service.export(
      item,
      connectorId: 'notion',
      destinationId: 'database-1',
    );
    await service.delete(
      item,
      connectorId: 'notion',
      destinationId: 'database-1',
    );

    expect(manager.upserted?.stableKey, '11:knowledge-16:notion10:database-1');
    expect(manager.deleted?.stableKey, manager.upserted?.stableKey);
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
