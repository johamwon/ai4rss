import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('checkpoint survives a new store instance and clears explicitly',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('river-ai-checkpoint-');
    try {
      final first = PlatformAiLongSummaryCheckpointStore(
        directoryProvider: () async => directory,
      );
      await first.write(_checkpoint());

      final restarted = PlatformAiLongSummaryCheckpointStore(
        directoryProvider: () async => directory,
      );
      final restored = await restarted.read('article-1');

      expect(restored, isNotNull);
      expect(restored!.fingerprint, List<String>.filled(64, 'a').join());
      expect(restored.completedChunks.keys, <int>[0]);
      expect(restored.completedChunks[0]!.facts.single.text, 'bounded fact');
      expect(restored.inputTokens, 25);
      expect(restored.outputTokens, 10);
      await restarted.clear('article-1');
      expect(await first.read('article-1'), isNull);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('corrupt checkpoints fail without silent deletion', () async {
    final directory =
        await Directory.systemTemp.createTemp('river-ai-checkpoint-corrupt-');
    try {
      final store = PlatformAiLongSummaryCheckpointStore(
        directoryProvider: () async => directory,
      );
      await store.write(_checkpoint());
      final file = directory.listSync().whereType<File>().single;
      await file.writeAsString('{"schemaVersion":999}', flush: true);

      await expectLater(
        store.read('article-1'),
        throwsA(
          isA<AiLongSummaryStorageException>().having(
            (failure) => failure.code,
            'code',
            AiLongSummaryStorageFailureCode.corruptValue,
          ),
        ),
      );
      expect(await file.exists(), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

AiLongSummaryCheckpoint _checkpoint() => AiLongSummaryCheckpoint(
      articleId: 'article-1',
      fingerprint: List<String>.filled(64, 'a').join(),
      chunkCount: 2,
      completedChunks: <int, AiChunkSummary>{
        0: AiChunkSummary(
          articleId: 'article-1',
          chunkIndex: 0,
          paragraphStart: 0,
          paragraphEnd: 1,
          facts: <SourcedArticleFact>[
            SourcedArticleFact(
              text: 'bounded fact',
              citations: <ParagraphCitation>[
                ParagraphCitation(
                  articleId: 'article-1',
                  paragraphStart: 0,
                  paragraphEnd: 1,
                ),
              ],
            ),
          ],
          topics: const <String>['RSS'],
          entities: const <String>['River'],
          language: 'en-US',
        ),
      },
      inputTokens: 25,
      outputTokens: 10,
    );
