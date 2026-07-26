import 'models.dart';

enum SpeechSegmentKind { prose, codePlaceholder }

final class SpeechSegment {
  const SpeechSegment({
    required this.index,
    required this.text,
    required this.sourceStart,
    required this.sourceEnd,
    this.kind = SpeechSegmentKind.prose,
    this.languageTag,
  })  : assert(index >= 0),
        assert(text.length > 0),
        assert(sourceStart >= 0),
        assert(sourceEnd > sourceStart);

  final int index;
  final String text;
  final int sourceStart;
  final int sourceEnd;
  final SpeechSegmentKind kind;
  final String? languageTag;
}

final class AudioLoadRequest {
  AudioLoadRequest({
    required this.item,
    List<SpeechSegment> speechSegments = const <SpeechSegment>[],
    this.contentRevision,
  })  : speechSegments = List<SpeechSegment>.unmodifiable(speechSegments),
        assert(
          item.kind != AudioKind.articleTts || speechSegments.isNotEmpty,
          'Article TTS requires at least one speech segment.',
        ),
        assert(
          item.kind != AudioKind.articleTts ||
              (contentRevision != null && contentRevision.trim().isNotEmpty),
          'Article TTS requires a stable content revision.',
        ),
        assert(
          item.kind != AudioKind.podcastEpisode || speechSegments.isEmpty,
          'Podcast audio must not contain speech segments.',
        ),
        assert(
          speechSegments.indexed.every(
            (entry) => entry.$2.index == entry.$1,
          ),
          'Speech segment indexes must be contiguous and zero-based.',
        );

  final AudioItem item;
  final List<SpeechSegment> speechSegments;
  final String? contentRevision;
}

final class AudioPlaybackPosition {
  AudioPlaybackPosition.media(Duration position)
      : assert(!position.isNegative),
        mediaPosition = position,
        segmentIndex = null,
        characterOffset = null;

  const AudioPlaybackPosition.speech({
    required int segmentIndex,
    int characterOffset = 0,
  })  : assert(segmentIndex >= 0),
        assert(characterOffset >= 0),
        mediaPosition = null,
        segmentIndex = segmentIndex,
        characterOffset = characterOffset;

  final Duration? mediaPosition;
  final int? segmentIndex;
  final int? characterOffset;

  bool get isSpeech => segmentIndex != null;
}

final class AudioPlaybackSettings {
  const AudioPlaybackSettings({
    this.rate = 1,
    this.pitch = 1,
    this.voiceId,
    this.languageTag,
  })  : assert(rate >= 0.5 && rate <= 3),
        assert(pitch >= 0.5 && pitch <= 2),
        assert(voiceId == null || voiceId.length > 0),
        assert(languageTag == null || languageTag.length > 0);

  final double rate;
  final double pitch;
  final String? voiceId;
  final String? languageTag;
}

final class AudioVoice {
  const AudioVoice({
    required this.id,
    required this.name,
    required this.languageTag,
    required this.isLocal,
  })  : assert(id.length > 0),
        assert(name.length > 0),
        assert(languageTag.length > 0);

  final String id;
  final String name;
  final String languageTag;
  final bool isLocal;
}

final class AudioEngineCapabilities {
  const AudioEngineCapabilities({
    required this.canPause,
    required this.canResume,
    required this.canSeek,
    required this.canSetRate,
    required this.canSetPitch,
    required this.canSelectVoice,
  });

  final bool canPause;
  final bool canResume;
  final bool canSeek;
  final bool canSetRate;
  final bool canSetPitch;
  final bool canSelectVoice;
}

enum AudioEnginePhase {
  idle,
  loading,
  ready,
  playing,
  paused,
  stopped,
  completed,
  interrupted,
  failed,
}

final class AudioEngineEvent {
  const AudioEngineEvent({
    required this.phase,
    this.itemId,
    this.position,
    this.failureCode,
  }) : assert(
          (phase == AudioEnginePhase.failed) == (failureCode != null),
          'Only failed audio events carry a stable failure code.',
        );

  final AudioEnginePhase phase;
  final String? itemId;
  final AudioPlaybackPosition? position;
  final String? failureCode;
}
