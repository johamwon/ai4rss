import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

  Future<List<double>> embedQuery({
    required EmbeddingProfile profile,
    required String query,
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
    required this.sourceKind,
    required this.sourceId,
    required this.title,
    required this.savedAt,
    required this.updatedAt,
    Iterable<String> tags = const <String>[],
    Iterable<String> topics = const <String>[],
    required this.profileIdentity,
    required this.chunkerVersion,
    required Iterable<KnowledgeVectorRecord> records,
    required this.indexedAt,
  })  : tags = Set<String>.unmodifiable(tags),
        topics = Set<String>.unmodifiable(topics),
        records = List<KnowledgeVectorRecord>.unmodifiable(records);

  final String itemId;
  final String contentHash;
  final KnowledgeSourceKind sourceKind;
  final String sourceId;
  final String title;
  final DateTime savedAt;
  final DateTime updatedAt;
  final Set<String> tags;
  final Set<String> topics;
  final String profileIdentity;
  final int chunkerVersion;
  final List<KnowledgeVectorRecord> records;
  final DateTime indexedAt;
}

final class KnowledgeVectorQueryFilter {
  KnowledgeVectorQueryFilter({
    Iterable<KnowledgeSourceKind> sourceKinds = const <KnowledgeSourceKind>[],
    Iterable<String> sourceIds = const <String>[],
    Iterable<String> tags = const <String>[],
    Iterable<String> topics = const <String>[],
    Iterable<String> excludedItemIds = const <String>[],
    this.savedFrom,
    this.savedBefore,
  })  : sourceKinds = Set<KnowledgeSourceKind>.unmodifiable(sourceKinds),
        sourceIds = _boundedFilterValues(sourceIds, 'sourceIds'),
        tags = _boundedFilterValues(tags, 'tags'),
        topics = _boundedFilterValues(topics, 'topics'),
        excludedItemIds =
            _boundedFilterValues(excludedItemIds, 'excludedItemIds') {
    if (this.sourceKinds.length > KnowledgeSourceKind.values.length ||
        (savedFrom != null && !savedFrom!.isUtc) ||
        (savedBefore != null && !savedBefore!.isUtc) ||
        (savedFrom != null &&
            savedBefore != null &&
            !savedFrom!.isBefore(savedBefore!))) {
      throw ArgumentError('Invalid knowledge vector query filter');
    }
  }

  final Set<KnowledgeSourceKind> sourceKinds;
  final Set<String> sourceIds;
  final Set<String> tags;
  final Set<String> topics;
  final Set<String> excludedItemIds;
  final DateTime? savedFrom;
  final DateTime? savedBefore;

  bool allows(KnowledgeVectorDocument document) =>
      (sourceKinds.isEmpty || sourceKinds.contains(document.sourceKind)) &&
      (sourceIds.isEmpty || sourceIds.contains(document.sourceId)) &&
      (tags.isEmpty || document.tags.any(tags.contains)) &&
      (topics.isEmpty || document.topics.any(topics.contains)) &&
      !excludedItemIds.contains(document.itemId) &&
      (savedFrom == null || !document.savedAt.isBefore(savedFrom!)) &&
      (savedBefore == null || document.savedAt.isBefore(savedBefore!));
}

final class KnowledgeVectorMatch {
  const KnowledgeVectorMatch({
    required this.document,
    required this.record,
    required this.score,
  });

  final KnowledgeVectorDocument document;
  final KnowledgeVectorRecord record;
  final double score;
}

abstract interface class KnowledgeVectorIndex {
  Future<KnowledgeVectorDocument?> readDocument(String itemId);
  Future<void> replaceDocument(KnowledgeVectorDocument document);
  Future<void> deleteDocument(String itemId);
  Future<void> clearProfile(String profileIdentity);
  Future<List<KnowledgeVectorMatch>> searchRecords({
    required String profileIdentity,
    required List<double> vector,
    required KnowledgeVectorQueryFilter filter,
    required int limit,
    required double minimumScore,
  });
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

  @override
  Future<List<KnowledgeVectorMatch>> searchRecords({
    required String profileIdentity,
    required List<double> vector,
    required KnowledgeVectorQueryFilter filter,
    required int limit,
    required double minimumScore,
  }) async {
    if (vector.length < 2 ||
        vector.length > 4096 ||
        vector.any((value) => !value.isFinite) ||
        limit < 1 ||
        limit > 10000 ||
        !minimumScore.isFinite ||
        minimumScore < -1 ||
        minimumScore > 1) {
      throw ArgumentError('Invalid vector search request');
    }
    final matches = <KnowledgeVectorMatch>[];
    for (final document in _documents.values) {
      if (document.profileIdentity != profileIdentity ||
          !filter.allows(document)) {
        continue;
      }
      for (final record in document.records) {
        if (record.vector.length != vector.length) continue;
        final score = _cosineSimilarity(vector, record.vector);
        if (score >= minimumScore) {
          matches.add(
            KnowledgeVectorMatch(
              document: document,
              record: record,
              score: score,
            ),
          );
        }
      }
    }
    matches.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final item = left.document.itemId.compareTo(right.document.itemId);
      if (item != 0) return item;
      return left.record.chunk.ordinal.compareTo(right.record.chunk.ordinal);
    });
    return List<KnowledgeVectorMatch>.unmodifiable(matches.take(limit));
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
    final fingerprint = '${item.contentHash}|${_metadataIdentity(item)}|'
        '${profile.identity}|${chunker.version}';
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
        _metadataMatches(existing, item) &&
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
      sourceKind: item.source.kind,
      sourceId: item.source.sourceId,
      title: item.title,
      savedAt: item.savedAt.toUtc(),
      updatedAt: item.updatedAt.toUtc(),
      tags: item.tags,
      topics: item.topics,
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
        document.sourceId.trim().isEmpty ||
        document.title.trim().isEmpty ||
        !document.savedAt.isUtc ||
        !document.updatedAt.isUtc ||
        document.updatedAt.isBefore(document.savedAt) ||
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

  String _metadataIdentity(KnowledgeItem item) {
    final tags = item.tags.toList()..sort();
    final topics = item.topics.toList()..sort();
    return sha256
        .convert(
          utf8.encode(
            '${item.source.kind.name}\n${item.source.sourceId}\n${item.title}\n'
            '${item.savedAt.toUtc().microsecondsSinceEpoch}\n'
            '${item.updatedAt.toUtc().microsecondsSinceEpoch}\n'
            '${tags.join('\u0000')}\n${topics.join('\u0000')}',
          ),
        )
        .toString();
  }

  bool _metadataMatches(
    KnowledgeVectorDocument document,
    KnowledgeItem item,
  ) =>
      document.sourceKind == item.source.kind &&
      document.sourceId == item.source.sourceId &&
      document.title == item.title &&
      document.savedAt == item.savedAt.toUtc() &&
      document.updatedAt == item.updatedAt.toUtc() &&
      _sameStrings(document.tags, item.tags) &&
      _sameStrings(document.topics, item.topics);
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

Set<String> _boundedFilterValues(Iterable<String> values, String name) {
  final result = <String>{};
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > 256 ||
        result.length >= 1000) {
      throw ArgumentError.value(value, name);
    }
    result.add(normalized);
  }
  return Set<String>.unmodifiable(result);
}

double _cosineSimilarity(List<double> left, List<double> right) {
  var dot = 0.0;
  var leftNorm = 0.0;
  var rightNorm = 0.0;
  for (var index = 0; index < left.length; index += 1) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  if (leftNorm == 0 || rightNorm == 0) return -1;
  return (dot / (sqrt(leftNorm) * sqrt(rightNorm))).clamp(-1, 1);
}

bool _sameStrings(Set<String> left, Iterable<String> right) {
  final values = right.toSet();
  return left.length == values.length && left.containsAll(values);
}
