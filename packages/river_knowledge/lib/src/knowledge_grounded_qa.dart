import 'knowledge_semantic_search.dart';

final class KnowledgeQuestionEvidence {
  const KnowledgeQuestionEvidence({
    required this.chunkId,
    required this.itemId,
    required this.title,
    required this.text,
    required this.sourceStart,
    required this.sourceEnd,
    required this.score,
  });

  final String chunkId;
  final String itemId;
  final String title;
  final String text;
  final int sourceStart;
  final int sourceEnd;
  final double score;
}

final class KnowledgeQuestionProviderRequest {
  KnowledgeQuestionProviderRequest({
    required this.question,
    required this.outputLanguage,
    required Iterable<KnowledgeQuestionEvidence> evidence,
  }) : evidence = List<KnowledgeQuestionEvidence>.unmodifiable(evidence);

  final String question;
  final String outputLanguage;
  final List<KnowledgeQuestionEvidence> evidence;

  @override
  String toString() => 'KnowledgeQuestionProviderRequest('
      'questionLength: ${question.length}, '
      'language: $outputLanguage, evidence: ${evidence.length})';
}

final class KnowledgeQuestionProviderStatement {
  KnowledgeQuestionProviderStatement({
    required this.text,
    required Iterable<String> citationChunkIds,
  }) : citationChunkIds = List<String>.unmodifiable(citationChunkIds);

  final String text;
  final List<String> citationChunkIds;
}

final class KnowledgeQuestionProviderResponse {
  KnowledgeQuestionProviderResponse({
    required this.insufficientEvidence,
    Iterable<KnowledgeQuestionProviderStatement> statements =
        const <KnowledgeQuestionProviderStatement>[],
  }) : statements = List<KnowledgeQuestionProviderStatement>.unmodifiable(
          statements,
        );

  final bool insufficientEvidence;
  final List<KnowledgeQuestionProviderStatement> statements;
}

abstract interface class KnowledgeQuestionAnswerProvider {
  Future<KnowledgeQuestionProviderResponse> answer(
    KnowledgeQuestionProviderRequest request,
  );
}

final class KnowledgeAnswerCitation {
  const KnowledgeAnswerCitation({
    required this.chunkId,
    required this.itemId,
    required this.title,
    required this.quote,
    required this.sourceStart,
    required this.sourceEnd,
  });

  final String chunkId;
  final String itemId;
  final String title;
  final String quote;
  final int sourceStart;
  final int sourceEnd;
}

final class KnowledgeGroundedStatement {
  KnowledgeGroundedStatement({
    required this.text,
    required Iterable<KnowledgeAnswerCitation> citations,
  }) : citations = List<KnowledgeAnswerCitation>.unmodifiable(citations);

  final String text;
  final List<KnowledgeAnswerCitation> citations;
}

enum KnowledgeAnswerOutcome { answered, insufficientEvidence }

final class KnowledgeAnswerResult {
  KnowledgeAnswerResult({
    required this.outcome,
    required Iterable<KnowledgeGroundedStatement> statements,
    required Iterable<KnowledgeQuestionEvidence> evidence,
    required this.providerCalled,
  })  : statements = List<KnowledgeGroundedStatement>.unmodifiable(statements),
        evidence = List<KnowledgeQuestionEvidence>.unmodifiable(evidence);

  final KnowledgeAnswerOutcome outcome;
  final List<KnowledgeGroundedStatement> statements;
  final List<KnowledgeQuestionEvidence> evidence;
  final bool providerCalled;
}

enum KnowledgeQuestionFailureCode { invalidProviderOutput }

final class KnowledgeQuestionFailure implements Exception {
  const KnowledgeQuestionFailure(this.code);

  final KnowledgeQuestionFailureCode code;

  @override
  String toString() => 'KnowledgeQuestionFailure(${code.name})';
}

final class KnowledgeGroundedQuestionAnswering {
  KnowledgeGroundedQuestionAnswering({
    required KnowledgeSemanticSearch search,
    required KnowledgeQuestionAnswerProvider provider,
    this.maximumSearchHits = 5,
    this.maximumEvidence = 10,
    this.minimumEvidenceScore = 0.45,
  })  : _search = search,
        _provider = provider {
    if (maximumSearchHits < 1 ||
        maximumSearchHits > 20 ||
        maximumEvidence < 1 ||
        maximumEvidence > 50 ||
        maximumEvidence < maximumSearchHits ||
        !minimumEvidenceScore.isFinite ||
        minimumEvidenceScore < 0 ||
        minimumEvidenceScore > 1) {
      throw ArgumentError('Invalid grounded question-answering policy');
    }
  }

  final KnowledgeSemanticSearch _search;
  final KnowledgeQuestionAnswerProvider _provider;
  final int maximumSearchHits;
  final int maximumEvidence;
  final double minimumEvidenceScore;

  Future<KnowledgeAnswerResult> ask(
    String question, {
    String outputLanguage = 'zh-CN',
  }) async {
    final normalized = question.trim();
    if (normalized.isEmpty ||
        normalized.length > 2000 ||
        !_languageTag.hasMatch(outputLanguage)) {
      throw ArgumentError('Invalid knowledge question');
    }
    final hits = await _search.search(
      normalized,
      limit: maximumSearchHits,
      minimumScore: minimumEvidenceScore,
    );
    final evidence = <KnowledgeQuestionEvidence>[];
    final seenChunks = <String>{};
    for (final hit in hits) {
      for (final source in hit.evidence) {
        if (seenChunks.add(source.chunkId)) {
          evidence.add(
            KnowledgeQuestionEvidence(
              chunkId: source.chunkId,
              itemId: hit.itemId,
              title: hit.title,
              text: source.text,
              sourceStart: source.sourceStart,
              sourceEnd: source.sourceEnd,
              score: source.score,
            ),
          );
          if (evidence.length == maximumEvidence) break;
        }
      }
      if (evidence.length == maximumEvidence) break;
    }
    if (evidence.isEmpty) {
      return KnowledgeAnswerResult(
        outcome: KnowledgeAnswerOutcome.insufficientEvidence,
        statements: const <KnowledgeGroundedStatement>[],
        evidence: const <KnowledgeQuestionEvidence>[],
        providerCalled: false,
      );
    }

    final response = await _provider.answer(
      KnowledgeQuestionProviderRequest(
        question: normalized,
        outputLanguage: outputLanguage,
        evidence: evidence,
      ),
    );
    if (response.insufficientEvidence) {
      if (response.statements.isNotEmpty) _invalidOutput();
      return KnowledgeAnswerResult(
        outcome: KnowledgeAnswerOutcome.insufficientEvidence,
        statements: const <KnowledgeGroundedStatement>[],
        evidence: evidence,
        providerCalled: true,
      );
    }
    if (response.statements.isEmpty || response.statements.length > 12) {
      _invalidOutput();
    }
    final byChunk = <String, KnowledgeQuestionEvidence>{
      for (final item in evidence) item.chunkId: item,
    };
    var totalCharacters = 0;
    final statements = <KnowledgeGroundedStatement>[];
    for (final statement in response.statements) {
      final text = statement.text.trim();
      totalCharacters += text.length;
      if (text.isEmpty ||
          text.length > 2000 ||
          totalCharacters > 12000 ||
          statement.citationChunkIds.isEmpty ||
          statement.citationChunkIds.length > 5 ||
          statement.citationChunkIds.toSet().length !=
              statement.citationChunkIds.length) {
        _invalidOutput();
      }
      final citations = <KnowledgeAnswerCitation>[];
      for (final chunkId in statement.citationChunkIds) {
        final source = byChunk[chunkId];
        if (source == null) _invalidOutput();
        citations.add(
          KnowledgeAnswerCitation(
            chunkId: source.chunkId,
            itemId: source.itemId,
            title: source.title,
            quote: source.text,
            sourceStart: source.sourceStart,
            sourceEnd: source.sourceEnd,
          ),
        );
      }
      statements.add(
        KnowledgeGroundedStatement(text: text, citations: citations),
      );
    }
    return KnowledgeAnswerResult(
      outcome: KnowledgeAnswerOutcome.answered,
      statements: statements,
      evidence: evidence,
      providerCalled: true,
    );
  }

  Never _invalidOutput() => throw const KnowledgeQuestionFailure(
        KnowledgeQuestionFailureCode.invalidProviderOutput,
      );
}

final _languageTag = RegExp(r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$');
