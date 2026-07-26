import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

final class _Backend implements PodcastPlayerBackend {
  final StreamController<PodcastPlayerEvent> controller =
      StreamController<PodcastPlayerEvent>.broadcast(sync: true);
  Uri? source;
  Duration? seekPosition;
  double? speed;
  var plays = 0;
  var pauses = 0;
  var stops = 0;

  @override
  Stream<PodcastPlayerEvent> get events => controller.stream;

  @override
  Future<void> setSource(Uri source) async => this.source = source;

  @override
  Future<void> play() async => plays += 1;

  @override
  Future<void> pause() async => pauses += 1;

  @override
  Future<void> stop() async => stops += 1;

  @override
  Future<void> seek(Duration position) async => seekPosition = position;

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> dispose() => controller.close();
}

void main() {
  test('streams a podcast and maps position, controls, and speed', () async {
    final backend = _Backend();
    final engine = PodcastAudioEngine(backend: backend);
    final events = <AudioEngineEvent>[];
    final subscription = engine.events.listen(events.add);
    final request = _podcastRequest(
      Uri.parse('https://media.example.test/episode.mp3'),
    );

    await engine.load(request);
    await engine.play();
    await engine.pause();
    await engine.resume();
    await engine.seek(
      AudioPlaybackPosition.media(const Duration(minutes: 5)),
    );
    await engine.updateSettings(
      const AudioPlaybackSettings(rate: 1.75),
    );
    backend.controller.add(
      const PodcastPlayerEvent(
        phase: PodcastPlayerPhase.playing,
        position: Duration(minutes: 5),
      ),
    );

    expect(backend.source, request.item.sourceUri);
    expect(backend.plays, 2);
    expect(backend.pauses, 1);
    expect(backend.seekPosition, const Duration(minutes: 5));
    expect(backend.speed, 1.75);
    expect(events.last.phase, AudioEnginePhase.playing);
    expect(
      events.last.position?.mediaPosition,
      const Duration(minutes: 5),
    );
    final capabilities = await engine.capabilities();
    expect(capabilities.supportsPodcastMedia, isTrue);
    expect(capabilities.supportsArticleTts, isFalse);
    await subscription.cancel();
    await engine.dispose();
  });

  test('fails closed for article, credentialed, and speech requests', () async {
    final backend = _Backend();
    final engine = PodcastAudioEngine(backend: backend);

    expect(
      () => engine.load(
        AudioLoadRequest(
          item: AudioItem(
            id: 'article',
            kind: AudioKind.articleTts,
            title: 'Article',
            sourceUri: Uri.parse('https://example.test/article'),
          ),
          speechSegments: const <SpeechSegment>[
            SpeechSegment(
              index: 0,
              text: 'Sentence.',
              sourceStart: 0,
              sourceEnd: 9,
            ),
          ],
          contentRevision: 'revision',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.load(
        _podcastRequest(
          Uri.parse('https://user:secret@example.test/episode.mp3'),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.seek(
        const AudioPlaybackPosition.speech(segmentIndex: 0),
      ),
      throwsArgumentError,
    );
    await engine.dispose();
  });
}

AudioLoadRequest _podcastRequest(Uri source) => AudioLoadRequest(
      item: AudioItem(
        id: 'episode',
        kind: AudioKind.podcastEpisode,
        title: 'Episode',
        sourceUri: source,
      ),
    );
