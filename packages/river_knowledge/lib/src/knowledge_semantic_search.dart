import 'package:river_domain/river_domain.dart';

import 'knowledge_vector_index.dart';

final class KnowledgeSearchEvidence {
  const KnowledgeSearchEvidence({
    required this.chunkId,
    required this.ordinal,
    required this.text,
    required this.sourceStart,
    required this.sourceEnd,
    required this.score,
  });

  final String chunkId;
  final int ordinal;
  final String text;
  final int sourceStart;
  final int sourceEnd;
  final double score;
}

final class KnowledgeSearchHit {
  KnowledgeSearchHit({
    required this.itemId,
    required this.title,
    required this.sourceKind,
    required this.sourceId,
    required this.contentHash,
    required this.savedAt,
    required this.score,
    required Iterable<KnowledgeSearchEvidence> evidence,
  }) : evidence = List<KnowledgeSearchEvidence>.unmodifiable(evidence);

  final String itemId;
  final String title;
  final KnowledgeSourceKind sourceKind;
  final String sourceId;
  final String contentHash;
  final DateTime savedAt;
  final double score;
  final List<KnowledgeSearchEvidence> evidence;
}

enum KnowledgeSemanticSearchFailureCode {
  itemNotIndexed,
  incompatibleProfile,
  emptyDocument,
}

final class KnowledgeSemanticSearchFailure implements Exception {
  const KnowledgeSemanticSearchFailure(this.code);

  final KnowledgeSemanticSearchFailureCode code;

  @override
  String toString() => 'KnowledgeSemanticSearchFailure(${code.name})';
}

final class KnowledgeSemanticSearch {
  KnowledgeSemanticSearch({
    required this.profile,
    required KnowledgeEmbeddingProvider provider,
    required KnowledgeVectorIndex index,
    this.maximumCandidateRecords = 1000,
    this.maximumEvidencePerItem = 3,
  })  : _provider = provider,
        _index = index {
    if (maximumCandidateRecords < 20 || maximumCandidateRecords > 10000) {
      throw ArgumentError.value(
        maximumCandidateRecords,
        'maximumCandidateRecords',
      );
    }
    if (maximumEvidencePerItem < 1 || maximumEvidencePerItem > 10) {
      throw ArgumentError.value(
        maximumEvidencePerItem,
        'maximumEvidencePerItem',
      );
    }
  }

  final EmbeddingProfile profile;
  final KnowledgeEmbeddingProvider _provider;
  final KnowledgeVectorIndex _index;
  final int maximumCandidateRecords;
  final int maximumEvidencePerItem;

  Future<List<KnowledgeSearchHit>> search(
    String query, {
    KnowledgeVectorQueryFilter? filter,
    int limit = 20,
    double minimumScore = 0.2,
  }) async {
    final normalized = query.trim();
    _validateRequest(normalized, limit, minimumScore);
    final vector = await _provider.embedQuery(
      profile: profile,
      query: normalized,
    );
    _validateVector(vector);
    return _searchVector(
      vector,
      filter: filter ?? KnowledgeVectorQueryFilter(),
      limit: limit,
      minimumScore: minimumScore,
    );
  }

  Future<List<KnowledgeSearchHit>> similarItems(
    String itemId, {
    KnowledgeVectorQueryFilter? filter,
    int limit = 20,
    double minimumScore = 0.2,
  }) async {
    if (itemId.trim().isEmpty || itemId.length > 256) {
      throw ArgumentError.value(itemId, 'itemId');
    }
    _validateRequest('similar', limit, minimumScore);
    final document = await _index.readDocument(itemId);
    if (document == null) {
      throw const KnowledgeSemanticSearchFailure(
        KnowledgeSemanticSearchFailureCode.itemNotIndexed,
      );
    }
    if (document.profileIdentity != profile.identity) {
      throw const KnowledgeSemanticSearchFailure(
        KnowledgeSemanticSearchFailureCode.incompatibleProfile,
      );
    }
    if (document.records.isEmpty) {
      throw const KnowledgeSemanticSearchFailure(
        KnowledgeSemanticSearchFailureCode.emptyDocument,
      );
    }
    final vector = List<double>.filled(profile.dimensions, 0);
    for (final record in document.records) {
      if (record.vector.length != profile.dimensions ||
          record.vector.any((value) => !value.isFinite)) {
        throw const VectorIndexFailure(VectorIndexFailureCode.corruptIndex);
      }
      for (var index = 0; index < vector.length; index += 1) {
        vector[index] += record.vector[index];
      }
    }
    final baseFilter = filter ?? KnowledgeVectorQueryFilter();
    final effectiveFilter = KnowledgeVectorQueryFilter(
      sourceKinds: baseFilter.sourceKinds,
      sourceIds: baseFilter.sourceIds,
      tags: baseFilter.tags,
      topics: baseFilter.topics,
      excludedItemIds: <String>{...baseFilter.excludedItemIds, itemId},
      savedFrom: baseFilter.savedFrom,
      savedBefore: baseFilter.savedBefore,
    );
    return _searchVector(
      vector,
      filter: effectiveFilter,
      limit: limit,
      minimumScore: minimumScore,
    );
  }

  Future<List<KnowledgeSearchHit>> _searchVector(
    List<double> vector, {
    required KnowledgeVectorQueryFilter filter,
    required int limit,
    required double minimumScore,
  }) async {
    final records = await _index.searchRecords(
      profileIdentity: profile.identity,
      vector: vector,
      filter: filter,
      limit: maximumCandidateRecords,
      minimumScore: minimumScore,
    );
    final grouped = <String, List<KnowledgeVectorMatch>>{};
    for (final match in records) {
      grouped.putIfAbsent(match.document.itemId, () => []).add(match);
    }
    final hits = <KnowledgeSearchHit>[];
    for (final matches in grouped.values) {
      matches.sort((left, right) {
        final score = right.score.compareTo(left.score);
        if (score != 0) return score;
        return left.record.chunk.ordinal.compareTo(right.record.chunk.ordinal);
      });
      final best = matches.first;
      hits.add(
        KnowledgeSearchHit(
          itemId: best.document.itemId,
          title: best.document.title,
          sourceKind: best.document.sourceKind,
          sourceId: best.document.sourceId,
          contentHash: best.document.contentHash,
          savedAt: best.document.savedAt,
          score: best.score,
          evidence: matches.take(maximumEvidencePerItem).map(
                (match) => KnowledgeSearchEvidence(
                  chunkId: match.record.chunk.id,
                  ordinal: match.record.chunk.ordinal,
                  text: match.record.chunk.text,
                  sourceStart: match.record.chunk.sourceStart,
                  sourceEnd: match.record.chunk.sourceEnd,
                  score: match.score,
                ),
              ),
        ),
      );
    }
    hits.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      return left.itemId.compareTo(right.itemId);
    });
    return List<KnowledgeSearchHit>.unmodifiable(hits.take(limit));
  }

  void _validateRequest(String query, int limit, double minimumScore) {
    if (query.isEmpty ||
        query.length > 2000 ||
        limit < 1 ||
        limit > 100 ||
        !minimumScore.isFinite ||
        minimumScore < -1 ||
        minimumScore > 1) {
      throw ArgumentError('Invalid semantic search request');
    }
  }

  void _validateVector(List<double> vector) {
    if (vector.length != profile.dimensions ||
        vector.any((value) => !value.isFinite)) {
      throw const VectorIndexFailure(
        VectorIndexFailureCode.invalidProviderOutput,
      );
    }
  }
}
