import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:river_domain/river_domain.dart';

import 'audio_segment_prefetcher.dart';

enum CloudTtsNetworkKind { offline, wifi, metered, unknown }

abstract interface class CloudTtsNetworkMonitor {
  Future<CloudTtsNetworkKind> check();
}

abstract interface class CloudTtsEntitlementGate {
  Future<bool> allowsGeneration();
}

final class StaticCloudTtsEntitlementGate implements CloudTtsEntitlementGate {
  const StaticCloudTtsEntitlementGate(this.allowed);

  final bool allowed;

  @override
  Future<bool> allowsGeneration() async => allowed;
}

final class StaticCloudTtsNetworkMonitor implements CloudTtsNetworkMonitor {
  const StaticCloudTtsNetworkMonitor(this.kind);

  final CloudTtsNetworkKind kind;

  @override
  Future<CloudTtsNetworkKind> check() async => kind;
}

abstract interface class CloudTtsClock {
  DateTime now();
}

final class SystemCloudTtsClock implements CloudTtsClock {
  const SystemCloudTtsClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

enum CloudTtsAudioFormat { mp3, m4a }

final class CloudTtsProfile {
  CloudTtsProfile({
    required this.profileId,
    required this.version,
    this.audioFormat = CloudTtsAudioFormat.mp3,
  }) {
    if (!_safeId.hasMatch(profileId) || !_safeId.hasMatch(version)) {
      throw ArgumentError('Cloud TTS profile identifiers must be safe IDs');
    }
  }

  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

  final String profileId;
  final String version;
  final CloudTtsAudioFormat audioFormat;
}

final class CloudTtsPolicy {
  const CloudTtsPolicy({
    this.wifiOnly = true,
    this.maximumTextCharacters = 5000,
    this.maximumAudioBytes = 8 * 1024 * 1024,
    this.maximumAudioDuration = const Duration(minutes: 10),
    this.maximumBillableDuration = const Duration(minutes: 15),
    this.maximumCostMicros = 10000000,
    this.synthesisTimeout = const Duration(seconds: 45),
    this.cacheTimeToLive = const Duration(days: 30),
    this.maximumCacheBytes = 512 * 1024 * 1024,
    this.maximumCacheEntries = 10000,
  })  : assert(maximumTextCharacters >= 1 && maximumTextCharacters <= 20000),
        assert(maximumAudioBytes >= 64 * 1024),
        assert(maximumCostMicros >= 0),
        assert(maximumCacheBytes >= maximumAudioBytes),
        assert(maximumCacheEntries >= 1);

  final bool wifiOnly;
  final int maximumTextCharacters;
  final int maximumAudioBytes;
  final Duration maximumAudioDuration;
  final Duration maximumBillableDuration;
  final int maximumCostMicros;
  final Duration synthesisTimeout;
  final Duration cacheTimeToLive;
  final int maximumCacheBytes;
  final int maximumCacheEntries;
}

final class CloudTtsSynthesisRequest {
  CloudTtsSynthesisRequest({
    required this.operationId,
    required this.text,
    required this.profile,
    required this.settings,
  });

  final String operationId;
  final String text;
  final CloudTtsProfile profile;
  final AudioPlaybackSettings settings;

  @override
  String toString() => 'CloudTtsSynthesisRequest('
      'operation: ${_shortHash(operationId)}, '
      'characters: ${text.runes.length}, '
      'profile: ${profile.profileId}/${profile.version}, '
      'format: ${profile.audioFormat.name}'
      ')';
}

final class CloudTtsSynthesisResponse {
  CloudTtsSynthesisResponse({
    required List<int> audioBytes,
    required this.mediaType,
    required this.audioDuration,
    required this.billableDuration,
    required this.costMicros,
  }) : audioBytes = List<int>.unmodifiable(audioBytes);

  final List<int> audioBytes;
  final String mediaType;
  final Duration audioDuration;
  final Duration billableDuration;
  final int costMicros;

  @override
  String toString() => 'CloudTtsSynthesisResponse('
      'mediaType: $mediaType, bytes: ${audioBytes.length}, '
      'durationMs: ${audioDuration.inMilliseconds}, '
      'billableMs: ${billableDuration.inMilliseconds}, '
      'costMicros: $costMicros'
      ')';
}

abstract interface class CloudTtsSynthesizer {
  Future<CloudTtsSynthesisResponse> synthesize(
    CloudTtsSynthesisRequest request,
    AudioPrefetchCancellation cancellation,
  );
}

final class CloudTtsCacheEntry {
  CloudTtsCacheEntry({
    required this.cacheKey,
    required this.contentRevisionHash,
    required this.segmentIndex,
    required List<int> audioBytes,
    required this.audioDigest,
    required this.mediaType,
    required this.audioDuration,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.expiresAt,
  }) : audioBytes = List<int>.unmodifiable(audioBytes);

  final String cacheKey;
  final String contentRevisionHash;
  final int segmentIndex;
  final List<int> audioBytes;
  final String audioDigest;
  final String mediaType;
  final Duration audioDuration;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final DateTime expiresAt;

  CloudTtsCacheEntry touched(DateTime at) => CloudTtsCacheEntry(
        cacheKey: cacheKey,
        contentRevisionHash: contentRevisionHash,
        segmentIndex: segmentIndex,
        audioBytes: audioBytes,
        audioDigest: audioDigest,
        mediaType: mediaType,
        audioDuration: audioDuration,
        createdAt: createdAt,
        lastAccessedAt: at,
        expiresAt: expiresAt,
      );

  @override
  String toString() => 'CloudTtsCacheEntry('
      'key: ${_shortHash(cacheKey)}, segment: $segmentIndex, '
      'bytes: ${audioBytes.length}, mediaType: $mediaType, '
      'expiresAt: $expiresAt'
      ')';
}

abstract interface class CloudTtsCacheStore {
  Future<CloudTtsCacheEntry?> read(String cacheKey);
  Future<void> write(CloudTtsCacheEntry entry);
  Future<void> remove(String cacheKey);
  Future<List<CloudTtsCacheEntry>> listEntries();
}

final class InMemoryCloudTtsCacheStore implements CloudTtsCacheStore {
  final Map<String, CloudTtsCacheEntry> _entries =
      <String, CloudTtsCacheEntry>{};

  @override
  Future<List<CloudTtsCacheEntry>> listEntries() async =>
      List<CloudTtsCacheEntry>.unmodifiable(_entries.values);

  @override
  Future<CloudTtsCacheEntry?> read(String cacheKey) async => _entries[cacheKey];

  @override
  Future<void> remove(String cacheKey) async {
    _entries.remove(cacheKey);
  }

  @override
  Future<void> write(CloudTtsCacheEntry entry) async {
    _entries[entry.cacheKey] = entry;
  }
}

final class CloudTtsUsageRecord {
  const CloudTtsUsageRecord({
    required this.operationId,
    required this.characterCount,
    required this.audioDuration,
    required this.billableDuration,
    required this.costMicros,
    required this.recordedAt,
  });

  final String operationId;
  final int characterCount;
  final Duration audioDuration;
  final Duration billableDuration;
  final int costMicros;
  final DateTime recordedAt;

  @override
  String toString() => 'CloudTtsUsageRecord('
      'operation: ${_shortHash(operationId)}, '
      'characters: $characterCount, '
      'audioMs: ${audioDuration.inMilliseconds}, '
      'billableMs: ${billableDuration.inMilliseconds}, '
      'costMicros: $costMicros'
      ')';
}

abstract interface class CloudTtsUsageLedger {
  Future<void> recordOnce(CloudTtsUsageRecord record);
}

final class InMemoryCloudTtsUsageLedger implements CloudTtsUsageLedger {
  final Map<String, CloudTtsUsageRecord> _records =
      <String, CloudTtsUsageRecord>{};

  List<CloudTtsUsageRecord> get records =>
      List<CloudTtsUsageRecord>.unmodifiable(_records.values);

  @override
  Future<void> recordOnce(CloudTtsUsageRecord record) async {
    final existing = _records[record.operationId];
    if (existing == null) {
      _records[record.operationId] = record;
      return;
    }
    if (existing.characterCount != record.characterCount ||
        existing.audioDuration != record.audioDuration ||
        existing.billableDuration != record.billableDuration ||
        existing.costMicros != record.costMicros) {
      throw StateError('Cloud TTS usage idempotency conflict');
    }
  }
}

enum CloudTtsFailureCode {
  invalidRequest,
  entitlementRequired,
  entitlementUnavailable,
  offline,
  wifiRequired,
  networkUnknown,
  providerTimeout,
  providerFailure,
  invalidResponse,
  meteringFailure,
}

final class CloudTtsFailure implements Exception {
  const CloudTtsFailure({required this.code, required this.retryable});

  final CloudTtsFailureCode code;
  final bool retryable;

  @override
  String toString() =>
      'CloudTtsFailure(code: ${code.name}, retryable: $retryable)';
}

final class PreparedCloudTtsSegment implements PreparedAudioSegment {
  PreparedCloudTtsSegment({
    required this.segmentIndex,
    required List<int> audioBytes,
    required this.mediaType,
    required this.audioDuration,
    required this.cacheKey,
    required this.fromCache,
  })  : _audioBytes = List<int>.unmodifiable(audioBytes),
        retainedBytes = audioBytes.length;

  @override
  final int segmentIndex;
  @override
  final int retainedBytes;
  final String mediaType;
  final Duration audioDuration;
  final String cacheKey;
  final bool fromCache;
  List<int>? _audioBytes;

  List<int> get audioBytes {
    final value = _audioBytes;
    if (value == null) throw StateError('Cloud TTS segment was released');
    return value;
  }

  bool get isReleased => _audioBytes == null;

  @override
  Future<void> release() async {
    if (_audioBytes == null) {
      throw StateError('Cloud TTS segment released twice');
    }
    _audioBytes = null;
  }

  @override
  String toString() => 'PreparedCloudTtsSegment('
      'segment: $segmentIndex, bytes: $retainedBytes, '
      'mediaType: $mediaType, fromCache: $fromCache, '
      'key: ${_shortHash(cacheKey)}'
      ')';
}

final class CloudTtsPreparationBackend
    implements AudioSegmentPreparationBackend {
  CloudTtsPreparationBackend({
    required CloudTtsSynthesizer synthesizer,
    required CloudTtsCacheStore cache,
    required CloudTtsUsageLedger usageLedger,
    required CloudTtsEntitlementGate entitlement,
    required CloudTtsNetworkMonitor network,
    required CloudTtsProfile profile,
    CloudTtsClock clock = const SystemCloudTtsClock(),
    this.policy = const CloudTtsPolicy(),
  })  : assert(policy.maximumAudioDuration > Duration.zero),
        assert(policy.maximumBillableDuration >= policy.maximumAudioDuration),
        assert(policy.synthesisTimeout >= const Duration(seconds: 1)),
        assert(policy.synthesisTimeout <= const Duration(minutes: 2)),
        assert(policy.cacheTimeToLive >= const Duration(hours: 1)),
        _synthesizer = synthesizer,
        _cache = cache,
        _usageLedger = usageLedger,
        _entitlement = entitlement,
        _network = network,
        _profile = profile,
        _clock = clock;

  final CloudTtsSynthesizer _synthesizer;
  final CloudTtsCacheStore _cache;
  final CloudTtsUsageLedger _usageLedger;
  final CloudTtsEntitlementGate _entitlement;
  final CloudTtsNetworkMonitor _network;
  final CloudTtsProfile _profile;
  final CloudTtsClock _clock;
  final CloudTtsPolicy policy;
  final Map<String, _CloudTtsInFlight> _inFlight =
      <String, _CloudTtsInFlight>{};

  int get inFlightCount => _inFlight.length;

  @override
  Future<PreparedAudioSegment> prepare(
    AudioSegmentPreparationRequest request,
    AudioPrefetchCancellation cancellation,
  ) async {
    _validateRequest(request);
    cancellation.throwIfCancelled();
    final identity = _identity(request);
    final cached = await _readValidCache(identity);
    if (cached != null) {
      cancellation.throwIfCancelled();
      return _prepared(cached, fromCache: true);
    }

    bool entitled;
    try {
      entitled = await _entitlement.allowsGeneration();
    } on Object {
      throw const CloudTtsFailure(
        code: CloudTtsFailureCode.entitlementUnavailable,
        retryable: true,
      );
    }
    if (!entitled) {
      throw const CloudTtsFailure(
        code: CloudTtsFailureCode.entitlementRequired,
        retryable: false,
      );
    }
    await _checkNetwork();
    cancellation.throwIfCancelled();

    var operation = _inFlight[identity.cacheKey];
    if (operation == null) {
      operation = _startOperation(identity, request);
      _inFlight[identity.cacheKey] = operation;
    }
    operation.waiters += 1;
    try {
      final generated = await Future.any<_CloudTtsGenerated>(
        <Future<_CloudTtsGenerated>>[
          operation.future,
          cancellation.whenCancelled.then<_CloudTtsGenerated>((_) {
            throw const AudioPrefetchCancelledException();
          }),
        ],
      );
      cancellation.throwIfCancelled();
      return PreparedCloudTtsSegment(
        segmentIndex: request.segment.index,
        audioBytes: generated.audioBytes,
        mediaType: generated.mediaType,
        audioDuration: generated.audioDuration,
        cacheKey: identity.cacheKey,
        fromCache: generated.fromCache,
      );
    } finally {
      operation.waiters -= 1;
      if (operation.waiters == 0 && !operation.completed) {
        operation.providerCancellation.cancel();
      }
    }
  }

  Future<void> cleanup() async {
    final now = _utcNow();
    List<CloudTtsCacheEntry> entries;
    try {
      entries = await _cache.listEntries();
    } on Object {
      return;
    }
    final retained = <CloudTtsCacheEntry>[];
    for (final entry in entries) {
      if (!entry.expiresAt.isAfter(now) || !_validStoredShape(entry)) {
        await _safeRemove(entry.cacheKey);
      } else {
        retained.add(entry);
      }
    }
    retained.sort((left, right) {
      final access = left.lastAccessedAt.compareTo(right.lastAccessedAt);
      if (access != 0) return access;
      return left.cacheKey.compareTo(right.cacheKey);
    });
    var totalBytes = retained.fold<int>(
      0,
      (sum, entry) => sum + entry.audioBytes.length,
    );
    var totalEntries = retained.length;
    for (final entry in retained) {
      if (totalBytes <= policy.maximumCacheBytes &&
          totalEntries <= policy.maximumCacheEntries) {
        break;
      }
      await _safeRemove(entry.cacheKey);
      totalBytes -= entry.audioBytes.length;
      totalEntries -= 1;
    }
  }

  _CloudTtsInFlight _startOperation(
    _CloudTtsIdentity identity,
    AudioSegmentPreparationRequest request,
  ) {
    final operation = _CloudTtsInFlight();
    operation.future = _generate(identity, request, operation).whenComplete(() {
      operation.completed = true;
      if (identical(_inFlight[identity.cacheKey], operation)) {
        _inFlight.remove(identity.cacheKey);
      }
    });
    unawaited(
      operation.future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
    return operation;
  }

  Future<_CloudTtsGenerated> _generate(
    _CloudTtsIdentity identity,
    AudioSegmentPreparationRequest request,
    _CloudTtsInFlight operation,
  ) async {
    CloudTtsSynthesisResponse response;
    try {
      response = await _synthesizer
          .synthesize(
        CloudTtsSynthesisRequest(
          operationId: identity.operationId,
          text: request.segment.text,
          profile: _profile,
          settings: request.settings,
        ),
        operation.providerCancellation,
      )
          .timeout(
        policy.synthesisTimeout,
        onTimeout: () {
          operation.providerCancellation.cancel();
          throw const CloudTtsFailure(
            code: CloudTtsFailureCode.providerTimeout,
            retryable: true,
          );
        },
      );
    } on AudioPrefetchCancelledException {
      rethrow;
    } on CloudTtsFailure {
      rethrow;
    } on Object {
      throw const CloudTtsFailure(
        code: CloudTtsFailureCode.providerFailure,
        retryable: true,
      );
    }
    _validateResponse(response);
    final now = _utcNow();
    try {
      await _usageLedger.recordOnce(
        CloudTtsUsageRecord(
          operationId: identity.operationId,
          characterCount: request.segment.text.runes.length,
          audioDuration: response.audioDuration,
          billableDuration: response.billableDuration,
          costMicros: response.costMicros,
          recordedAt: now,
        ),
      );
    } on Object {
      throw const CloudTtsFailure(
        code: CloudTtsFailureCode.meteringFailure,
        retryable: true,
      );
    }

    if (!operation.providerCancellation.isCancelled) {
      final entry = CloudTtsCacheEntry(
        cacheKey: identity.cacheKey,
        contentRevisionHash: identity.contentRevisionHash,
        segmentIndex: request.segment.index,
        audioBytes: response.audioBytes,
        audioDigest: sha256.convert(response.audioBytes).toString(),
        mediaType: response.mediaType,
        audioDuration: response.audioDuration,
        createdAt: now,
        lastAccessedAt: now,
        expiresAt: now.add(policy.cacheTimeToLive),
      );
      try {
        await _cache.write(entry);
        await cleanup();
      } on Object {
        // A usable response remains playable when the optional cache is down.
      }
    }
    return _CloudTtsGenerated(
      audioBytes: response.audioBytes,
      mediaType: response.mediaType,
      audioDuration: response.audioDuration,
      fromCache: false,
    );
  }

  Future<CloudTtsCacheEntry?> _readValidCache(
    _CloudTtsIdentity identity,
  ) async {
    CloudTtsCacheEntry? entry;
    try {
      entry = await _cache.read(identity.cacheKey);
    } on Object {
      return null;
    }
    if (entry == null) return null;
    final now = _utcNow();
    if (entry.cacheKey != identity.cacheKey ||
        entry.contentRevisionHash != identity.contentRevisionHash ||
        !entry.expiresAt.isAfter(now) ||
        !_validStoredShape(entry) ||
        sha256.convert(entry.audioBytes).toString() != entry.audioDigest) {
      await _safeRemove(identity.cacheKey);
      return null;
    }
    final touched = entry.touched(now);
    try {
      await _cache.write(touched);
    } on Object {
      // Cache touch failures do not make an already validated asset unusable.
    }
    return touched;
  }

  bool _validStoredShape(CloudTtsCacheEntry entry) =>
      entry.segmentIndex >= 0 &&
      entry.audioBytes.isNotEmpty &&
      entry.audioBytes.length <= policy.maximumAudioBytes &&
      _allowedMediaType(entry.mediaType) &&
      entry.audioDuration > Duration.zero &&
      entry.audioDuration <= policy.maximumAudioDuration &&
      entry.createdAt.isUtc &&
      entry.lastAccessedAt.isUtc &&
      entry.expiresAt.isUtc;

  Future<void> _checkNetwork() async {
    CloudTtsNetworkKind kind;
    try {
      kind = await _network.check();
    } on Object {
      kind = CloudTtsNetworkKind.unknown;
    }
    switch (kind) {
      case CloudTtsNetworkKind.offline:
        throw const CloudTtsFailure(
          code: CloudTtsFailureCode.offline,
          retryable: true,
        );
      case CloudTtsNetworkKind.unknown:
        throw const CloudTtsFailure(
          code: CloudTtsFailureCode.networkUnknown,
          retryable: true,
        );
      case CloudTtsNetworkKind.metered when policy.wifiOnly:
        throw const CloudTtsFailure(
          code: CloudTtsFailureCode.wifiRequired,
          retryable: true,
        );
      case CloudTtsNetworkKind.wifi:
      case CloudTtsNetworkKind.metered:
        return;
    }
  }

  void _validateRequest(AudioSegmentPreparationRequest request) {
    final revision = request.contentRevision.trim();
    final text = request.segment.text;
    if (request.item.kind != AudioKind.articleTts ||
        revision.isEmpty ||
        revision.length > 256 ||
        text.trim().isEmpty ||
        text.runes.length > policy.maximumTextCharacters ||
        (request.settings.voiceId?.length ?? 0) > 256 ||
        (request.settings.languageTag?.length ?? 0) > 64) {
      throw const CloudTtsFailure(
        code: CloudTtsFailureCode.invalidRequest,
        retryable: false,
      );
    }
  }

  void _validateResponse(CloudTtsSynthesisResponse response) {
    if (response.audioBytes.isEmpty ||
        response.audioBytes.length > policy.maximumAudioBytes ||
        !_allowedMediaType(response.mediaType) ||
        response.audioDuration <= Duration.zero ||
        response.audioDuration > policy.maximumAudioDuration ||
        response.billableDuration < response.audioDuration ||
        response.billableDuration > policy.maximumBillableDuration ||
        response.costMicros < 0 ||
        response.costMicros > policy.maximumCostMicros) {
      throw const CloudTtsFailure(
        code: CloudTtsFailureCode.invalidResponse,
        retryable: false,
      );
    }
  }

  bool _allowedMediaType(String mediaType) => switch (_profile.audioFormat) {
        CloudTtsAudioFormat.mp3 => mediaType == 'audio/mpeg',
        CloudTtsAudioFormat.m4a => mediaType == 'audio/mp4',
      };

  _CloudTtsIdentity _identity(AudioSegmentPreparationRequest request) {
    final revisionHash =
        sha256.convert(utf8.encode(request.contentRevision.trim())).toString();
    final canonical = jsonEncode(<String, Object?>{
      'schema': 'river.cloud-tts-cache.v1',
      'contentRevisionHash': revisionHash,
      'segmentIndex': request.segment.index,
      'segmentTextHash':
          sha256.convert(utf8.encode(request.segment.text)).toString(),
      'sourceStart': request.segment.sourceStart,
      'sourceEnd': request.segment.sourceEnd,
      'segmentKind': request.segment.kind.name,
      'profileId': _profile.profileId,
      'profileVersion': _profile.version,
      'format': _profile.audioFormat.name,
      'rateMicros': (request.settings.rate * 1000000).round(),
      'pitchMicros': (request.settings.pitch * 1000000).round(),
      'voiceId': request.settings.voiceId,
      'languageTag': request.settings.languageTag,
    });
    final digest = sha256.convert(utf8.encode(canonical)).toString();
    return _CloudTtsIdentity(
      cacheKey: 'cloud-tts:v1:$digest',
      operationId: 'cloud-tts:$digest',
      contentRevisionHash: revisionHash,
    );
  }

  PreparedCloudTtsSegment _prepared(
    CloudTtsCacheEntry entry, {
    required bool fromCache,
  }) =>
      PreparedCloudTtsSegment(
        segmentIndex: entry.segmentIndex,
        audioBytes: entry.audioBytes,
        mediaType: entry.mediaType,
        audioDuration: entry.audioDuration,
        cacheKey: entry.cacheKey,
        fromCache: fromCache,
      );

  DateTime _utcNow() {
    final value = _clock.now();
    if (!value.isUtc) {
      throw StateError('Cloud TTS clock must return UTC');
    }
    return value;
  }

  Future<void> _safeRemove(String cacheKey) async {
    try {
      await _cache.remove(cacheKey);
    } on Object {
      // Cleanup is best-effort and never exposes cache implementation errors.
    }
  }
}

final class _CloudTtsIdentity {
  const _CloudTtsIdentity({
    required this.cacheKey,
    required this.operationId,
    required this.contentRevisionHash,
  });

  final String cacheKey;
  final String operationId;
  final String contentRevisionHash;
}

final class _CloudTtsGenerated {
  const _CloudTtsGenerated({
    required this.audioBytes,
    required this.mediaType,
    required this.audioDuration,
    required this.fromCache,
  });

  final List<int> audioBytes;
  final String mediaType;
  final Duration audioDuration;
  final bool fromCache;
}

final class _CloudTtsInFlight {
  final AudioPrefetchCancellation providerCancellation =
      AudioPrefetchCancellation();
  late Future<_CloudTtsGenerated> future;
  var waiters = 0;
  var completed = false;
}

String _shortHash(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 12);
