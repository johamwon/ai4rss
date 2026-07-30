enum AiArtifactType {
  articleSummary,
  longArticleSummary,
}

final class AiArtifact {
  AiArtifact({
    required this.cacheKey,
    required this.articleId,
    required this.type,
    required this.requestModel,
    required this.resolvedModel,
    required this.promptVersion,
    required this.language,
    required this.contentHash,
    required this.structuredResult,
    required this.inputTokens,
    required this.outputTokens,
    required this.providerCalls,
    required this.costUsd,
    required this.createdAt,
  }) {
    if (!_cacheKey.hasMatch(cacheKey) ||
        articleId.trim() != articleId ||
        articleId.isEmpty ||
        articleId.length > 240 ||
        requestModel.trim() != requestModel ||
        requestModel.isEmpty ||
        requestModel.length > 200 ||
        resolvedModel.trim() != resolvedModel ||
        resolvedModel.isEmpty ||
        resolvedModel.length > 200 ||
        !_promptVersion.hasMatch(promptVersion) ||
        !_languageTag.hasMatch(language) ||
        !_contentHash.hasMatch(contentHash) ||
        structuredResult.isEmpty ||
        structuredResult.length > maxStructuredResultCharacters ||
        inputTokens < 0 ||
        outputTokens < 0 ||
        providerCalls < 0 ||
        providerCalls > 1024 ||
        !costUsd.isFinite ||
        costUsd < 0) {
      throw ArgumentError('Invalid AI artifact');
    }
  }

  static const maxStructuredResultCharacters = 1024 * 1024;
  static final RegExp _cacheKey = RegExp(r'^sha256:[a-f0-9]{64}$');
  static final RegExp _contentHash = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _promptVersion = RegExp(
    r'^[a-z][a-z0-9-]{0,79}@[1-9][0-9]{0,8}$',
  );
  static final RegExp _languageTag = RegExp(
    r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$',
  );

  final String cacheKey;
  final String articleId;
  final AiArtifactType type;
  final String requestModel;
  final String resolvedModel;
  final String promptVersion;
  final String language;
  final String contentHash;
  final String structuredResult;
  final int inputTokens;
  final int outputTokens;
  final int providerCalls;
  final double costUsd;
  final DateTime createdAt;

  @override
  String toString() => 'AiArtifact('
      'cacheKey: $cacheKey, '
      'articleId: $articleId, '
      'type: ${type.name}, '
      'requestModel: $requestModel, '
      'resolvedModel: $resolvedModel, '
      'promptVersion: $promptVersion, '
      'language: $language, '
      'structuredResultCharacters: ${structuredResult.length}, '
      'inputTokens: $inputTokens, '
      'outputTokens: $outputTokens, '
      'providerCalls: $providerCalls, '
      'costUsd: ${costUsd.toStringAsFixed(6)}'
      ')';
}

abstract interface class AiArtifactRepository {
  Future<AiArtifact?> read(String cacheKey);

  Future<void> write(AiArtifact artifact);

  Future<void> delete(String cacheKey);
}
