import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftAiArtifactRepository implements domain.AiArtifactRepository {
  const DriftAiArtifactRepository(this._database);

  final RiverDatabase _database;

  @override
  Future<void> delete(String cacheKey) async {
    await (_database.delete(
      _database.aiArtifacts,
    )..where((row) => row.cacheKey.equals(cacheKey))).go();
  }

  @override
  Future<domain.AiArtifact?> read(String cacheKey) async {
    final row =
        await (_database.select(_database.aiArtifacts)
              ..where((candidate) => candidate.cacheKey.equals(cacheKey)))
            .getSingleOrNull();
    if (row == null) return null;
    return domain.AiArtifact(
      cacheKey: row.cacheKey,
      articleId: row.articleId,
      type: domain.AiArtifactType.values.byName(row.artifactType),
      requestModel: row.requestModel,
      resolvedModel: row.resolvedModel,
      promptVersion: row.promptVersion,
      language: row.language,
      contentHash: row.contentHash,
      structuredResult: row.structuredResult,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      providerCalls: row.providerCalls,
      costUsd: row.costUsd,
      createdAt: row.createdAt.toUtc(),
    );
  }

  @override
  Future<void> write(domain.AiArtifact artifact) async {
    await _database
        .into(_database.aiArtifacts)
        .insertOnConflictUpdate(
          AiArtifactsCompanion.insert(
            cacheKey: artifact.cacheKey,
            articleId: artifact.articleId,
            artifactType: artifact.type.name,
            requestModel: artifact.requestModel,
            resolvedModel: artifact.resolvedModel,
            promptVersion: artifact.promptVersion,
            language: artifact.language,
            contentHash: artifact.contentHash,
            structuredResult: artifact.structuredResult,
            inputTokens: artifact.inputTokens,
            outputTokens: artifact.outputTokens,
            providerCalls: artifact.providerCalls,
            costUsd: artifact.costUsd,
            createdAt: artifact.createdAt.toUtc(),
          ),
        );
  }
}
