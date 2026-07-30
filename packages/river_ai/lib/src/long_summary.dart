import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

import 'prompt_registry.dart';
import 'provider.dart';
import 'summary_cache.dart';
import 'summary_schema.dart';

final class AiContextBudget {
  const AiContextBudget({
    this.mapContentCharacters = 12000,
    this.overlapParagraphs = 1,
    this.maxChunks = 64,
    this.maxMapPromptCharacters = 32000,
    this.maxReducePromptCharacters = 64000,
    this.maxRequestBytes = 240 * 1024,
    this.mapOutputTokens = 1400,
    this.reduceOutputTokens = 1600,
  })  : assert(mapContentCharacters >= 1000),
        assert(overlapParagraphs >= 0 && overlapParagraphs <= 4),
        assert(maxChunks >= 1 && maxChunks <= 256),
        assert(maxMapPromptCharacters >= mapContentCharacters),
        assert(maxMapPromptCharacters <= 160000),
        assert(maxReducePromptCharacters >= 2000),
        assert(maxReducePromptCharacters <= 160000),
        assert(maxRequestBytes >= 32 * 1024),
        assert(maxRequestBytes <= 256 * 1024),
        assert(mapOutputTokens >= 1 && mapOutputTokens <= 32768),
        assert(reduceOutputTokens >= 1 && reduceOutputTokens <= 32768);

  final int mapContentCharacters;
  final int overlapParagraphs;
  final int maxChunks;
  final int maxMapPromptCharacters;
  final int maxReducePromptCharacters;
  final int maxRequestBytes;
  final int mapOutputTokens;
  final int reduceOutputTokens;
}

final class ArticleSummaryChunk {
  ArticleSummaryChunk({
    required this.articleId,
    required this.index,
    required this.paragraphStart,
    required this.paragraphEnd,
    required this.text,
  }) {
    if (articleId.trim().isEmpty ||
        index < 0 ||
        paragraphStart < 0 ||
        paragraphEnd <= paragraphStart ||
        text.trim().isEmpty) {
      throw ArgumentError('Invalid article summary chunk');
    }
  }

  final String articleId;
  final int index;
  final int paragraphStart;
  final int paragraphEnd;
  final String text;

  @override
  String toString() => 'ArticleSummaryChunk('
      'articleId: $articleId, '
      'index: $index, '
      'paragraphRange: [$paragraphStart, $paragraphEnd), '
      'characters: ${text.length}'
      ')';
}

final class ArticleSummaryChunkPlanner {
  const ArticleSummaryChunkPlanner();

  List<ArticleSummaryChunk> plan({
    required String articleId,
    required String content,
    required AiContextBudget budget,
  }) {
    if (articleId.trim().isEmpty || content.trim().isEmpty) {
      throw ArgumentError('Article id and content are required');
    }
    final paragraphs = _paragraphs(content);
    final pieces = <_ParagraphPiece>[];
    for (var index = 0; index < paragraphs.length; index++) {
      for (final text in _splitBounded(
        paragraphs[index],
        budget.mapContentCharacters,
      )) {
        pieces.add(_ParagraphPiece(index, text));
      }
    }

    final groups = <_PieceRange>[];
    var start = 0;
    while (start < pieces.length) {
      var end = start;
      var characters = 0;
      while (end < pieces.length) {
        final addition = pieces[end].text.length + (end == start ? 0 : 2);
        if (end > start &&
            characters + addition > budget.mapContentCharacters) {
          break;
        }
        characters += addition;
        end++;
      }
      groups.add(_PieceRange(start, end));
      start = end;
    }
    if (groups.length > budget.maxChunks) {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.tooManyChunks,
      );
    }

    return List<ArticleSummaryChunk>.unmodifiable(
      <ArticleSummaryChunk>[
        for (var index = 0; index < groups.length; index++)
          _chunk(
            articleId,
            index,
            groups[index],
            pieces,
            overlap: index == 0 ? 0 : budget.overlapParagraphs,
          ),
      ],
    );
  }

  ArticleSummaryChunk _chunk(
    String articleId,
    int index,
    _PieceRange group,
    List<_ParagraphPiece> pieces, {
    required int overlap,
  }) {
    final startPiece = math.max(0, group.start - overlap);
    final selected = pieces.sublist(startPiece, group.end);
    final text = selected
        .map((piece) => '[P${piece.paragraphIndex}] ${piece.text}')
        .join('\n\n');
    return ArticleSummaryChunk(
      articleId: articleId,
      index: index,
      paragraphStart: selected.first.paragraphIndex,
      paragraphEnd: selected.last.paragraphIndex + 1,
      text: text,
    );
  }
}

final class ParagraphCitation {
  ParagraphCitation({
    required this.articleId,
    required this.paragraphStart,
    required this.paragraphEnd,
  }) {
    if (articleId.trim().isEmpty ||
        paragraphStart < 0 ||
        paragraphEnd <= paragraphStart) {
      throw ArgumentError('Invalid paragraph citation');
    }
  }

  final String articleId;
  final int paragraphStart;
  final int paragraphEnd;

  Map<String, Object> toJson() => <String, Object>{
        'articleId': articleId,
        'paragraphStart': paragraphStart,
        'paragraphEnd': paragraphEnd,
      };

  @override
  bool operator ==(Object other) =>
      other is ParagraphCitation &&
      other.articleId == articleId &&
      other.paragraphStart == paragraphStart &&
      other.paragraphEnd == paragraphEnd;

  @override
  int get hashCode => Object.hash(articleId, paragraphStart, paragraphEnd);
}

final class SourcedArticleFact {
  SourcedArticleFact({
    required this.text,
    required Iterable<ParagraphCitation> citations,
  }) : citations = List<ParagraphCitation>.unmodifiable(citations) {
    if (text.trim() != text ||
        text.isEmpty ||
        text.length > 800 ||
        this.citations.isEmpty ||
        this.citations.length > 256) {
      throw ArgumentError('Invalid sourced article fact');
    }
  }

  final String text;
  final List<ParagraphCitation> citations;

  Map<String, Object> toJson() => <String, Object>{
        'text': text,
        'citations': citations
            .map((citation) => citation.toJson())
            .toList(growable: false),
      };

  @override
  String toString() => 'SourcedArticleFact('
      'characters: ${text.length}, '
      'citations: ${citations.length}'
      ')';
}

final class AiChunkSummary {
  AiChunkSummary({
    required this.articleId,
    required this.chunkIndex,
    required this.paragraphStart,
    required this.paragraphEnd,
    required Iterable<SourcedArticleFact> facts,
    required Iterable<String> topics,
    required Iterable<String> entities,
    required this.language,
  })  : facts = List<SourcedArticleFact>.unmodifiable(facts),
        topics = List<String>.unmodifiable(topics),
        entities = List<String>.unmodifiable(entities) {
    if (articleId.trim().isEmpty ||
        chunkIndex < 0 ||
        paragraphStart < 0 ||
        paragraphEnd <= paragraphStart ||
        this.facts.isEmpty ||
        this.facts.length > 20 ||
        !_isBoundedDistinctStrings(this.topics, 12, 80) ||
        !_isBoundedDistinctStrings(this.entities, 20, 120) ||
        !ArticleSummarySchema.languageTag.hasMatch(language) ||
        this.facts.any(
              (fact) => fact.citations.any(
                (citation) =>
                    citation.articleId != articleId ||
                    citation.paragraphStart < paragraphStart ||
                    citation.paragraphEnd > paragraphEnd,
              ),
            )) {
      throw ArgumentError('Invalid AI chunk summary');
    }
  }

  final String articleId;
  final int chunkIndex;
  final int paragraphStart;
  final int paragraphEnd;
  final List<SourcedArticleFact> facts;
  final List<String> topics;
  final List<String> entities;
  final String language;

  @override
  String toString() => 'AiChunkSummary('
      'articleId: $articleId, '
      'chunkIndex: $chunkIndex, '
      'paragraphRange: [$paragraphStart, $paragraphEnd), '
      'facts: ${facts.length}, '
      'language: $language'
      ')';
}

final class AiChunkSummarySchema {
  const AiChunkSummarySchema();

  static const name = 'river.article-summary.chunk.v1';
  static const Map<String, Object?> jsonSchema = <String, Object?>{
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'title': name,
    'type': 'object',
    'additionalProperties': false,
    'required': <String>[
      'schemaVersion',
      'articleId',
      'chunkIndex',
      'paragraphStart',
      'paragraphEnd',
      'facts',
      'topics',
      'entities',
      'language',
    ],
    'properties': <String, Object?>{
      'schemaVersion': <String, Object?>{'const': name},
      'articleId': <String, Object?>{
        'type': 'string',
        'minLength': 1,
        'maxLength': 256,
      },
      'chunkIndex': <String, Object?>{'type': 'integer', 'minimum': 0},
      'paragraphStart': <String, Object?>{'type': 'integer', 'minimum': 0},
      'paragraphEnd': <String, Object?>{'type': 'integer', 'minimum': 1},
      'facts': <String, Object?>{
        'type': 'array',
        'minItems': 1,
        'maxItems': 20,
        'items': <String, Object?>{
          'type': 'object',
          'additionalProperties': false,
          'required': <String>[
            'text',
            'articleId',
            'paragraphStart',
            'paragraphEnd',
          ],
          'properties': <String, Object?>{
            'text': <String, Object?>{
              'type': 'string',
              'minLength': 1,
              'maxLength': 800,
            },
            'articleId': <String, Object?>{
              'type': 'string',
              'minLength': 1,
              'maxLength': 256,
            },
            'paragraphStart': <String, Object?>{
              'type': 'integer',
              'minimum': 0,
            },
            'paragraphEnd': <String, Object?>{
              'type': 'integer',
              'minimum': 1,
            },
          },
        },
      },
      'topics': <String, Object?>{
        'type': 'array',
        'maxItems': 12,
        'uniqueItems': true,
        'items': <String, Object?>{
          'type': 'string',
          'minLength': 1,
          'maxLength': 80,
        },
      },
      'entities': <String, Object?>{
        'type': 'array',
        'maxItems': 20,
        'uniqueItems': true,
        'items': <String, Object?>{
          'type': 'string',
          'minLength': 1,
          'maxLength': 120,
        },
      },
      'language': <String, Object?>{
        'type': 'string',
        'minLength': 2,
        'maxLength': 35,
      },
    },
  };

  AiChunkSummary parse(
    String output, {
    required ArticleSummaryChunk expectedChunk,
    required String expectedLanguage,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(output);
    } on FormatException {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.invalidChunkOutput,
      );
    }
    if (decoded is! Map<String, Object?> ||
        !_hasExactKeys(decoded, const <String>{
          'schemaVersion',
          'articleId',
          'chunkIndex',
          'paragraphStart',
          'paragraphEnd',
          'facts',
          'topics',
          'entities',
          'language',
        }) ||
        decoded['schemaVersion'] != name ||
        decoded['articleId'] != expectedChunk.articleId ||
        decoded['chunkIndex'] != expectedChunk.index ||
        decoded['paragraphStart'] != expectedChunk.paragraphStart ||
        decoded['paragraphEnd'] != expectedChunk.paragraphEnd ||
        decoded['language'] != expectedLanguage) {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.invalidChunkOutput,
      );
    }
    final rawFacts = decoded['facts'];
    if (rawFacts is! List<Object?> ||
        rawFacts.isEmpty ||
        rawFacts.length > 20) {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.invalidChunkOutput,
      );
    }
    final facts = <SourcedArticleFact>[];
    for (final rawFact in rawFacts) {
      if (rawFact is! Map<String, Object?> ||
          !_hasExactKeys(rawFact, const <String>{
            'text',
            'articleId',
            'paragraphStart',
            'paragraphEnd',
          })) {
        throw const AiLongSummaryFailure(
          AiLongSummaryFailureCode.invalidChunkOutput,
        );
      }
      final text = rawFact['text'];
      final articleId = rawFact['articleId'];
      final paragraphStart = rawFact['paragraphStart'];
      final paragraphEnd = rawFact['paragraphEnd'];
      if (text is! String ||
          text.trim() != text ||
          text.isEmpty ||
          text.length > 800 ||
          articleId != expectedChunk.articleId ||
          paragraphStart is! int ||
          paragraphEnd is! int ||
          paragraphStart < expectedChunk.paragraphStart ||
          paragraphEnd > expectedChunk.paragraphEnd ||
          paragraphEnd <= paragraphStart) {
        throw const AiLongSummaryFailure(
          AiLongSummaryFailureCode.invalidChunkOutput,
        );
      }
      facts.add(
        SourcedArticleFact(
          text: text,
          citations: <ParagraphCitation>[
            ParagraphCitation(
              articleId: articleId! as String,
              paragraphStart: paragraphStart,
              paragraphEnd: paragraphEnd,
            ),
          ],
        ),
      );
    }
    final topics = _boundedStrings(decoded['topics'], 12, 80);
    final entities = _boundedStrings(decoded['entities'], 20, 120);
    if (!ArticleSummarySchema.languageTag.hasMatch(expectedLanguage)) {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.invalidChunkOutput,
      );
    }
    return AiChunkSummary(
      articleId: expectedChunk.articleId,
      chunkIndex: expectedChunk.index,
      paragraphStart: expectedChunk.paragraphStart,
      paragraphEnd: expectedChunk.paragraphEnd,
      facts: facts,
      topics: topics,
      entities: entities,
      language: expectedLanguage,
    );
  }
}

abstract interface class AiLongSummaryCheckpointStore {
  Future<AiLongSummaryCheckpoint?> read(String articleId);
  Future<void> write(AiLongSummaryCheckpoint checkpoint);
  Future<void> clear(String articleId);
}

final class AiLongSummaryCheckpoint {
  AiLongSummaryCheckpoint({
    required this.articleId,
    required this.fingerprint,
    required this.chunkCount,
    required Map<int, AiChunkSummary> completedChunks,
    this.inputTokens = 0,
    this.outputTokens = 0,
  }) : completedChunks =
            Map<int, AiChunkSummary>.unmodifiable(completedChunks) {
    if (articleId.trim().isEmpty ||
        articleId.length > 240 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint) ||
        chunkCount < 1 ||
        chunkCount > 256 ||
        inputTokens < 0 ||
        outputTokens < 0 ||
        completedChunks.keys.any((index) => index < 0 || index >= chunkCount)) {
      throw ArgumentError('Invalid long-summary checkpoint');
    }
  }

  final String articleId;
  final String fingerprint;
  final int chunkCount;
  final Map<int, AiChunkSummary> completedChunks;
  final int inputTokens;
  final int outputTokens;

  @override
  String toString() => 'AiLongSummaryCheckpoint('
      'articleId: $articleId, '
      'chunkCount: $chunkCount, '
      'completedChunks: ${completedChunks.length}, '
      'inputTokens: $inputTokens, '
      'outputTokens: $outputTokens'
      ')';
}

final class AiLongSummaryCheckpointCodec {
  const AiLongSummaryCheckpointCodec();

  static const schemaVersion = 1;
  static const maxEncodedCharacters = 4 * 1024 * 1024;

  String encode(AiLongSummaryCheckpoint checkpoint) => jsonEncode(
        <String, Object?>{
          'schemaVersion': schemaVersion,
          'articleId': checkpoint.articleId,
          'fingerprint': checkpoint.fingerprint,
          'chunkCount': checkpoint.chunkCount,
          'inputTokens': checkpoint.inputTokens,
          'outputTokens': checkpoint.outputTokens,
          'completedChunks': <Map<String, Object?>>[
            for (final entry
                in checkpoint.completedChunks.entries.toList()
                  ..sort((left, right) => left.key.compareTo(right.key)))
              <String, Object?>{
                'index': entry.key,
                'articleId': entry.value.articleId,
                'chunkIndex': entry.value.chunkIndex,
                'paragraphStart': entry.value.paragraphStart,
                'paragraphEnd': entry.value.paragraphEnd,
                'facts': entry.value.facts
                    .map((fact) => fact.toJson())
                    .toList(growable: false),
                'topics': entry.value.topics,
                'entities': entry.value.entities,
                'language': entry.value.language,
              },
          ],
        },
      );

  AiLongSummaryCheckpoint decode(String encoded) {
    if (encoded.isEmpty || encoded.length > maxEncodedCharacters) {
      throw const FormatException('Invalid AI checkpoint size');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const FormatException('Invalid AI checkpoint JSON');
    }
    if (decoded is! Map<String, Object?> ||
        !_hasExactKeys(decoded, const <String>{
          'schemaVersion',
          'articleId',
          'fingerprint',
          'chunkCount',
          'inputTokens',
          'outputTokens',
          'completedChunks',
        }) ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported AI checkpoint schema');
    }
    final articleId = decoded['articleId'];
    final fingerprint = decoded['fingerprint'];
    final chunkCount = decoded['chunkCount'];
    final inputTokens = decoded['inputTokens'];
    final outputTokens = decoded['outputTokens'];
    final rawChunks = decoded['completedChunks'];
    if (articleId is! String ||
        fingerprint is! String ||
        chunkCount is! int ||
        inputTokens is! int ||
        outputTokens is! int ||
        rawChunks is! List<Object?> ||
        rawChunks.length > 256) {
      throw const FormatException('Invalid AI checkpoint envelope');
    }
    final completed = <int, AiChunkSummary>{};
    try {
      for (final rawChunk in rawChunks) {
        if (rawChunk is! Map<String, Object?> ||
            !_hasExactKeys(rawChunk, const <String>{
              'index',
              'articleId',
              'chunkIndex',
              'paragraphStart',
              'paragraphEnd',
              'facts',
              'topics',
              'entities',
              'language',
            })) {
          throw const FormatException('Invalid AI checkpoint chunk');
        }
        final index = rawChunk['index'];
        final chunkArticleId = rawChunk['articleId'];
        final chunkIndex = rawChunk['chunkIndex'];
        final paragraphStart = rawChunk['paragraphStart'];
        final paragraphEnd = rawChunk['paragraphEnd'];
        final language = rawChunk['language'];
        final rawFacts = rawChunk['facts'];
        if (index is! int ||
            chunkArticleId is! String ||
            chunkIndex is! int ||
            paragraphStart is! int ||
            paragraphEnd is! int ||
            language is! String ||
            rawFacts is! List<Object?> ||
            rawFacts.isEmpty ||
            rawFacts.length > 20) {
          throw const FormatException('Invalid AI checkpoint chunk values');
        }
        final facts = <SourcedArticleFact>[];
        for (final rawFact in rawFacts) {
          if (rawFact is! Map<String, Object?> ||
              !_hasExactKeys(rawFact, const <String>{
                'text',
                'citations',
              })) {
            throw const FormatException('Invalid AI checkpoint fact');
          }
          final text = rawFact['text'];
          final rawCitations = rawFact['citations'];
          if (text is! String ||
              rawCitations is! List<Object?> ||
              rawCitations.isEmpty ||
              rawCitations.length > 256) {
            throw const FormatException('Invalid AI checkpoint fact values');
          }
          final citations = <ParagraphCitation>[];
          for (final rawCitation in rawCitations) {
            if (rawCitation is! Map<String, Object?> ||
                !_hasExactKeys(rawCitation, const <String>{
                  'articleId',
                  'paragraphStart',
                  'paragraphEnd',
                })) {
              throw const FormatException('Invalid AI checkpoint citation');
            }
            final citationArticleId = rawCitation['articleId'];
            final citationStart = rawCitation['paragraphStart'];
            final citationEnd = rawCitation['paragraphEnd'];
            if (citationArticleId is! String ||
                citationStart is! int ||
                citationEnd is! int) {
              throw const FormatException(
                'Invalid AI checkpoint citation values',
              );
            }
            citations.add(
              ParagraphCitation(
                articleId: citationArticleId,
                paragraphStart: citationStart,
                paragraphEnd: citationEnd,
              ),
            );
          }
          facts.add(SourcedArticleFact(text: text, citations: citations));
        }
        if (completed.containsKey(index)) {
          throw const FormatException('Duplicate AI checkpoint chunk');
        }
        completed[index] = AiChunkSummary(
          articleId: chunkArticleId,
          chunkIndex: chunkIndex,
          paragraphStart: paragraphStart,
          paragraphEnd: paragraphEnd,
          facts: facts,
          topics: _checkpointStrings(rawChunk['topics']),
          entities: _checkpointStrings(rawChunk['entities']),
          language: language,
        );
      }
      return AiLongSummaryCheckpoint(
        articleId: articleId,
        fingerprint: fingerprint,
        chunkCount: chunkCount,
        completedChunks: completed,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      );
    } on ArgumentError {
      throw const FormatException('Invalid AI checkpoint bounds');
    }
  }
}

final class MemoryAiLongSummaryCheckpointStore
    implements AiLongSummaryCheckpointStore {
  final Map<String, AiLongSummaryCheckpoint> _values =
      <String, AiLongSummaryCheckpoint>{};

  @override
  Future<void> clear(String articleId) async {
    _values.remove(articleId);
  }

  @override
  Future<AiLongSummaryCheckpoint?> read(String articleId) async =>
      _values[articleId];

  @override
  Future<void> write(AiLongSummaryCheckpoint checkpoint) async {
    _values[checkpoint.articleId] = checkpoint;
  }
}

abstract interface class AiTokenEstimator {
  int estimate(String text);
}

final class UnicodeAiTokenEstimator implements AiTokenEstimator {
  const UnicodeAiTokenEstimator();

  @override
  int estimate(String text) {
    var ideographs = 0;
    var other = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x3400 && rune <= 0x9fff) ||
          (rune >= 0x3040 && rune <= 0x30ff) ||
          (rune >= 0xac00 && rune <= 0xd7af)) {
        ideographs++;
      } else {
        other++;
      }
    }
    return math.max(1, ideographs + (other / 4).ceil());
  }
}

final class AiTokenPricing {
  const AiTokenPricing({
    required this.inputUsdPerMillion,
    required this.outputUsdPerMillion,
  })  : assert(inputUsdPerMillion >= 0),
        assert(outputUsdPerMillion >= 0);

  const AiTokenPricing.zero()
      : inputUsdPerMillion = 0,
        outputUsdPerMillion = 0;

  final double inputUsdPerMillion;
  final double outputUsdPerMillion;
}

final class AiCostEstimate {
  const AiCostEstimate({
    required this.providerCalls,
    required this.inputTokens,
    required this.outputTokens,
    required this.upperBoundUsd,
  });

  final int providerCalls;
  final int inputTokens;
  final int outputTokens;
  final double upperBoundUsd;

  @override
  String toString() => 'AiCostEstimate('
      'providerCalls: $providerCalls, '
      'inputTokens: $inputTokens, '
      'outputTokens: $outputTokens, '
      'upperBoundUsd: ${upperBoundUsd.toStringAsFixed(6)}'
      ')';
}

final class LongSummaryPreflight {
  LongSummaryPreflight({
    required Iterable<ArticleSummaryChunk> chunks,
    required this.estimate,
  }) : chunks = List<ArticleSummaryChunk>.unmodifiable(chunks);

  final List<ArticleSummaryChunk> chunks;
  final AiCostEstimate estimate;
}

final class LongArticleSummaryResult {
  LongArticleSummaryResult({
    required this.summary,
    required Iterable<SourcedArticleFact> sourcedFacts,
    required this.usage,
    required this.preflightEstimate,
    required this.resumedChunks,
    required this.omittedFacts,
    required this.checkpointCleanupPending,
    required this.cacheHit,
  }) : sourcedFacts = List<SourcedArticleFact>.unmodifiable(sourcedFacts);

  final ArticleSummary summary;
  final List<SourcedArticleFact> sourcedFacts;
  final AiTokenUsage usage;
  final AiCostEstimate preflightEstimate;
  final int resumedChunks;
  final int omittedFacts;
  final bool checkpointCleanupPending;
  final bool cacheHit;
}

enum AiLongSummaryFailureCode {
  tooManyChunks,
  contextBudgetExceeded,
  invalidChunkOutput,
}

final class AiLongSummaryFailure implements Exception {
  const AiLongSummaryFailure(this.code);

  final AiLongSummaryFailureCode code;

  @override
  String toString() => 'AiLongSummaryFailure(${code.name})';
}

final class LongArticleSummaryService {
  LongArticleSummaryService(
    this._provider, {
    required this.checkpoints,
    PromptRegistry? prompts,
    this.model = 'provider-default',
    this.outputLanguage = 'zh-CN',
    this.budget = const AiContextBudget(),
    this.pricing = const AiTokenPricing.zero(),
    this.artifacts,
    this.clock,
    AiSummaryRequestCoalescer? requests,
    AiTokenEstimator? tokenEstimator,
    ArticleSummaryChunkPlanner? planner,
  })  : prompts = prompts ?? PromptRegistry.standard(),
        _requests = requests ?? AiSummaryRequestCoalescer(),
        _tokenEstimator = tokenEstimator ?? const UnicodeAiTokenEstimator(),
        _planner = planner ?? const ArticleSummaryChunkPlanner() {
    if (model.trim().isEmpty || model.length > 200) {
      throw ArgumentError.value(model, 'model');
    }
    if (!ArticleSummarySchema.languageTag.hasMatch(outputLanguage)) {
      throw ArgumentError.value(outputLanguage, 'outputLanguage');
    }
    if ((artifacts == null) != (clock == null)) {
      throw ArgumentError('artifacts and clock must be supplied together');
    }
  }

  final AiProvider _provider;
  final AiLongSummaryCheckpointStore checkpoints;
  final PromptRegistry prompts;
  final String model;
  final String outputLanguage;
  final AiContextBudget budget;
  final AiTokenPricing pricing;
  final AiArtifactRepository? artifacts;
  final Clock? clock;
  final AiSummaryRequestCoalescer _requests;
  final AiTokenEstimator _tokenEstimator;
  final ArticleSummaryChunkPlanner _planner;

  LongSummaryPreflight preflight(Article article) {
    if (article.id.trim() != article.id ||
        article.id.isEmpty ||
        article.id.length > 240) {
      throw ArgumentError.value(article.id, 'article.id');
    }
    final content = normalizeSummaryContent(article.plainText ?? '');
    if (content.isEmpty) {
      throw ArgumentError.value(article.id, 'article', 'Article has no text');
    }
    final chunks = _planner.plan(
      articleId: article.id,
      content: content,
      budget: budget,
    );
    var inputTokens = 0;
    for (final chunk in chunks) {
      final prompt = _mapPrompt(chunk);
      _requirePromptBudget(
        prompt,
        budget.maxMapPromptCharacters,
        AiChunkSummarySchema.jsonSchema,
      );
      inputTokens += _promptTokens(
        prompt,
        AiChunkSummarySchema.jsonSchema,
      );
    }
    final reduceInputUpperBound = _tokenEstimator.estimate(
          List<String>.filled(budget.maxReducePromptCharacters, '界').join(),
        ) +
        _tokenEstimator.estimate(jsonEncode(ArticleSummarySchema.jsonSchema));
    inputTokens += reduceInputUpperBound * 2;
    final outputTokens =
        chunks.length * budget.mapOutputTokens + budget.reduceOutputTokens * 2;
    final upperBoundUsd = inputTokens * pricing.inputUsdPerMillion / 1000000 +
        outputTokens * pricing.outputUsdPerMillion / 1000000;
    return LongSummaryPreflight(
      chunks: chunks,
      estimate: AiCostEstimate(
        providerCalls: chunks.length + 2,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        upperBoundUsd: upperBoundUsd,
      ),
    );
  }

  Future<LongArticleSummaryResult> summarize(Article article) {
    final plan = preflight(article);
    final (content, identity) = _cacheIdentityFor(article);
    return _requests.run(
      identity.cacheKey,
      () => _summarize(article, content, plan, identity),
    );
  }

  /// Reads a previously validated long-article result without provider calls.
  Future<LongArticleSummaryResult?> readCached(Article article) {
    final plan = preflight(article);
    final (_, identity) = _cacheIdentityFor(article);
    return _readCached(article, identity, plan);
  }

  (String, SummaryCacheIdentity) _cacheIdentityFor(Article article) {
    final content = normalizeSummaryContent(article.plainText ?? '');
    final identity = SummaryCacheIdentity(
      contentHash: summaryContentHash(content),
      model: model,
      promptVersion: prompts.resolve('article-summary-reduce', 1).versionKey,
      language: outputLanguage,
    );
    return (content, identity);
  }

  Future<LongArticleSummaryResult> _summarize(
    Article article,
    String content,
    LongSummaryPreflight plan,
    SummaryCacheIdentity identity,
  ) async {
    final cached = await _readCached(article, identity, plan);
    if (cached != null) return cached;

    final fingerprint = _fingerprint(article, content);
    final saved = await checkpoints.read(article.id);
    final completed = _resumableChunks(
      saved,
      fingerprint: fingerprint,
      chunks: plan.chunks,
    );
    final resumedChunks = completed.length;
    var inputTokens = completed.isEmpty ? 0 : saved!.inputTokens;
    var outputTokens = completed.isEmpty ? 0 : saved!.outputTokens;
    var providerCalls = completed.length;

    for (final chunk in plan.chunks) {
      if (completed.containsKey(chunk.index)) continue;
      final prompt = _mapPrompt(chunk);
      final response = await _provider.complete(
        AiProviderRequest(
          operationId: '${article.id}:map:${chunk.index}',
          model: model,
          prompt: prompt,
          responseSchema: AiChunkSummarySchema.jsonSchema,
          maxOutputTokens: budget.mapOutputTokens,
        ),
      );
      providerCalls++;
      inputTokens += response.usage.inputTokens;
      outputTokens += response.usage.outputTokens;
      completed[chunk.index] = const AiChunkSummarySchema().parse(
        response.output,
        expectedChunk: chunk,
        expectedLanguage: outputLanguage,
      );
      await checkpoints.write(
        AiLongSummaryCheckpoint(
          articleId: article.id,
          fingerprint: fingerprint,
          chunkCount: plan.chunks.length,
          completedChunks: completed,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        ),
      );
    }

    final summaries = <AiChunkSummary>[
      for (var index = 0; index < plan.chunks.length; index++)
        completed[index]!,
    ];
    final allFacts = _mergeFacts(
      summaries.expand((summary) => summary.facts),
    );
    final reduceFacts = _selectReduceFacts(
      article,
      summaries,
      allFacts,
      content,
    );
    final reducePrompt = _reducePrompt(article, reduceFacts, content);
    final response = await _provider.complete(
      AiProviderRequest(
        operationId: '${article.id}:reduce',
        model: model,
        prompt: reducePrompt,
        responseSchema: ArticleSummarySchema.jsonSchema,
        maxOutputTokens: budget.reduceOutputTokens,
      ),
    );
    providerCalls++;
    inputTokens += response.usage.inputTokens;
    outputTokens += response.usage.outputTokens;

    ArticleSummary summary;
    try {
      summary = _parseFinal(response, reducePrompt.versionKey);
    } on AiSchemaFailure catch (failure) {
      final repair = prompts.resolve('article-summary-repair', 1).render(
        <String, String>{
          'language': outputLanguage,
          'failureCode': failure.code.name,
          'invalidOutput': response.output,
        },
      );
      final repaired = await _provider.complete(
        AiProviderRequest(
          operationId: '${article.id}:reduce:repair',
          model: model,
          prompt: repair,
          responseSchema: ArticleSummarySchema.jsonSchema,
          maxOutputTokens: budget.reduceOutputTokens,
        ),
      );
      providerCalls++;
      inputTokens += repaired.usage.inputTokens;
      outputTokens += repaired.usage.outputTokens;
      summary = _parseFinal(repaired, reducePrompt.versionKey);
    }
    var checkpointCleanupPending = false;
    try {
      await checkpoints.clear(article.id);
    } on Object {
      checkpointCleanupPending = true;
    }
    final result = LongArticleSummaryResult(
      summary: summary,
      sourcedFacts: reduceFacts,
      usage: AiTokenUsage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ),
      preflightEstimate: plan.estimate,
      resumedChunks: resumedChunks,
      omittedFacts: allFacts.length - reduceFacts.length,
      checkpointCleanupPending: checkpointCleanupPending,
      cacheHit: false,
    );
    await _writeCached(
      article: article,
      identity: identity,
      result: result,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      providerCalls: providerCalls,
    );
    return result;
  }

  Future<LongArticleSummaryResult?> _readCached(
    Article article,
    SummaryCacheIdentity identity,
    LongSummaryPreflight plan,
  ) async {
    final repository = artifacts;
    if (repository == null) return null;
    AiArtifact? artifact;
    try {
      artifact = await repository.read(identity.cacheKey);
    } on FormatException {
      await _deleteInvalidCache(identity.cacheKey);
      return null;
    } on ArgumentError {
      await _deleteInvalidCache(identity.cacheKey);
      return null;
    } on Object {
      return null;
    }
    if (artifact == null) return null;
    if (!identity.matches(artifact, AiArtifactType.longArticleSummary)) {
      await _deleteInvalidCache(identity.cacheKey);
      return null;
    }
    try {
      final decoded = _decodeLongCache(
        artifact,
        expectedArticleId: article.id,
      );
      return LongArticleSummaryResult(
        summary: decoded.summary,
        sourcedFacts: decoded.sourcedFacts,
        usage: AiTokenUsage(inputTokens: 0, outputTokens: 0),
        preflightEstimate: plan.estimate,
        resumedChunks: 0,
        omittedFacts: decoded.omittedFacts,
        checkpointCleanupPending: false,
        cacheHit: true,
      );
    } on FormatException {
      await _deleteInvalidCache(identity.cacheKey);
      return null;
    } on AiSchemaFailure {
      await _deleteInvalidCache(identity.cacheKey);
      return null;
    } on ArgumentError {
      await _deleteInvalidCache(identity.cacheKey);
      return null;
    }
  }

  Future<void> _writeCached({
    required Article article,
    required SummaryCacheIdentity identity,
    required LongArticleSummaryResult result,
    required int inputTokens,
    required int outputTokens,
    required int providerCalls,
  }) async {
    final repository = artifacts;
    if (repository == null) return;
    final costUsd = inputTokens * pricing.inputUsdPerMillion / 1000000 +
        outputTokens * pricing.outputUsdPerMillion / 1000000;
    try {
      await repository.write(
        AiArtifact(
          cacheKey: identity.cacheKey,
          articleId: article.id,
          type: AiArtifactType.longArticleSummary,
          requestModel: model,
          resolvedModel: result.summary.model,
          promptVersion: identity.promptVersion,
          language: outputLanguage,
          contentHash: identity.contentHash,
          structuredResult: _encodeLongCache(result),
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          providerCalls: providerCalls,
          costUsd: costUsd,
          createdAt: clock!.now().toUtc(),
        ),
      );
    } on Object {
      // A valid summary remains usable if local cache persistence degrades.
    }
  }

  Future<void> _deleteInvalidCache(String cacheKey) async {
    try {
      await artifacts!.delete(cacheKey);
    } on Object {
      // A malformed value is never returned even if cleanup is deferred.
    }
  }

  AiPrompt _mapPrompt(ArticleSummaryChunk chunk) =>
      prompts.resolve('article-summary-map', 1).render(
        <String, String>{
          'articleId': chunk.articleId,
          'chunkIndex': '${chunk.index}',
          'paragraphStart': '${chunk.paragraphStart}',
          'paragraphEnd': '${chunk.paragraphEnd}',
          'language': outputLanguage,
          'content': chunk.text,
        },
      );

  AiPrompt _reducePrompt(
    Article article,
    Iterable<SourcedArticleFact> facts,
    String content,
  ) =>
      prompts.resolve('article-summary-reduce', 1).render(
        <String, String>{
          'articleId': article.id,
          'title': article.title,
          'language': outputLanguage,
          'estimatedReadingMinutes': '${_readingMinutes(content)}',
          'sourcedFacts': jsonEncode(
            facts.map((fact) => fact.toJson()).toList(growable: false),
          ),
        },
      );

  List<SourcedArticleFact> _selectReduceFacts(
    Article article,
    List<AiChunkSummary> summaries,
    List<SourcedArticleFact> allFacts,
    String content,
  ) {
    final selected = <String, SourcedArticleFact>{};
    for (final summary in summaries) {
      final fact = summary.facts.first;
      selected.update(
        _factKey(fact.text),
        (existing) => _combineFact(existing, fact),
        ifAbsent: () => fact,
      );
    }
    var prompt = _reducePrompt(article, selected.values, content);
    if (!_fitsPrompt(
      prompt,
      budget.maxReducePromptCharacters,
      ArticleSummarySchema.jsonSchema,
    )) {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.contextBudgetExceeded,
      );
    }
    for (final fact in allFacts) {
      final key = _factKey(fact.text);
      final previous = selected[key];
      selected[key] = previous == null ? fact : _combineFact(previous, fact);
      final candidate = _reducePrompt(article, selected.values, content);
      if (!_fitsPrompt(
        candidate,
        budget.maxReducePromptCharacters,
        ArticleSummarySchema.jsonSchema,
      )) {
        if (previous == null) {
          selected.remove(key);
        } else {
          selected[key] = previous;
        }
        continue;
      }
      prompt = candidate;
    }
    _requirePromptBudget(
      prompt,
      budget.maxReducePromptCharacters,
      ArticleSummarySchema.jsonSchema,
    );
    return List<SourcedArticleFact>.unmodifiable(selected.values);
  }

  ArticleSummary _parseFinal(
    AiProviderResponse response,
    String promptVersion,
  ) =>
      const ArticleSummarySchema().parse(
        response.output,
        model: response.model,
        promptVersion: promptVersion,
        expectedLanguage: outputLanguage,
      );

  int _promptTokens(AiPrompt prompt, Map<String, Object?> schema) =>
      _tokenEstimator.estimate(prompt.system) +
      _tokenEstimator.estimate(prompt.user) +
      _tokenEstimator.estimate(jsonEncode(schema));

  bool _fitsPrompt(
    AiPrompt prompt,
    int maximum,
    Map<String, Object?> schema,
  ) {
    if (prompt.system.length + prompt.user.length > maximum) return false;
    final envelope = jsonEncode(
      <String, Object?>{
        'messages': <Map<String, String>>[
          <String, String>{'role': 'system', 'content': prompt.system},
          <String, String>{'role': 'user', 'content': prompt.user},
        ],
        'responseSchema': schema,
      },
    );
    return utf8.encode(envelope).length <= budget.maxRequestBytes;
  }

  void _requirePromptBudget(
    AiPrompt prompt,
    int maximum,
    Map<String, Object?> schema,
  ) {
    if (!_fitsPrompt(prompt, maximum, schema)) {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.contextBudgetExceeded,
      );
    }
  }

  int _readingMinutes(String content) {
    var ideographs = 0;
    for (final rune in content.runes) {
      if (rune >= 0x3400 && rune <= 0x9fff) ideographs++;
    }
    final latinWords =
        RegExp(r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*").allMatches(content).length;
    return math.max(1, (ideographs / 400 + latinWords / 220).ceil());
  }

  String _fingerprint(Article article, String content) => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, Object>{
            'articleId': article.id,
            'title': article.title,
            'content': content,
            'model': model,
            'language': outputLanguage,
            'mapPrompt': 'article-summary-map@1',
            'reducePrompt': 'article-summary-reduce@1',
            'mapContentCharacters': budget.mapContentCharacters,
            'overlapParagraphs': budget.overlapParagraphs,
            'maxChunks': budget.maxChunks,
            'maxMapPromptCharacters': budget.maxMapPromptCharacters,
            'maxReducePromptCharacters': budget.maxReducePromptCharacters,
            'maxRequestBytes': budget.maxRequestBytes,
            'mapOutputTokens': budget.mapOutputTokens,
            'reduceOutputTokens': budget.reduceOutputTokens,
          }),
        ),
      )
      .toString();

  Map<int, AiChunkSummary> _resumableChunks(
    AiLongSummaryCheckpoint? saved, {
    required String fingerprint,
    required List<ArticleSummaryChunk> chunks,
  }) {
    if (saved == null ||
        saved.fingerprint != fingerprint ||
        saved.chunkCount != chunks.length) {
      return <int, AiChunkSummary>{};
    }
    for (final entry in saved.completedChunks.entries) {
      final chunk = chunks[entry.key];
      final summary = entry.value;
      if (summary.articleId != chunk.articleId ||
          summary.chunkIndex != chunk.index ||
          summary.paragraphStart != chunk.paragraphStart ||
          summary.paragraphEnd != chunk.paragraphEnd ||
          summary.language != outputLanguage) {
        return <int, AiChunkSummary>{};
      }
    }
    return <int, AiChunkSummary>{...saved.completedChunks};
  }
}

const _longCacheSchema = 'river.long-article-summary-cache.v1';

String _encodeLongCache(LongArticleSummaryResult result) {
  final summary = jsonDecode(
    const ArticleSummaryCacheCodec().encode(result.summary),
  );
  return jsonEncode(<String, Object?>{
    'schemaVersion': _longCacheSchema,
    'summary': summary,
    'sourcedFacts': result.sourcedFacts
        .map((fact) => fact.toJson())
        .toList(growable: false),
    'omittedFacts': result.omittedFacts,
  });
}

_LongCachePayload _decodeLongCache(
  AiArtifact artifact, {
  required String expectedArticleId,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(artifact.structuredResult);
  } on FormatException {
    throw const FormatException('Invalid long-summary cache JSON');
  }
  if (decoded is! Map<String, Object?> ||
      !_hasExactKeys(decoded, const <String>{
        'schemaVersion',
        'summary',
        'sourcedFacts',
        'omittedFacts',
      }) ||
      decoded['schemaVersion'] != _longCacheSchema) {
    throw const FormatException('Unsupported long-summary cache schema');
  }
  final rawSummary = decoded['summary'];
  final rawFacts = decoded['sourcedFacts'];
  final omittedFacts = decoded['omittedFacts'];
  if (rawSummary is! Map<String, Object?> ||
      rawFacts is! List<Object?> ||
      rawFacts.isEmpty ||
      rawFacts.length > 1280 ||
      omittedFacts is! int ||
      omittedFacts < 0) {
    throw const FormatException('Invalid long-summary cache envelope');
  }
  final summary = const ArticleSummarySchema().parse(
    jsonEncode(rawSummary),
    model: artifact.resolvedModel,
    promptVersion: artifact.promptVersion,
    expectedLanguage: artifact.language,
  );
  final facts = <SourcedArticleFact>[];
  for (final rawFact in rawFacts) {
    if (rawFact is! Map<String, Object?> ||
        !_hasExactKeys(rawFact, const <String>{'text', 'citations'})) {
      throw const FormatException('Invalid long-summary cached fact');
    }
    final text = rawFact['text'];
    final rawCitations = rawFact['citations'];
    if (text is! String ||
        rawCitations is! List<Object?> ||
        rawCitations.isEmpty ||
        rawCitations.length > 256) {
      throw const FormatException('Invalid long-summary cached fact values');
    }
    final citations = <ParagraphCitation>[];
    for (final rawCitation in rawCitations) {
      if (rawCitation is! Map<String, Object?> ||
          !_hasExactKeys(rawCitation, const <String>{
            'articleId',
            'paragraphStart',
            'paragraphEnd',
          })) {
        throw const FormatException('Invalid long-summary cached citation');
      }
      final articleId = rawCitation['articleId'];
      final paragraphStart = rawCitation['paragraphStart'];
      final paragraphEnd = rawCitation['paragraphEnd'];
      if (articleId is! String ||
          articleId.trim().isEmpty ||
          paragraphStart is! int ||
          paragraphEnd is! int) {
        throw const FormatException(
          'Invalid long-summary cached citation values',
        );
      }
      citations.add(
        ParagraphCitation(
          articleId: expectedArticleId,
          paragraphStart: paragraphStart,
          paragraphEnd: paragraphEnd,
        ),
      );
    }
    facts.add(SourcedArticleFact(text: text, citations: citations));
  }
  return _LongCachePayload(
    summary: summary,
    sourcedFacts: facts,
    omittedFacts: omittedFacts,
  );
}

final class _LongCachePayload {
  _LongCachePayload({
    required this.summary,
    required Iterable<SourcedArticleFact> sourcedFacts,
    required this.omittedFacts,
  }) : sourcedFacts = List<SourcedArticleFact>.unmodifiable(sourcedFacts);

  final ArticleSummary summary;
  final List<SourcedArticleFact> sourcedFacts;
  final int omittedFacts;
}

List<SourcedArticleFact> _mergeFacts(
  Iterable<SourcedArticleFact> facts,
) {
  final merged = <String, SourcedArticleFact>{};
  for (final fact in facts) {
    merged.update(
      _factKey(fact.text),
      (existing) => _combineFact(existing, fact),
      ifAbsent: () => fact,
    );
  }
  return List<SourcedArticleFact>.unmodifiable(merged.values);
}

SourcedArticleFact _combineFact(
  SourcedArticleFact left,
  SourcedArticleFact right,
) =>
    SourcedArticleFact(
      text: left.text,
      citations: <ParagraphCitation>{
        ...left.citations,
        ...right.citations,
      },
    );

String _factKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _hasExactKeys(Map<String, Object?> value, Set<String> expected) =>
    value.length == expected.length &&
    value.keys.every(expected.contains) &&
    expected.every(value.containsKey);

bool _isBoundedDistinctStrings(
  List<String> values,
  int maximum,
  int maxLength,
) =>
    values.length <= maximum &&
    values.toSet().length == values.length &&
    values.every(
      (value) =>
          value.trim() == value &&
          value.isNotEmpty &&
          value.length <= maxLength,
    );

List<String> _boundedStrings(Object? value, int maximum, int maxLength) {
  if (value is! List<Object?> || value.length > maximum) {
    throw const AiLongSummaryFailure(
      AiLongSummaryFailureCode.invalidChunkOutput,
    );
  }
  final result = <String>[];
  for (final item in value) {
    if (item is! String ||
        item.trim() != item ||
        item.isEmpty ||
        item.length > maxLength ||
        result.contains(item)) {
      throw const AiLongSummaryFailure(
        AiLongSummaryFailureCode.invalidChunkOutput,
      );
    }
    result.add(item);
  }
  return List<String>.unmodifiable(result);
}

List<String> _checkpointStrings(Object? value) {
  if (value is! List<Object?> || value.any((item) => item is! String)) {
    throw const FormatException('Invalid AI checkpoint string list');
  }
  return value.cast<String>();
}

List<String> _paragraphs(String value) {
  final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  var paragraphs = normalized
      .split(RegExp(r'\n[ \t]*\n+'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList(growable: false);
  if (paragraphs.length == 1 && normalized.contains('\n')) {
    paragraphs = normalized
        .split(RegExp(r'\n+'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
  }
  return paragraphs;
}

List<String> _splitBounded(String value, int maximum) {
  if (value.length <= maximum) return <String>[value];
  final result = <String>[];
  var offset = 0;
  while (offset < value.length) {
    var end = math.min(value.length, offset + maximum);
    if (end < value.length &&
        _isHighSurrogate(value.codeUnitAt(end - 1)) &&
        _isLowSurrogate(value.codeUnitAt(end))) {
      end--;
    }
    if (end < value.length) {
      final searchStart = offset + (maximum * 0.7).floor();
      for (var candidate = end; candidate >= searchStart; candidate--) {
        if (RegExp(r'[\s。！？.!?；;]').hasMatch(value[candidate - 1])) {
          end = candidate;
          break;
        }
      }
    }
    result.add(value.substring(offset, end).trim());
    offset = end;
    while (offset < value.length && value[offset].trim().isEmpty) {
      offset++;
    }
  }
  return result.where((part) => part.isNotEmpty).toList(growable: false);
}

bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;

bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

final class _ParagraphPiece {
  const _ParagraphPiece(this.paragraphIndex, this.text);

  final int paragraphIndex;
  final String text;
}

final class _PieceRange {
  const _PieceRange(this.start, this.end);

  final int start;
  final int end;
}
