import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('system TTS lists a voice and completes a short utterance', (
    tester,
  ) async {
    final engine = SystemTtsAudioEngine();
    addTearDown(engine.dispose);

    final capabilities = await engine.capabilities();
    expect(capabilities.supportsArticleTts, isTrue);
    expect(capabilities.supportsPodcastMedia, isFalse);
    expect(await engine.voices(), isNotEmpty);

    await engine.load(
      AudioLoadRequest(
        item: AudioItem(
          id: 'system-tts-smoke',
          kind: AudioKind.articleTts,
          title: 'System TTS smoke',
          sourceUri: Uri.parse('river://article/system-tts-smoke'),
        ),
        contentRevision: 'smoke-v1',
        speechSegments: const <SpeechSegment>[
          SpeechSegment(
            index: 0,
            text: 'River text to speech smoke test.',
            sourceStart: 0,
            sourceEnd: 32,
            languageTag: 'en-US',
          ),
        ],
      ),
    );
    await engine.updateSettings(const AudioPlaybackSettings());
    final terminal = engine.events.firstWhere(
      (event) =>
          event.phase == AudioEnginePhase.completed ||
          event.phase == AudioEnginePhase.failed,
    );
    await engine.play();
    final event = await terminal.timeout(const Duration(seconds: 20));

    expect(event.phase, AudioEnginePhase.completed);
    expect(event.failureCode, isNull);
    expect(event.position?.segmentIndex, 0);
  });
}
