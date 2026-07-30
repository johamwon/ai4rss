import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips, replaces, and deletes a validated artifact', () async {
    final database = RiverDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAiArtifactRepository(database);

    await repository.write(_artifact(inputTokens: 100));
    final first = await repository.read(_cacheKey);

    expect(first, isNotNull);
    expect(first!.articleId, 'article-1');
    expect(first.type, AiArtifactType.articleSummary);
    expect(first.inputTokens, 100);
    expect(first.structuredResult, '{"schemaVersion":"test"}');
    expect(first.toString(), isNot(contains(first.structuredResult)));

    await repository.write(_artifact(inputTokens: 80));
    expect((await repository.read(_cacheKey))!.inputTokens, 80);

    await repository.delete(_cacheKey);
    expect(await repository.read(_cacheKey), isNull);
  });

  test('persists across a database restart', () async {
    final directory = await Directory.systemTemp.createTemp('river-ai-cache-');
    final file = File('${directory.path}${Platform.pathSeparator}river.sqlite');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    var database = RiverDatabase(NativeDatabase(file));
    await DriftAiArtifactRepository(database).write(_artifact());
    await database.close();

    database = RiverDatabase(NativeDatabase(file));
    final restored = await DriftAiArtifactRepository(database).read(_cacheKey);
    await database.close();

    expect(restored, isNotNull);
    expect(restored!.createdAt, DateTime.utc(2026, 7, 30, 12));
    expect(restored.providerCalls, 1);
  });
}

const _cacheKey =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

AiArtifact _artifact({int inputTokens = 100}) => AiArtifact(
  cacheKey: _cacheKey,
  articleId: 'article-1',
  type: AiArtifactType.articleSummary,
  requestModel: 'model-v1',
  resolvedModel: 'model-v1-20260730',
  promptVersion: 'article-summary@1',
  language: 'zh-CN',
  contentHash:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  structuredResult: '{"schemaVersion":"test"}',
  inputTokens: inputTokens,
  outputTokens: 40,
  providerCalls: 1,
  costUsd: 0.0003,
  createdAt: DateTime.utc(2026, 7, 30, 12),
);
