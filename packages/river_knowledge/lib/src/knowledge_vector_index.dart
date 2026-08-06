import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

enum EmbeddingExecutionLocation { local, managedCloud }

final class EmbeddingProfile {
  EmbeddingProfile({
    required this.modelId,
    required this.revision,
    required this.dimensions,
    required this.location,
  }) {
    if (!_safeId.hasMatch(modelId) ||
        revision < 1 ||
        dimensions < 2 ||
        dimensions > 4096) {
      throw ArgumentError('Invalid embedding profile');
    }
  }

  final String modelId;
  final int revision;
  final int dimensions;
  final EmbeddingExecutionLocation location;

  String get identity => '$modelId@$revision/$dimensions/${location.name}';
}

final class KnowledgeChunk {
  KnowledgeChunk({
    required this.id,
    required this.itemId,
    required this.contentHash,
    required this.ordinal,
    required this.text,
    required this.sourceStart,
    required this.sourceEnd,
    required this.chunkerVersion,
  }) {
    if (!_hash.hasMatch(id) ||
        itemId.isEmpty ||
        !_contentHash.hasMatch(contentHash) ||
        ordinal < 0 ||
        text.trim().isEmpty ||
        sourceStart < 0 ||
        sourceEnd <= sourceStart ||
        chunkerVersion < 1) {
      throw ArgumentError('Invalid knowledge chunk');
    }
  }

  final String id;
  final String itemId;
  final String contentHash;
  final int ordinal;
  final String text;
  final int sourceStart;
  final int sourceEnd;
  final int chunkerVersion;
}

final class KnowledgeChunker {
  const KnowledgeChunker({
    this.version = 1,
    this.maximumCharacters = 800,
    this.overlapCharacters = 80,
    this.maximumChunks = 2048,
  })  : assert(version > 0),
        assert(maximumCharacters >= 128 && maximumCharacters <= 8000),
        assert(overlapCharacters >= 0),
        assert(overlapCharacters < maximumCharacters ~/ 2),
        assert(maximumChunks >= 1 && maximumChunks <= 10000);

  final int version;
  final int maximumCharacters;
  final int overlapCharacters;
  final int maximumChunks;

  List<KnowledgeChunk> chunk(KnowledgeItem item) {
    final source = item.markdown;
    if (source.length > 5 * 1024 * 1024) {
      throw const VectorIndexFailure(VectorIndexFailureCode.inputTooLarge);
    }
    final chunks = <KnowledgeChunk>[];
    var start = _skipWhitespace(source, 0);
    while (start < source.length) {
      var end = (start + maximumCharacters).clamp(0, source.length);
      end = _safeBoundary(source, end);
      if (end < source.length) {
        final preferred = _preferredBreak(source, start, end);
        if (preferred > start + maximumCharacters ~/ 2) end = preferred;
      }
      var textStart = start;
      while (textStart < end && _isWhitespace(source.codeUnitAt(textStart))) {
        textStart += 1;
      }
      var textEnd = end;
      while (textEnd > textStart &&
          _isWhitespace(source.codeUnitAt(textEnd - 1))) {
        textEnd -= 1;
      }
      if (textEnd > textStart) {
        final text = source.substring(textStart, textEnd);
        final ordinal = chunks.length;
        final id = sha256
            .convert(
              utf8.encode(
                'river.knowledge-chunk.v$version\n${item.id}\n'
                '${item.contentHash}\n$ordinal\n$textStart\n$textEnd\n$text',
              ),
            )
            .toString();
        chunks.add(
          KnowledgeChunk(
            id: id,
            itemId: item.id,
            contentHash: item.contentHash,
            ordinal: ordinal,
            text: text,
            sourceStart: textStart,
            sourceEnd: textEnd,
            chunkerVersion: version,
          ),
        );
        if (chunks.length > maximumChunks) {
          throw const VectorIndexFailure(VectorIndexFailureCode.inputTooLarge);
        }
      }
      if (end >= source.length) break;
      final next = _safeBoundary(
        source,
        (end - overlapCharacters).clamp(start + 1, end),
      );
      start = _skipWhitespace(source, next <= start ? end : next);
    }
    return List<KnowledgeChunk>.unmodifiable(chunks);
  }
}

final class EmbeddingVector {
  EmbeddingVector({required this.chunkId, required Iterable<double> values})
      : values = List<double>.unmodifiable(values) {
    if (!_hash.hasMatch(chunkId) ||
        this.values.isEmpty ||
        this.values.any((value) => !value.isFinite)) {
      throw ArgumentError('Invalid embedding vector');
    }
  }

  final String chunkId;
  final List<double> values;
}

abstract interface class KnowledgeEmbeddingProvider {
  Future<List<EmbeddingVector>> embed({
    required EmbeddingProfile profile,
    required List<KnowledgeChunk> chunks,
  });
}

final class KnowledgeVectorRecord {
  KnowledgeVectorRecord({
    required this.chunk,
    required this.profileIdentity,
    required Iterable<double> vector,
  }) : vector = List<double>.unmodifiable(vector);

  final KnowledgeChunk chunk;
  final String profileIdentity;
  final List<double> vector;
}

final class KnowledgeVectorDocument {
  KnowledgeVectorDocument({
    required this.itemId,
    required this.contentHash,
    required this.profileIdentity,
    required this.chunkerVersion,
    required Iterable<KnowledgeVectorRecord> records,
    required this.indexedAt,
  }) : records = List<KnowledgeVectorRecord>.unmodifiable(records);

  final String itemId;
  final String contentHash;
  final String profileIdentity;
  final int chunkerVersion;
  final List<KnowledgeVectorRecord> records;
  final DateTime indexedAt;
}

abstract interface class KnowledgeVectorIndex {
  Future<KnowledgeVectorDocument?> readDocument(String itemId);
  Future<void> replaceDocument(KnowledgeVectorDocument document);
  Future<void> deleteDocument(String itemId);
  Future<void> clearProfile(String profileIdentity);
}

final class MemoryKnowledgeVectorIndex implements KnowledgeVectorIndex {
  final Map<String, KnowledgeVectorDocument> _documents =
      <String, KnowledgeVectorDocument>{};

  List<KnowledgeVectorDocument> get documents =>
      List<KnowledgeVectorDocument>.unmodifiable(_documents.values);

  @override
  Future<void> clearProfile(String profileIdentity) async {
    _documents.removeWhere(
      (_, document) => document.profileIdentity == profileIdentity,
    );
  }

  @override
  Future<void> deleteDocument(String itemId) async => _documents.remove(itemId);

  @override
  Future<KnowledgeVectorDocument?> readDocument(String itemId) async =>
      _documents[itemId];

  @override
  Future<void> replaceDocument(KnowledgeVectorDocument document) async {
    _documents[document.itemId] = document;
  }
}

enum VectorIndexFailureCode {
  inputTooLarge,
  invalidProviderOutput,
  corruptIndex,
  concurrentMutation,
}

final class VectorIndexFailure implements Exception {
  const VectorIndexFailure(this.code);

  final VectorIndexFailureCode code;

  @override
  String toString() => 'VectorIndexFailure(${code.name})';
}

final class KnowledgeIndexBuildResult {
  const KnowledgeIndexBuildResult({
    required this.document,
    required this.skipped,
    required this.recoveredCorruption,
    required this.embeddingCalls,
  });

  final KnowledgeVectorDocument document;
  final bool skipped;
  final bool recoveredCorruption;
  final int embeddingCalls;
}

abstract interface class KnowledgeIndexClock {
  DateTime now();
}

final class SystemKnowledgeIndexClock implements KnowledgeIndexClock {
  const SystemKnowledgeIndexClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final class KnowledgeVectorIndexer {
  KnowledgeVectorIndexer({
    required this.profile,
    required KnowledgeEmbeddingProvider provider,
    required KnowledgeVectorIndex index,
    this.chunker = const KnowledgeChunker(),
    KnowledgeIndexClock clock = const SystemKnowledgeIndexClock(),
    this.maximumBatchSize = 32,
  })  : _provider = provider,
        _index = index,
        _clock = clock {
    if (maximumBatchSize < 1 || maximumBatchSize > 128) {
      throw ArgumentError.value(maximumBatchSize, 'maximumBatchSize');
    }
  }

  final EmbeddingProfile profile;
  final KnowledgeEmbeddingProvider _provider;
  final KnowledgeVectorIndex _index;
  final KnowledgeChunker chunker;
  final KnowledgeIndexClock _clock;
  final int maximumBatchSize;
  final Map<String, _InFlightIndexBuild> _inFlight =
      <String, _InFlightIndexBuild>{};
  final Set<String> _deleting = <String>{};

  Future<KnowledgeIndexBuildResult> indexItem(KnowledgeItem item) {
    if (_deleting.contains(item.id)) {
      throw const VectorIndexFailure(
        VectorIndexFailureCode.concurrentMutation,
      );
    }
    final fingerprint =
        '${item.contentHash}|${profile.identity}|${chunker.version}';
    final current = _inFlight[item.id];
    if (current != null) {
      if (current.fingerprint != fingerprint) {
        throw const VectorIndexFailure(
          VectorIndexFailureCode.concurrentMutation,
        );
      }
      return current.future;
    }
    final future = _build(item);
    _inFlight[item.id] = _InFlightIndexBuild(fingerprint, future);
    void cleanup() {
      if (identical(_inFlight[item.id]?.future, future)) {
        _inFlight.remove(item.id);
      }
    }

    unawaited(
      future.then<void>(
        (_) => cleanup(),
        onError: (Object _, StackTrace __) => cleanup(),
      ),
    );
    return future;
  }

  Future<void> deleteItem(String itemId) async {
    if (!_deleting.add(itemId)) {
      throw const VectorIndexFailure(
        VectorIndexFailureCode.concurrentMutation,
      );
    }
    try {
      final current = _inFlight[itemId];
      if (current != null) {
        try {
          await current.future;
        } on Object {
          // Deletion still has to remove a document after a failed build.
        }
      }
      await _index.deleteDocument(itemId);
    } finally {
      _deleting.remove(itemId);
    }
  }

  Future<KnowledgeIndexBuildResult> _build(KnowledgeItem item) async {
    KnowledgeVectorDocument? existing;
    var recovered = false;
    try {
      existing = await _index.readDocument(item.id);
      if (existing != null) _validateDocument(existing);
    } on VectorIndexFailure catch (error) {
      if (error.code != VectorIndexFailureCode.corruptIndex) rethrow;
      recovered = true;
      existing = null;
    }
    if (existing != null &&
        existing.contentHash == item.contentHash &&
        existing.profileIdentity == profile.identity &&
        existing.chunkerVersion == chunker.version) {
      return KnowledgeIndexBuildResult(
        document: existing,
        skipped: true,
        recoveredCorruption: false,
        embeddingCalls: 0,
      );
    }

    final chunks = chunker.chunk(item);
    final records = <KnowledgeVectorRecord>[];
    var calls = 0;
    for (var offset = 0; offset < chunks.length; offset += maximumBatchSize) {
      final end = (offset + maximumBatchSize).clamp(0, chunks.length);
      final batch = chunks.sublist(offset, end);
      final vectors = await _provider.embed(profile: profile, chunks: batch);
      calls += 1;
      if (vectors.length != batch.length) {
        throw const VectorIndexFailure(
          VectorIndexFailureCode.invalidProviderOutput,
        );
      }
      for (var index = 0; index < batch.length; index += 1) {
        final vector = vectors[index];
        if (vector.chunkId != batch[index].id ||
            vector.values.length != profile.dimensions) {
          throw const VectorIndexFailure(
            VectorIndexFailureCode.invalidProviderOutput,
          );
        }
        records.add(
          KnowledgeVectorRecord(
            chunk: batch[index],
            profileIdentity: profile.identity,
            vector: vector.values,
          ),
        );
      }
    }
    final document = KnowledgeVectorDocument(
      itemId: item.id,
      contentHash: item.contentHash,
      profileIdentity: profile.identity,
      chunkerVersion: chunker.version,
      records: records,
      indexedAt: _utcNow(),
    );
    _validateDocument(document, expectedDimensions: profile.dimensions);
    await _index.replaceDocument(document);
    return KnowledgeIndexBuildResult(
      document: document,
      skipped: false,
      recoveredCorruption: recovered,
      embeddingCalls: calls,
    );
  }

  void _validateDocument(
    KnowledgeVectorDocument document, {
    int? expectedDimensions,
  }) {
    final storedDimensions =
        document.records.isEmpty ? null : document.records.first.vector.length;
    final chunkIds = <String>{};
    if (document.itemId.isEmpty ||
        !_contentHash.hasMatch(document.contentHash) ||
        document.profileIdentity.isEmpty ||
        document.chunkerVersion < 1 ||
        document.records.length > 2048 ||
        !document.indexedAt.isUtc ||
        document.records.indexed.any(
          (entry) =>
              entry.$2.chunk.ordinal != entry.$1 ||
              entry.$2.chunk.chunkerVersion != document.chunkerVersion ||
              !chunkIds.add(entry.$2.chunk.id) ||
              entry.$2.chunk.itemId != document.itemId ||
              entry.$2.chunk.contentHash != document.contentHash ||
              entry.$2.profileIdentity != document.profileIdentity ||
              entry.$2.vector.length < 2 ||
              entry.$2.vector.length > 4096 ||
              entry.$2.vector.length != storedDimensions ||
              (expectedDimensions != null &&
                  entry.$2.vector.length != expectedDimensions) ||
              entry.$2.vector.any((value) => !value.isFinite),
        )) {
      throw const VectorIndexFailure(VectorIndexFailureCode.corruptIndex);
    }
  }

  DateTime _utcNow() {
    final value = _clock.now();
    if (!value.isUtc) throw StateError('Knowledge index clock must return UTC');
    return value;
  }
}

final class _InFlightIndexBuild {
  const _InFlightIndexBuild(this.fingerprint, this.future);

  final String fingerprint;
  final Future<KnowledgeIndexBuildResult> future;
}

int _skipWhitespace(String value, int start) {
  var cursor = start;
  while (cursor < value.length && _isWhitespace(value.codeUnitAt(cursor))) {
    cursor += 1;
  }
  return cursor;
}

int _preferredBreak(String value, int start, int end) {
  for (var cursor = end; cursor > start; cursor -= 1) {
    final code = value.codeUnitAt(cursor - 1);
    if (code == 0x0A || code == 0x20 || code == 0x3002) return cursor;
  }
  return end;
}

int _safeBoundary(String value, int boundary) {
  if (boundary > 0 &&
      boundary < value.length &&
      _isHighSurrogate(value.codeUnitAt(boundary - 1)) &&
      _isLowSurrogate(value.codeUnitAt(boundary))) {
    return boundary - 1;
  }
  return boundary;
}

bool _isWhitespace(int value) =>
    value == 0x20 ||
    value == 0x09 ||
    value == 0x0a ||
    value == 0x0d ||
    value == 0x3000;

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;
bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

final _safeId = RegExp(r'^[A-Za-z0-9._:/-]{1,200}$');
final _hash = RegExp(r'^[a-f0-9]{64}$');
final _contentHash = RegExp(r'^sha256:[a-f0-9]{64}$');
