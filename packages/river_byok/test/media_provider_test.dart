import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_byok/river_byok.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('OpenAI-compatible TTS sends bounded request and accepts valid audio',
      () async {
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: const <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00],
        headers: const <String, String>{
          'content-type': 'audio/mpeg',
          'x-river-audio-duration-ms': '1250',
        },
      ),
    );
    final synthesizer = OpenAiCompatibleTtsSynthesizer(
      configuration: _configuration(ByokMediaCapability.tts),
      transport: transport,
    );
    final response = await synthesizer.synthesize(
      CloudTtsSynthesisRequest(
        operationId: 'tts-operation-1',
        text: '需要朗读的文章内容',
        profile: CloudTtsProfile(profileId: 'byok', version: 'v1'),
        settings: const AudioPlaybackSettings(
          rate: 1.25,
          voiceId: 'alloy',
          languageTag: 'zh-CN',
        ),
      ),
      AudioPrefetchCancellation(),
    );

    expect(response.audioDuration, const Duration(milliseconds: 1250));
    expect(response.costMicros, 0);
    expect(transport.requests.single.uri.path, '/v1/audio/speech');
    final body = jsonDecode(utf8.decode(transport.requests.single.body)) as Map;
    expect(body['model'], 'media-model');
    expect(body['voice'], 'alloy');
    expect(body['input'], '需要朗读的文章内容');
    expect(
      transport.requests.single.headers['authorization'],
      'Bearer provider-secret-key',
    );
    expect(transport.requests.single.toString(), isNot(contains('secret')));
  });

  test('Fish Audio TTS uses the vendor endpoint, model header and reference ID',
      () async {
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: const <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00],
        headers: const <String, String>{'content-type': 'audio/mpeg'},
      ),
    );
    final synthesizer = createByokTtsSynthesizer(
      configuration: _fishAudioConfiguration(voice: 'voice-model-id'),
      transport: transport,
    );

    await synthesizer.synthesize(
      CloudTtsSynthesisRequest(
        operationId: 'fish-tts-operation-1',
        text: 'Fish Audio 中文语音测试',
        profile: CloudTtsProfile(profileId: 'fish-audio', version: 's2-1'),
        settings: const AudioPlaybackSettings(rate: 1.25),
      ),
      AudioPrefetchCancellation(),
    );

    final request = transport.requests.single;
    expect(request.uri.toString(), 'https://api.fish.audio/v1/tts');
    expect(request.headers['model'], FishAudioTtsPreset.defaultModel);
    expect(request.headers['authorization'], 'Bearer provider-secret-key');
    final body = jsonDecode(utf8.decode(request.body)) as Map;
    expect(body['text'], 'Fish Audio 中文语音测试');
    expect(body['reference_id'], 'voice-model-id');
    expect(body['format'], 'mp3');
    expect((body['prosody'] as Map)['speed'], 1.25);
    expect((body['prosody'] as Map)['volume'], 0);
    expect(body['temperature'], 0.7);
    expect(body['top_p'], 0.7);
    expect(body['chunk_length'], 300);
    expect(body['latency'], 'normal');
    expect(body['mp3_bitrate'], 128);
    expect(request.headers, isNot(contains('idempotency-key')));
    expect(request.toString(), isNot(contains('provider-secret-key')));
  });

  test('Fish Audio bounds playback speed and sends only format parameters',
      () async {
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: const <int>[0x4f, 0x67, 0x67, 0x53, 0, 0, 0, 0],
        headers: const <String, String>{'content-type': 'audio/ogg'},
      ),
    );
    final configuration = ByokMediaConfiguration(
      capability: ByokMediaCapability.tts,
      providerId: FishAudioTtsPreset.providerId,
      displayName: FishAudioTtsPreset.displayName,
      baseUri: Uri.parse(FishAudioTtsPreset.baseUrl),
      model: FishAudioTtsPreset.defaultModel,
      apiKey: OpaqueByokApiKey('provider-secret-key'),
      audioFormat: ByokAudioFormat.opus,
      fishAudioOptions: const FishAudioTtsOptions(
        temperature: 0.4,
        topP: 0.8,
        volumeDb: -5,
        chunkLength: 200,
        latency: FishAudioLatency.balanced,
        opusBitrateBps: 32000,
        qualityGuard: true,
      ),
    );

    await FishAudioTtsSynthesizer(
      configuration: configuration,
      transport: transport,
    ).synthesize(
      CloudTtsSynthesisRequest(
        operationId: 'fish-bounded-speed',
        text: 'bounded speed',
        profile: CloudTtsProfile(profileId: 'fish', version: 'v1'),
        settings: const AudioPlaybackSettings(rate: 3),
      ),
      AudioPrefetchCancellation(),
    );

    final body = jsonDecode(utf8.decode(transport.requests.single.body)) as Map;
    expect((body['prosody'] as Map)['speed'], 2.0);
    expect((body['prosody'] as Map)['volume'], -5);
    expect(body['format'], 'opus');
    expect(body['opus_bitrate'], 32000);
    expect(body, isNot(contains('mp3_bitrate')));
    expect(body['features'], <Object?>['quality-guard']);
  });

  test('Fish Audio supports the documented default voice request', () async {
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: const <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00],
      ),
    );
    final synthesizer = FishAudioTtsSynthesizer(
      configuration: _fishAudioConfiguration(),
      transport: transport,
    );

    await synthesizer.synthesize(
      CloudTtsSynthesisRequest(
        operationId: 'fish-tts-operation-2',
        text: 'default voice',
        profile: CloudTtsProfile(profileId: 'fish-audio', version: 's2-1'),
        settings: const AudioPlaybackSettings(),
      ),
      AudioPrefetchCancellation(),
    );

    final body = jsonDecode(utf8.decode(transport.requests.single.body)) as Map;
    expect(body, isNot(contains('reference_id')));
  });

  test(
      'Fish Audio normalizes generic binary content type after signature check',
      () async {
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: const <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00],
        headers: const <String, String>{
          'content-type': 'application/octet-stream',
        },
      ),
    );
    final response = await FishAudioTtsSynthesizer(
      configuration: _fishAudioConfiguration(),
      transport: transport,
    ).synthesize(
      CloudTtsSynthesisRequest(
        operationId: 'fish-tts-operation-3',
        text: 'binary response',
        profile: CloudTtsProfile(profileId: 'fish-audio', version: 's2-1'),
        settings: const AudioPlaybackSettings(),
      ),
      AudioPrefetchCancellation(),
    );

    expect(response.mediaType, 'audio/mpeg');
  });

  test('podcast transcription verifies asset and parses timestamp segments',
      () async {
    final mediaBytes = utf8.encode('synthetic-audio-fixture');
    final asset = PodcastMediaAsset(
      assetId: 'podcast-asset-1',
      contentDigest: sha256.convert(mediaBytes).toString(),
      mediaType: 'audio/mpeg',
      bytes: mediaBytes.length,
      duration: const Duration(seconds: 9),
    );
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: utf8.encode(
          jsonEncode(<String, Object?>{
            'language': 'zh',
            'segments': <Map<String, Object?>>[
              <String, Object?>{'start': 0.0, 'end': 4.5, 'text': '第一段'},
              <String, Object?>{'start': 4.5, 'end': 9.0, 'text': '第二段'},
            ],
          }),
        ),
      ),
    );
    final provider = OpenAiCompatiblePodcastTranscriptionProvider(
      configuration: _configuration(
        ByokMediaCapability.podcastTranscription,
      ),
      transport: transport,
      assets: _AssetReader(
        PodcastMediaBytes(
          bytes: mediaBytes,
          fileName: 'episode.mp3',
          mediaType: 'audio/mpeg',
        ),
      ),
    );

    final result = await provider.transcribe(
      asset,
      outputLanguage: 'zh',
      operationId: 'transcription-operation-1',
      cancellation: PodcastTaskCancellation(),
    );

    expect(result.transcript.segments, hasLength(2));
    expect(
      result.transcript.segments.last.start,
      const Duration(milliseconds: 4500),
    );
    expect(result.billableDuration, const Duration(seconds: 9));
    expect(result.costMicros, 0);
    expect(transport.requests.single.uri.path, '/v1/audio/transcriptions');
    expect(
      utf8.decode(transport.requests.single.body),
      contains('episode.mp3'),
    );
    expect(
      utf8.decode(transport.requests.single.body),
      contains('verbose_json'),
    );
    expect(
      utf8.decode(transport.requests.single.body),
      isNot(contains('secret')),
    );
  });

  test('podcast transcription rejects bytes that do not match the asset',
      () async {
    final bytes = utf8.encode('expected');
    final provider = OpenAiCompatiblePodcastTranscriptionProvider(
      configuration: _configuration(
        ByokMediaCapability.podcastTranscription,
      ),
      transport: _Transport(ByokHttpResponse(statusCode: 200, body: const [])),
      assets: _AssetReader(
        PodcastMediaBytes(
          bytes: utf8.encode('different'),
          fileName: 'episode.mp3',
          mediaType: 'audio/mpeg',
        ),
      ),
    );
    await expectLater(
      provider.transcribe(
        PodcastMediaAsset(
          assetId: 'podcast-asset-1',
          contentDigest: sha256.convert(bytes).toString(),
          mediaType: 'audio/mpeg',
          bytes: bytes.length,
          duration: const Duration(seconds: 1),
        ),
        outputLanguage: null,
        operationId: 'transcription-operation-1',
        cancellation: PodcastTaskCancellation(),
      ),
      throwsA(
        isA<PodcastTranscriptionFailure>().having(
          (failure) => failure.code,
          'code',
          PodcastTranscriptionFailureCode.invalidMedia,
        ),
      ),
    );
  });

  test('transport timeout maps to a stable TTS failure', () async {
    final synthesizer = OpenAiCompatibleTtsSynthesizer(
      configuration: _configuration(ByokMediaCapability.tts),
      transport: const _FailingTransport(
        ByokHttpFailure(ByokHttpFailureCode.timeout),
      ),
    );
    await expectLater(
      synthesizer.synthesize(
        CloudTtsSynthesisRequest(
          operationId: 'tts-operation-1',
          text: 'bounded text',
          profile: CloudTtsProfile(profileId: 'byok', version: 'v1'),
          settings: const AudioPlaybackSettings(rate: 1),
        ),
        AudioPrefetchCancellation(),
      ),
      throwsA(
        isA<CloudTtsFailure>().having(
          (failure) => failure.code,
          'code',
          CloudTtsFailureCode.providerTimeout,
        ),
      ),
    );
  });

  test('cancelled podcast job stops before reading private media', () async {
    final reader = _CountingAssetReader();
    final provider = OpenAiCompatiblePodcastTranscriptionProvider(
      configuration: _configuration(
        ByokMediaCapability.podcastTranscription,
      ),
      transport: _Transport(ByokHttpResponse(statusCode: 200, body: const [])),
      assets: reader,
    );
    final cancellation = PodcastTaskCancellation()..cancel();
    await expectLater(
      provider.transcribe(
        PodcastMediaAsset(
          assetId: 'podcast-asset-1',
          contentDigest: sha256.convert(const <int>[1]).toString(),
          mediaType: 'audio/mpeg',
          bytes: 1,
          duration: const Duration(seconds: 1),
        ),
        outputLanguage: null,
        operationId: 'transcription-operation-1',
        cancellation: cancellation,
      ),
      throwsA(isA<PodcastTaskCancelledException>()),
    );
    expect(reader.calls, 0);
  });
}

ByokMediaConfiguration _configuration(ByokMediaCapability capability) =>
    ByokMediaConfiguration(
      capability: capability,
      providerId: 'custom-provider',
      displayName: 'Custom',
      baseUri: Uri.parse('https://provider.example/v1'),
      model: 'media-model',
      apiKey: OpaqueByokApiKey('provider-secret-key'),
      voice: capability == ByokMediaCapability.tts ? 'alloy' : null,
    );

ByokMediaConfiguration _fishAudioConfiguration({String? voice}) =>
    ByokMediaConfiguration(
      capability: ByokMediaCapability.tts,
      providerId: FishAudioTtsPreset.providerId,
      displayName: FishAudioTtsPreset.displayName,
      baseUri: Uri.parse(FishAudioTtsPreset.baseUrl),
      model: FishAudioTtsPreset.defaultModel,
      apiKey: OpaqueByokApiKey('provider-secret-key'),
      voice: voice,
    );

final class _Transport implements ByokHttpTransport {
  _Transport(this.response);

  final ByokHttpResponse response;
  final List<ByokHttpRequest> requests = <ByokHttpRequest>[];

  @override
  Future<ByokHttpResponse> send(ByokHttpRequest request) async {
    requests.add(request);
    return response;
  }
}

final class _AssetReader implements PodcastMediaAssetReader {
  const _AssetReader(this.media);

  final PodcastMediaBytes media;

  @override
  Future<PodcastMediaBytes> read(String assetId) async => media;
}

final class _FailingTransport implements ByokHttpTransport {
  const _FailingTransport(this.failure);

  final ByokHttpFailure failure;

  @override
  Future<ByokHttpResponse> send(ByokHttpRequest request) async => throw failure;
}

final class _CountingAssetReader implements PodcastMediaAssetReader {
  var calls = 0;

  @override
  Future<PodcastMediaBytes> read(String assetId) async {
    calls += 1;
    throw StateError('cancelled job must not read media');
  }
}
