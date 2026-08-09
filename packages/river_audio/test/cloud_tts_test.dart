import 'dart:async';

import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('generates once, meters exact duration, and reuses cache offline',
      () async {
    final synthesizer = _ImmediateSynthesizer();
    final cache = InMemoryCloudTtsCacheStore();
    final ledger = InMemoryCloudTtsUsageLedger();
    final backend = _backend(
      synthesizer: synthesizer,
      cache: cache,
      ledger: ledger,
    );

    final first = await backend.prepare(
      _request(),
      AudioPrefetchCancellation(),
    ) as PreparedCloudTtsSegment;
    expect(first.fromCache, isFalse);
    expect(first.audioBytes, _audioBytes);
    expect(synthesizer.requests, hasLength(1));
    expect(ledger.records, hasLength(1));
    expect(ledger.records.single.characterCount, 19);
    expect(ledger.records.single.audioDuration, const Duration(seconds: 3));
    expect(
      ledger.records.single.billableDuration,
      const Duration(milliseconds: 3500),
    );
    expect(ledger.records.single.costMicros, 17);

    final offlineBackend = _backend(
      synthesizer: synthesizer,
      cache: cache,
      ledger: ledger,
      entitlement: false,
      network: CloudTtsNetworkKind.offline,
    );
    final cached = await offlineBackend.prepare(
      _request(),
      AudioPrefetchCancellation(),
    ) as PreparedCloudTtsSegment;
    expect(cached.fromCache, isTrue);
    expect(synthesizer.requests, hasLength(1));
    expect(ledger.records, hasLength(1));
    await first.release();
    await cached.release();
  });

  test('concurrent duplicate generation shares provider and usage operation',
      () async {
    final synthesizer = _PendingSynthesizer();
    final ledger = InMemoryCloudTtsUsageLedger();
    final backend = _backend(
      synthesizer: synthesizer,
      ledger: ledger,
    );
    final first = backend.prepare(_request(), AudioPrefetchCancellation());
    final second = backend.prepare(_request(), AudioPrefetchCancellation());
    await _flush();

    expect(synthesizer.requests, hasLength(1));
    expect(backend.inFlightCount, 1);
    synthesizer.complete(_response());
    final prepared = await Future.wait(<Future<PreparedAudioSegment>>[
      first,
      second,
    ]);

    expect(ledger.records, hasLength(1));
    expect(
      synthesizer.requests.single.operationId,
      ledger.records.single.operationId,
    );
    for (final item in prepared) {
      await item.release();
    }
  });

  test('last waiter cancellation propagates and late audio is not cached',
      () async {
    final synthesizer = _PendingSynthesizer();
    final cache = InMemoryCloudTtsCacheStore();
    final ledger = InMemoryCloudTtsUsageLedger();
    final backend = _backend(
      synthesizer: synthesizer,
      cache: cache,
      ledger: ledger,
    );
    final cancellation = AudioPrefetchCancellation();
    final preparation = backend.prepare(_request(), cancellation);
    await _flush();

    cancellation.cancel();
    await expectLater(
      preparation,
      throwsA(isA<AudioPrefetchCancelledException>()),
    );
    expect(synthesizer.cancellations.single.isCancelled, isTrue);

    synthesizer.complete(_response());
    await _flush();
    await _flush();
    expect(ledger.records, hasLength(1));
    expect(await cache.listEntries(), isEmpty);
    expect(backend.inFlightCount, 0);
  });

  test('content, revision, and complete voice settings invalidate cache',
      () async {
    final synthesizer = _ImmediateSynthesizer();
    final backend = _backend(synthesizer: synthesizer);

    await _release(
      await backend.prepare(
        _request(),
        AudioPrefetchCancellation(),
      ),
    );
    await _release(
      await backend.prepare(
        _request(revision: 'sha256:changed'),
        AudioPrefetchCancellation(),
      ),
    );
    await _release(
      await backend.prepare(
        _request(text: 'Changed cloud sentence.'),
        AudioPrefetchCancellation(),
      ),
    );
    await _release(
      await backend.prepare(
        _request(settings: const AudioPlaybackSettings(rate: 1.25)),
        AudioPrefetchCancellation(),
      ),
    );

    expect(synthesizer.requests, hasLength(4));
    expect(
      synthesizer.requests.map((request) => request.operationId).toSet(),
      hasLength(4),
    );
  });

  test('network and entitlement gates fail closed before provider calls',
      () async {
    final synthesizer = _ImmediateSynthesizer();
    await _expectFailure(
      _backend(synthesizer: synthesizer, entitlement: false),
      CloudTtsFailureCode.entitlementRequired,
    );
    await _expectFailure(
      _backend(
        synthesizer: synthesizer,
        network: CloudTtsNetworkKind.offline,
      ),
      CloudTtsFailureCode.offline,
    );
    await _expectFailure(
      _backend(
        synthesizer: synthesizer,
        network: CloudTtsNetworkKind.metered,
      ),
      CloudTtsFailureCode.wifiRequired,
    );
    await _expectFailure(
      _backend(
        synthesizer: synthesizer,
        network: CloudTtsNetworkKind.unknown,
      ),
      CloudTtsFailureCode.networkUnknown,
    );
    expect(synthesizer.requests, isEmpty);

    final metered = _backend(
      synthesizer: synthesizer,
      network: CloudTtsNetworkKind.metered,
      policy: const CloudTtsPolicy(wifiOnly: false),
    );
    await _release(
      await metered.prepare(
        _request(),
        AudioPrefetchCancellation(),
      ),
    );
    expect(synthesizer.requests, hasLength(1));
  });

  test('invalid provider output is not metered or cached', () async {
    final ledger = InMemoryCloudTtsUsageLedger();
    final cache = InMemoryCloudTtsCacheStore();
    final synthesizer = _ImmediateSynthesizer(
      response: _response(mediaType: 'text/plain'),
    );
    final backend = _backend(
      synthesizer: synthesizer,
      ledger: ledger,
      cache: cache,
    );

    await _expectFailure(backend, CloudTtsFailureCode.invalidResponse);
    expect(ledger.records, isEmpty);
    expect(await cache.listEntries(), isEmpty);
  });

  test('corrupt cached bytes are removed and safely regenerated', () async {
    final cache = InMemoryCloudTtsCacheStore();
    final synthesizer = _ImmediateSynthesizer();
    final backend = _backend(synthesizer: synthesizer, cache: cache);
    final first = await backend.prepare(
      _request(),
      AudioPrefetchCancellation(),
    ) as PreparedCloudTtsSegment;
    final original = (await cache.listEntries()).single;
    await first.release();
    await cache.write(
      CloudTtsCacheEntry(
        cacheKey: original.cacheKey,
        contentRevisionHash: original.contentRevisionHash,
        segmentIndex: original.segmentIndex,
        audioBytes: const <int>[9, 9, 9],
        audioDigest: original.audioDigest,
        mediaType: original.mediaType,
        audioDuration: original.audioDuration,
        createdAt: original.createdAt,
        lastAccessedAt: original.lastAccessedAt,
        expiresAt: original.expiresAt,
      ),
    );

    final regenerated = await backend.prepare(
      _request(),
      AudioPrefetchCancellation(),
    ) as PreparedCloudTtsSegment;
    expect(regenerated.fromCache, isFalse);
    expect(synthesizer.requests, hasLength(2));
    await regenerated.release();
  });

  test('cleanup removes expired and least-recently-used entries within bounds',
      () async {
    final clock = _Clock(DateTime.utc(2026, 8, 6, 12));
    final cache = InMemoryCloudTtsCacheStore();
    final backend = _backend(
      cache: cache,
      clock: clock,
      policy: const CloudTtsPolicy(
        maximumAudioBytes: 64 * 1024,
        maximumCacheBytes: 128 * 1024,
        maximumCacheEntries: 2,
      ),
    );
    await cache.write(_cacheEntry('expired', 1, clock.value, expired: true));
    await cache.write(_cacheEntry('oldest', 2, clock.value));
    await cache.write(
      _cacheEntry(
        'middle',
        3,
        clock.value.add(const Duration(minutes: 1)),
      ),
    );
    await cache.write(
      _cacheEntry(
        'newest',
        4,
        clock.value.add(const Duration(minutes: 2)),
      ),
    );

    await backend.cleanup();
    final entries = await cache.listEntries();
    expect(
      entries.map((entry) => entry.cacheKey).toSet(),
      <String>{'middle', 'newest'},
    );
    expect(
      entries.fold<int>(0, (sum, entry) => sum + entry.audioBytes.length),
      lessThanOrEqualTo(128 * 1024),
    );
  });

  test('diagnostics omit article identity, text, revision, and audio bytes',
      () async {
    final synthesizer = _ImmediateSynthesizer();
    final ledger = InMemoryCloudTtsUsageLedger();
    final prepared = await _backend(
      synthesizer: synthesizer,
      ledger: ledger,
    ).prepare(
      _request(
        text: 'PRIVATE-SPOKEN-TEXT',
        revision: 'PRIVATE-REVISION',
      ),
      AudioPrefetchCancellation(),
    ) as PreparedCloudTtsSegment;
    final values = <Object>[
      synthesizer.requests.single,
      synthesizer.response,
      ledger.records.single,
      prepared,
    ].map((value) => value.toString()).join('\n');

    expect(values, isNot(contains('PRIVATE-SPOKEN-TEXT')));
    expect(values, isNot(contains('PRIVATE-REVISION')));
    expect(values, isNot(contains('article-private')));
    expect(values, isNot(contains('secret=1')));
    expect(values, isNot(contains(_audioBytes.toString())));
    await prepared.release();
  });
}

const _audioBytes = <int>[0x49, 0x44, 0x33, 1, 2, 3, 4];

CloudTtsPreparationBackend _backend({
  CloudTtsSynthesizer? synthesizer,
  CloudTtsCacheStore? cache,
  InMemoryCloudTtsUsageLedger? ledger,
  bool entitlement = true,
  CloudTtsNetworkKind network = CloudTtsNetworkKind.wifi,
  CloudTtsClock? clock,
  CloudTtsPolicy policy = const CloudTtsPolicy(),
}) =>
    CloudTtsPreparationBackend(
      synthesizer: synthesizer ?? _ImmediateSynthesizer(),
      cache: cache ?? InMemoryCloudTtsCacheStore(),
      usageLedger: ledger ?? InMemoryCloudTtsUsageLedger(),
      entitlement: StaticCloudTtsEntitlementGate(entitlement),
      network: StaticCloudTtsNetworkMonitor(network),
      profile: CloudTtsProfile(profileId: 'premium', version: 'v1'),
      clock: clock ?? _Clock(DateTime.utc(2026, 8, 6, 12)),
      policy: policy,
    );

AudioSegmentPreparationRequest _request({
  String text = 'Cloud TTS sentence.',
  String revision = 'sha256:original',
  AudioPlaybackSettings settings = const AudioPlaybackSettings(),
}) =>
    AudioSegmentPreparationRequest(
      item: AudioItem(
        id: 'article-private',
        kind: AudioKind.articleTts,
        title: 'Private title',
        sourceUri: Uri.parse('https://reader.example/private?secret=1'),
      ),
      contentRevision: revision,
      segment: SpeechSegment(
        index: 0,
        text: text,
        sourceStart: 0,
        sourceEnd: text.length,
      ),
      settings: settings,
    );

CloudTtsSynthesisResponse _response({String mediaType = 'audio/mpeg'}) =>
    CloudTtsSynthesisResponse(
      audioBytes: _audioBytes,
      mediaType: mediaType,
      audioDuration: const Duration(seconds: 3),
      billableDuration: const Duration(milliseconds: 3500),
      costMicros: 17,
    );

CloudTtsCacheEntry _cacheEntry(
  String key,
  int segment,
  DateTime access, {
  bool expired = false,
}) =>
    CloudTtsCacheEntry(
      cacheKey: key,
      contentRevisionHash: 'revision-$key',
      segmentIndex: segment,
      audioBytes: List<int>.filled(60 * 1024, segment),
      audioDigest: 'unused-during-cleanup',
      mediaType: 'audio/mpeg',
      audioDuration: const Duration(seconds: 30),
      createdAt: access,
      lastAccessedAt: access,
      expiresAt: expired
          ? access.subtract(const Duration(minutes: 1))
          : access.add(const Duration(days: 1)),
    );

Future<void> _expectFailure(
  CloudTtsPreparationBackend backend,
  CloudTtsFailureCode code,
) async {
  await expectLater(
    backend.prepare(_request(), AudioPrefetchCancellation()),
    throwsA(
      isA<CloudTtsFailure>().having(
        (failure) => failure.code,
        'code',
        code,
      ),
    ),
  );
}

Future<void> _release(PreparedAudioSegment segment) => segment.release();

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _Clock implements CloudTtsClock {
  _Clock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _ImmediateSynthesizer implements CloudTtsSynthesizer {
  _ImmediateSynthesizer({CloudTtsSynthesisResponse? response})
      : response = response ?? _response();

  final CloudTtsSynthesisResponse response;
  final List<CloudTtsSynthesisRequest> requests = <CloudTtsSynthesisRequest>[];

  @override
  Future<CloudTtsSynthesisResponse> synthesize(
    CloudTtsSynthesisRequest request,
    AudioPrefetchCancellation cancellation,
  ) async {
    requests.add(request);
    cancellation.throwIfCancelled();
    return response;
  }
}

final class _PendingSynthesizer implements CloudTtsSynthesizer {
  final List<CloudTtsSynthesisRequest> requests = <CloudTtsSynthesisRequest>[];
  final List<AudioPrefetchCancellation> cancellations =
      <AudioPrefetchCancellation>[];
  final Completer<CloudTtsSynthesisResponse> _result =
      Completer<CloudTtsSynthesisResponse>();

  @override
  Future<CloudTtsSynthesisResponse> synthesize(
    CloudTtsSynthesisRequest request,
    AudioPrefetchCancellation cancellation,
  ) {
    requests.add(request);
    cancellations.add(cancellation);
    return _result.future;
  }

  void complete(CloudTtsSynthesisResponse response) =>
      _result.complete(response);
}
