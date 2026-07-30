import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

import 'summary_schema.dart';

final class SummaryCacheIdentity {
  SummaryCacheIdentity({
    required this.contentHash,
    required this.model,
    required this.promptVersion,
    required this.language,
  }) : cacheKey = summaryCacheKey(
          contentHash: contentHash,
          model: model,
          promptVersion: promptVersion,
          language: language,
        );

  final String contentHash;
  final String model;
  final String promptVersion;
  final String language;
  final String cacheKey;

  bool matches(AiArtifact artifact, AiArtifactType type) =>
      artifact.cacheKey == cacheKey &&
      artifact.type == type &&
      artifact.contentHash == contentHash &&
      artifact.requestModel == model &&
      artifact.promptVersion == promptVersion &&
      artifact.language == language;

  @override
  String toString() => 'SummaryCacheIdentity('
      'cacheKey: $cacheKey, '
      'model: $model, '
      'promptVersion: $promptVersion, '
      'language: $language'
      ')';
}

final class ArticleSummaryCacheCodec {
  const ArticleSummaryCacheCodec();

  String encode(ArticleSummary summary) => jsonEncode(
        <String, Object?>{
          'schemaVersion': ArticleSummarySchema.name,
          'oneLine': summary.oneLine,
          'keyPoints': summary.keyPoints,
          'whyItMatters': summary.whyItMatters,
          'topics': summary.topics,
          'entities': summary.entities,
          'estimatedReadingMinutes': summary.estimatedReadingMinutes,
          'language': summary.language,
        },
      );

  ArticleSummary decode(AiArtifact artifact) =>
      const ArticleSummarySchema().parse(
        artifact.structuredResult,
        model: artifact.resolvedModel,
        promptVersion: artifact.promptVersion,
        expectedLanguage: artifact.language,
      );
}

final class AiSummaryRequestCoalescer {
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  int get inFlight => _inFlight.length;

  Future<T> run<T>(String cacheKey, Future<T> Function() operation) {
    final existing = _inFlight[cacheKey];
    if (existing != null) {
      return existing.then((value) => value as T);
    }
    late final Future<T> task;
    task = Future<T>.sync(operation).whenComplete(() {
      if (identical(_inFlight[cacheKey], task)) {
        _inFlight.remove(cacheKey)?.ignore();
      }
    });
    _inFlight[cacheKey] = task;
    return task;
  }
}

String normalizeSummaryContent(String content) =>
    content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

String summaryContentHash(String content) =>
    sha256.convert(utf8.encode(normalizeSummaryContent(content))).toString();

String summaryCacheKey({
  required String contentHash,
  required String model,
  required String promptVersion,
  required String language,
}) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(contentHash) ||
      model.trim() != model ||
      model.isEmpty ||
      model.length > 200 ||
      !RegExp(r'^[a-z][a-z0-9-]{0,79}@[1-9][0-9]{0,8}$')
          .hasMatch(promptVersion) ||
      !ArticleSummarySchema.languageTag.hasMatch(language)) {
    throw ArgumentError('Invalid summary cache identity');
  }
  final canonical = jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'contentHash': contentHash,
    'model': model,
    'promptVersion': promptVersion,
    'language': language,
  });
  return 'sha256:${sha256.convert(utf8.encode(canonical))}';
}
