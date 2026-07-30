import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real app support storage resumes an AI map checkpoint',
      (tester) async {
    const articleId = 'river-ai-long-integration-v1';
    final first = PlatformAiLongSummaryCheckpointStore();
    await first.clear(articleId);
    addTearDown(() => first.clear(articleId));
    await first.write(_checkpoint(articleId));

    final restarted = PlatformAiLongSummaryCheckpointStore();
    final restored = await restarted.read(articleId);

    expect(restored, isNotNull);
    expect(restored!.completedChunks.keys, <int>[0]);
    expect(restored.completedChunks[0]!.facts.single.text, 'bounded fact');
    expect(restored.inputTokens, 25);
    expect(restored.outputTokens, 10);
    await restarted.clear(articleId);
    expect(await first.read(articleId), isNull);
  });
}

AiLongSummaryCheckpoint _checkpoint(String articleId) =>
    AiLongSummaryCheckpoint(
      articleId: articleId,
      fingerprint: List<String>.filled(64, 'b').join(),
      chunkCount: 2,
      completedChunks: <int, AiChunkSummary>{
        0: AiChunkSummary(
          articleId: articleId,
          chunkIndex: 0,
          paragraphStart: 0,
          paragraphEnd: 1,
          facts: <SourcedArticleFact>[
            SourcedArticleFact(
              text: 'bounded fact',
              citations: <ParagraphCitation>[
                ParagraphCitation(
                  articleId: articleId,
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
