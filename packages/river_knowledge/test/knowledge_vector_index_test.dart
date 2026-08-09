import 'dart:async';

import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:test/test.dart';

void main() {
  test('chunking is deterministic bounded and surrogate safe', () {
    const chunker = KnowledgeChunker(
      maximumCharacters: 128,
      overlapCharacters: 16,
    );
    final item =
        _item('item-chunk', List<String>.filled(80, '段落😀 text.').join(' '));

    final first = chunker.chunk(item);
    final second = chunker.chunk(item);

    expect(first.map((chunk) => chunk.id), second.map((chunk) => chunk.id));
    expect(first, isNotEmpty);
    expect(first.every((chunk) => chunk.text.length <= 128), isTrue);
    expect(first.every((chunk) => !chunk.text.contains('\uFFFD')), isTrue);
    expect(
      first.map((chunk) => chunk.ordinal),
      orderedEquals(List<int>.generate(first.length, (i) => i)),
    );
  });

  test('unchanged item skips provider and exact duplicate writes', () async {
    final provider = _Provider();
    final index = MemoryKnowledgeVectorIndex();
    final service = _service(provider: provider, index: index);
    final item = _item('item-skip', _longText);

    final first = await service.indexItem(item);
    final second = await service.indexItem(item);

    expect(first.skipped, isFalse);
    expect(second.skipped, isTrue);
    expect(provider.calls, first.embeddingCalls);
    expect(index.documents, hasLength(1));
  });

  test('model revision upgrade rebuilds every vector', () async {
    final provider = _Provider();
    final index = MemoryKnowledgeVectorIndex();
    final item = _item('item-upgrade', _longText);
    await _service(provider: provider, index: index).indexItem(item);
    final callsBefore = provider.calls;

    final upgraded = await _service(
      provider: provider,
      index: index,
      revision: 2,
    ).indexItem(item);

    expect(upgraded.skipped, isFalse);
    expect(provider.calls, greaterThan(callsBefore));
    expect(upgraded.document.profileIdentity, contains('@2/'));
  });

  test('content update atomically replaces old chunks', () async {
    final provider = _Provider();
    final index = MemoryKnowledgeVectorIndex();
    final service = _service(provider: provider, index: index);
    final original = _item('item-update', _longText);
    final changed = _item('item-update', 'changed $_longText');
    await service.indexItem(original);

    final result = await service.indexItem(changed);

    expect(result.document.contentHash, changed.contentHash);
    expect(
      index.documents.single.records
          .every((record) => record.chunk.contentHash == changed.contentHash),
      isTrue,
    );
  });

  test('delete removes all vectors for one knowledge item', () async {
    final index = MemoryKnowledgeVectorIndex();
    final service = _service(provider: _Provider(), index: index);
    await service.indexItem(_item('item-delete', _longText));

    await service.deleteItem('item-delete');

    expect(index.documents, isEmpty);
  });

  test('delete waits for an in-flight build and prevents resurrection',
      () async {
    final provider = _Provider(block: true);
    final index = MemoryKnowledgeVectorIndex();
    final service = _service(provider: provider, index: index);
    final item = _item('item-delete-race', _longText);
    final build = service.indexItem(item);
    final deletion = service.deleteItem(item.id);

    expect(
      () => service.indexItem(item),
      throwsA(
        isA<VectorIndexFailure>().having(
          (error) => error.code,
          'code',
          VectorIndexFailureCode.concurrentMutation,
        ),
      ),
    );
    provider.release();
    await build;
    await deletion;

    expect(index.documents, isEmpty);
  });

  test('invalid provider output preserves the previous document', () async {
    final index = MemoryKnowledgeVectorIndex();
    final original = _item('item-invalid', _longText);
    await _service(provider: _Provider(), index: index).indexItem(original);
    final before = index.documents.single;

    await expectLater(
      _service(provider: _Provider(wrongDimensions: true), index: index)
          .indexItem(_item('item-invalid', 'new $_longText')),
      throwsA(isA<VectorIndexFailure>()),
    );
    expect(index.documents.single, same(before));
  });

  test('concurrent duplicate builds coalesce and mutation conflicts', () async {
    final provider = _Provider(block: true);
    final service = _service(
      provider: provider,
      index: MemoryKnowledgeVectorIndex(),
    );
    final item = _item('item-concurrent', _longText);
    final first = service.indexItem(item);
    final duplicate = service.indexItem(item);
    expect(duplicate, same(first));
    expect(
      () => service.indexItem(_item('item-concurrent', 'mutated $_longText')),
      throwsA(
        isA<VectorIndexFailure>().having(
          (error) => error.code,
          'code',
          VectorIndexFailureCode.concurrentMutation,
        ),
      ),
    );
    provider.release();
    expect(await duplicate, same(await first));
  });

  test('corrupt stored document is rebuilt from source', () async {
    final validIndex = MemoryKnowledgeVectorIndex();
    final item = _item('item-corrupt', _longText);
    final valid = await _service(provider: _Provider(), index: validIndex)
        .indexItem(item);
    final corrupt = _CorruptIndex(valid.document);

    final result =
        await _service(provider: _Provider(), index: corrupt).indexItem(item);

    expect(result.recoveredCorruption, isTrue);
    expect(corrupt.replacements, 1);
  });

  test('provider batches are independently bounded', () async {
    final provider = _Provider();
    final result = await KnowledgeVectorIndexer(
      profile: _profile(),
      provider: provider,
      index: MemoryKnowledgeVectorIndex(),
      chunker: const KnowledgeChunker(
        maximumCharacters: 128,
        overlapCharacters: 8,
      ),
      maximumBatchSize: 2,
      clock: const _Clock(),
    ).indexItem(
      _item(
        'item-batch',
        List<String>.filled(120, 'bounded vector text.').join(' '),
      ),
    );

    expect(provider.batchSizes.every((size) => size <= 2), isTrue);
    expect(result.embeddingCalls, provider.batchSizes.length);
    expect(result.embeddingCalls, greaterThan(1));
  });
}

const _longText =
    'River keeps knowledge local. Paragraph one contains evidence.\n\n'
    'Paragraph two adds enough deterministic text for vector indexing and rebuild tests. '
    'The content is synthetic and contains no private user information.';

KnowledgeVectorIndexer _service({
  required _Provider provider,
  required KnowledgeVectorIndex index,
  int revision = 1,
}) =>
    KnowledgeVectorIndexer(
      profile: _profile(revision: revision),
      provider: provider,
      index: index,
      chunker: const KnowledgeChunker(
        maximumCharacters: 128,
        overlapCharacters: 16,
      ),
      maximumBatchSize: 2,
      clock: const _Clock(),
    );

EmbeddingProfile _profile({int revision = 1}) => EmbeddingProfile(
      modelId: 'river-local-mini',
      revision: revision,
      dimensions: 4,
      location: EmbeddingExecutionLocation.local,
    );

KnowledgeItem _item(String id, String markdown) {
  final title = 'Knowledge $id';
  final html = '<p>$markdown</p>';
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'source-$id',
      originalUrl: Uri.parse('https://example.test/$id'),
      sourceTitle: 'River',
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: html,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: markdown,
      sanitizedHtml: html,
    ),
    savedAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );
}

final class _Provider implements KnowledgeEmbeddingProvider {
  _Provider({this.wrongDimensions = false, this.block = false});

  final bool wrongDimensions;
  final bool block;
  final Completer<void> _release = Completer<void>();
  final List<int> batchSizes = <int>[];
  int calls = 0;

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<List<EmbeddingVector>> embed({
    required EmbeddingProfile profile,
    required List<KnowledgeChunk> chunks,
  }) async {
    calls += 1;
    batchSizes.add(chunks.length);
    if (block) await _release.future;
    return chunks
        .map(
          (chunk) => EmbeddingVector(
            chunkId: chunk.id,
            values: List<double>.generate(
              wrongDimensions ? profile.dimensions - 1 : profile.dimensions,
              (index) => (chunk.ordinal + index + 1) / 10,
            ),
          ),
        )
        .toList(growable: false);
  }
}

final class _CorruptIndex implements KnowledgeVectorIndex {
  _CorruptIndex(this.document);

  KnowledgeVectorDocument document;
  int replacements = 0;

  @override
  Future<void> clearProfile(String profileIdentity) async {}

  @override
  Future<void> deleteDocument(String itemId) async {}

  @override
  Future<KnowledgeVectorDocument?> readDocument(String itemId) async {
    return KnowledgeVectorDocument(
      itemId: document.itemId,
      contentHash: document.contentHash,
      profileIdentity: document.profileIdentity,
      chunkerVersion: document.chunkerVersion,
      records: document.records
          .map(
            (record) => KnowledgeVectorRecord(
              chunk: record.chunk,
              profileIdentity: record.profileIdentity,
              vector: const <double>[1],
            ),
          )
          .toList(),
      indexedAt: document.indexedAt,
    );
  }

  @override
  Future<void> replaceDocument(KnowledgeVectorDocument document) async {
    this.document = document;
    replacements += 1;
  }
}

final class _Clock implements KnowledgeIndexClock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}
