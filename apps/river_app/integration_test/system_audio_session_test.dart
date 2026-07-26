import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('publishes and clears a real Windows system media session',
      (tester) async {
    if (!Platform.isWindows) return;
    final session = await SystemAudioSession.create();

    expect(await session.activate(), isTrue);
    await session.publish(
      AudioSystemPlaybackState(
        item: AudioItem(
          id: 'smoke-article',
          kind: AudioKind.articleTts,
          title: 'River system media controls smoke',
          sourceUri: Uri.parse('river://article/smoke'),
        ),
        phase: AudioEnginePhase.playing,
        position: const AudioPlaybackPosition.speech(segmentIndex: 0),
        settings: const AudioPlaybackSettings(rate: 1.25),
        canSkipPrevious: false,
        canSkipNext: true,
      ),
    );
    await tester.pump();
    await session.deactivate();
    await session.clear();
    await session.dispose();
  });
}
