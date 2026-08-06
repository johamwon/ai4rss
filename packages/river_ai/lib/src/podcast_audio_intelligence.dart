import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'podcast_transcription.dart';

enum PodcastAudioIntelligenceFailureCode {
  invalidRequest,
  insufficientEvidence,
  providerFailure,
  invalidProviderOutput,
  contentBlocked,
  costLimit,
  meteringFailure,
  idempotencyConflict,
}

final class PodcastAudioIntelligenceFailure implements Exception {
  const PodcastAudioIntelligenceFailure({
    required this.code,
    required this.retryable,
  });

  final PodcastAudioIntelligenceFailureCode code;
  final bool retryable;

  @override
  String toString() => 'PodcastAudioIntelligenceFailure('
      'code: ${code.name}, retryable: $retryable)';
}

enum PodcastAudioIntelligenceUsageStage { question, briefScript, briefAudio }

final class PodcastAudioIntelligenceUsageRecord {
  const PodcastAudioIntelligenceUsageRecord({
    required this.recordKey,
    required this.stage,
    required this.costMicros,
    required this.billableDuration,
    required this.recordedAt,
  });

  final String recordKey;
  final PodcastAudioIntelligenceUsageStage stage;
  final int costMicros;
  final Duration billableDuration;
  final DateTime recordedAt;

  @override
  String toString() => 'PodcastAudioIntelligenceUsageRecord('
      'key: ${recordKey.substring(0, 12)}, stage: ${stage.name}, '
      'costMicros: $costMicros, '
      'billableMs: ${billableDuration.inMilliseconds})';
}

abstract interface class PodcastAudioIntelligenceUsageLedger {
  Future<void> recordOnce(PodcastAudioIntelligenceUsageRecord record);
}

final class MemoryPodcastAudioIntelligenceUsageLedger
    implements PodcastAudioIntelligenceUsageLedger {
  final Map<String, PodcastAudioIntelligenceUsageRecord> _records =
      <String, PodcastAudioIntelligenceUsageRecord>{};

  List<PodcastAudioIntelligenceUsageRecord> get records =>
      List<PodcastAudioIntelligenceUsageRecord>.unmodifiable(_records.values);

  @override
  Future<void> recordOnce(
    PodcastAudioIntelligenceUsageRecord record,
  ) async {
    final existing = _records[record.recordKey];
    if (existing == null) {
      _records[record.recordKey] = record;
      return;
    }
    if (existing.stage != record.stage ||
        existing.costMicros != record.costMicros ||
        existing.billableDuration != record.billableDuration) {
      throw StateError('Podcast audio intelligence usage conflict');
    }
  }
}

abstract interface class PodcastAudioIntelligenceClock {
  DateTime now();
}

final class SystemPodcastAudioIntelligenceClock
    implements PodcastAudioIntelligenceClock {
  const SystemPodcastAudioIntelligenceClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final class PodcastQuestionEvidence {
  const PodcastQuestionEvidence({
    required this.segmentIndex,
    required this.start,
    required this.end,
    required this.text,
    required this.speaker,
  });

  final int segmentIndex;
  final Duration start;
  final Duration end;
  final String text;
  final String? speaker;
}

final class PodcastQuestionProviderRequest {
  PodcastQuestionProviderRequest({
    required this.question,
    required this.language,
    required List<PodcastQuestionEvidence> evidence,
    required this.maximumCostMicros,
  }) : evidence = List<PodcastQuestionEvidence>.unmodifiable(evidence);

  final String question;
  final String language;
  final List<PodcastQuestionEvidence> evidence;
  final int maximumCostMicros;

  @override
  String toString() => 'PodcastQuestionProviderRequest('
      'questionCharacters: ${question.length}, language: $language, '
      'evidence: ${evidence.length}, maximumCostMicros: $maximumCostMicros)';
}

final class PodcastQuestionStatementDraft {
  PodcastQuestionStatementDraft({
    required this.text,
    required List<int> segmentIndexes,
  }) : segmentIndexes = List<int>.unmodifiable(segmentIndexes);

  final String text;
  final List<int> segmentIndexes;
}

final class PodcastQuestionProviderResult {
  PodcastQuestionProviderResult({
    required this.refused,
    required List<PodcastQuestionStatementDraft> statements,
    required this.costMicros,
  }) : statements = List<PodcastQuestionStatementDraft>.unmodifiable(
          statements,
        );

  final bool refused;
  final List<PodcastQuestionStatementDraft> statements;
  final int costMicros;
}

abstract interface class PodcastQuestionProvider {
  Future<PodcastQuestionProviderResult> answer(
    PodcastQuestionProviderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  });
}

final class PodcastQuestionCitation {
  const PodcastQuestionCitation({
    required this.segmentIndex,
    required this.start,
    required this.end,
    required this.quote,
    required this.speaker,
  });

  final int segmentIndex;
  final Duration start;
  final Duration end;
  final String quote;
  final String? speaker;
}

final class PodcastQuestionStatement {
  PodcastQuestionStatement({
    required this.text,
    required List<PodcastQuestionCitation> citations,
  }) : citations = List<PodcastQuestionCitation>.unmodifiable(citations);

  final String text;
  final List<PodcastQuestionCitation> citations;
}

enum PodcastQuestionOutcome { answered, insufficientEvidence }

final class PodcastQuestionResult {
  PodcastQuestionResult({
    required this.outcome,
    required List<PodcastQuestionStatement> statements,
    required this.providerCalled,
    required this.costMicros,
    required this.diagnostic,
  }) : statements = List<PodcastQuestionStatement>.unmodifiable(statements);

  final PodcastQuestionOutcome outcome;
  final List<PodcastQuestionStatement> statements;
  final bool providerCalled;
  final int costMicros;
  final Map<String, Object> diagnostic;
}

final class PodcastTranscriptQuestionService {
  PodcastTranscriptQuestionService({
    required PodcastQuestionProvider provider,
    required PodcastAudioIntelligenceUsageLedger usageLedger,
    PodcastAudioIntelligenceClock clock =
        const SystemPodcastAudioIntelligenceClock(),
    this.maximumEvidenceSegments = 24,
    this.maximumCostMicros = 5000000,
  })  : _provider = provider,
        _usageLedger = usageLedger,
        _clock = clock {
    if (maximumEvidenceSegments < 1 ||
        maximumEvidenceSegments > 100 ||
        maximumCostMicros < 0 ||
        maximumCostMicros > 50000000) {
      throw ArgumentError('Invalid podcast question policy.');
    }
  }

  final PodcastQuestionProvider _provider;
  final PodcastAudioIntelligenceUsageLedger _usageLedger;
  final PodcastAudioIntelligenceClock _clock;
  final int maximumEvidenceSegments;
  final int maximumCostMicros;

  Future<PodcastQuestionResult> ask({
    required String operationId,
    required String question,
    required String language,
    required PodcastTranscript transcript,
    required PodcastTaskCancellation cancellation,
  }) async {
    if (!_safeOperationId.hasMatch(operationId) ||
        question.trim().isEmpty ||
        question.length > 2000 ||
        !_languageTag.hasMatch(language)) {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.invalidRequest,
        retryable: false,
      );
    }
    cancellation.throwIfCancelled();
    final selected = _selectEvidence(question, transcript);
    if (selected.isEmpty) {
      return PodcastQuestionResult(
        outcome: PodcastQuestionOutcome.insufficientEvidence,
        statements: const <PodcastQuestionStatement>[],
        providerCalled: false,
        costMicros: 0,
        diagnostic: <String, Object>{
          'questionCharacters': question.length,
          'language': language,
          'evidenceSegments': 0,
          'outcome': PodcastQuestionOutcome.insufficientEvidence.name,
        },
      );
    }
    PodcastQuestionProviderResult result;
    try {
      final providerFuture = _provider.answer(
        PodcastQuestionProviderRequest(
          question: question,
          language: language,
          evidence: selected,
          maximumCostMicros: maximumCostMicros,
        ),
        operationId: _stageOperationId(
          operationId,
          PodcastAudioIntelligenceUsageStage.question,
        ),
        cancellation: cancellation,
      );
      result = await _awaitCosted(
        providerFuture,
        cancellation,
        onCost: (value) => _recordUsage(
          operationId,
          PodcastAudioIntelligenceUsageStage.question,
          value.costMicros,
          Duration.zero,
        ),
      );
    } on PodcastTaskCancelledException {
      rethrow;
    } on PodcastAudioIntelligenceFailure {
      rethrow;
    } on Object {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.providerFailure,
        retryable: true,
      );
    }
    _validateCost(result.costMicros, maximumCostMicros);
    if (result.refused) {
      if (result.statements.isNotEmpty) _invalidOutput();
      return PodcastQuestionResult(
        outcome: PodcastQuestionOutcome.insufficientEvidence,
        statements: const <PodcastQuestionStatement>[],
        providerCalled: true,
        costMicros: result.costMicros,
        diagnostic: <String, Object>{
          'questionCharacters': question.length,
          'language': language,
          'evidenceSegments': selected.length,
          'outcome': PodcastQuestionOutcome.insufficientEvidence.name,
        },
      );
    }
    if (result.statements.isEmpty || result.statements.length > 12) {
      _invalidOutput();
    }
    final evidence = <int, PodcastQuestionEvidence>{
      for (final value in selected) value.segmentIndex: value,
    };
    final statements = <PodcastQuestionStatement>[];
    for (final draft in result.statements) {
      if (draft.text.trim().isEmpty ||
          draft.text.length > 1200 ||
          draft.segmentIndexes.isEmpty ||
          draft.segmentIndexes.length > 5 ||
          draft.segmentIndexes.toSet().length != draft.segmentIndexes.length ||
          draft.segmentIndexes.any((index) => !evidence.containsKey(index))) {
        _invalidOutput();
      }
      statements.add(
        PodcastQuestionStatement(
          text: draft.text,
          citations: <PodcastQuestionCitation>[
            for (final index in draft.segmentIndexes)
              PodcastQuestionCitation(
                segmentIndex: index,
                start: evidence[index]!.start,
                end: evidence[index]!.end,
                quote: evidence[index]!.text,
                speaker: evidence[index]!.speaker,
              ),
          ],
        ),
      );
    }
    return PodcastQuestionResult(
      outcome: PodcastQuestionOutcome.answered,
      statements: statements,
      providerCalled: true,
      costMicros: result.costMicros,
      diagnostic: <String, Object>{
        'questionCharacters': question.length,
        'language': language,
        'evidenceSegments': selected.length,
        'outcome': PodcastQuestionOutcome.answered.name,
      },
    );
  }

  List<PodcastQuestionEvidence> _selectEvidence(
    String question,
    PodcastTranscript transcript,
  ) {
    final terms = _searchTerms(question);
    if (terms.isEmpty) return const <PodcastQuestionEvidence>[];
    final scored = <(int, PodcastTranscriptSegment)>[];
    for (final segment in transcript.segments) {
      final normalized = segment.text.toLowerCase();
      final score = terms.where(normalized.contains).length;
      if (score > 0) scored.add((score, segment));
    }
    scored.sort((left, right) {
      final score = right.$1.compareTo(left.$1);
      return score != 0 ? score : left.$2.index.compareTo(right.$2.index);
    });
    return <PodcastQuestionEvidence>[
      for (final value in scored.take(maximumEvidenceSegments))
        PodcastQuestionEvidence(
          segmentIndex: value.$2.index,
          start: value.$2.start,
          end: value.$2.end,
          text: value.$2.text,
          speaker: value.$2.speaker,
        ),
    ];
  }

  Never _invalidOutput() => throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.invalidProviderOutput,
        retryable: false,
      );

  Future<T> _awaitCosted<T>(
    Future<T> providerFuture,
    PodcastTaskCancellation cancellation, {
    required Future<void> Function(T value) onCost,
  }) async {
    final metered = providerFuture.then<T>((value) async {
      await onCost(value);
      return value;
    });
    unawaited(metered.then<void>((_) {}, onError: (_, __) {}));
    return Future.any<T>(<Future<T>>[
      metered,
      cancellation.whenCancelled.then<T>((_) {
        throw const PodcastTaskCancelledException();
      }),
    ]);
  }

  Future<void> _recordUsage(
    String operationId,
    PodcastAudioIntelligenceUsageStage stage,
    int costMicros,
    Duration billableDuration,
  ) async {
    if (costMicros < 0 || billableDuration.isNegative) {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.meteringFailure,
        retryable: false,
      );
    }
    try {
      await _usageLedger.recordOnce(
        PodcastAudioIntelligenceUsageRecord(
          recordKey: _usageKey(operationId, stage),
          stage: stage,
          costMicros: costMicros,
          billableDuration: billableDuration,
          recordedAt: _utcNow(),
        ),
      );
    } on PodcastAudioIntelligenceFailure {
      rethrow;
    } on Object {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.meteringFailure,
        retryable: true,
      );
    }
  }

  DateTime _utcNow() {
    final value = _clock.now();
    if (!value.isUtc) throw StateError('Clock must return UTC');
    return value;
  }
}

enum AudioBriefStyle { narration, dialogue }

final class AudioBriefSource {
  AudioBriefSource({
    required this.sourceId,
    required this.title,
    required this.text,
  }) {
    if (!_safeSourceId.hasMatch(sourceId) ||
        title.trim().isEmpty ||
        title.length > 1000 ||
        text.trim().isEmpty ||
        text.length > 20000) {
      throw ArgumentError('Invalid audio brief source.');
    }
  }

  final String sourceId;
  final String title;
  final String text;
}

final class AudioBriefRequest {
  AudioBriefRequest({
    required this.operationId,
    required this.day,
    required this.language,
    required List<AudioBriefSource> sources,
    this.style = AudioBriefStyle.narration,
    this.maximumTotalCostMicros = 10000000,
  }) : sources = List<AudioBriefSource>.unmodifiable(sources) {
    if (!_safeOperationId.hasMatch(operationId) ||
        !day.isUtc ||
        day != DateTime.utc(day.year, day.month, day.day) ||
        !_languageTag.hasMatch(language) ||
        this.sources.isEmpty ||
        this.sources.length > 50 ||
        this.sources.map((value) => value.sourceId).toSet().length !=
            this.sources.length ||
        maximumTotalCostMicros < 0 ||
        maximumTotalCostMicros > 50000000) {
      throw ArgumentError('Invalid audio brief request.');
    }
  }

  final String operationId;
  final DateTime day;
  final String language;
  final List<AudioBriefSource> sources;
  final AudioBriefStyle style;
  final int maximumTotalCostMicros;

  String get fingerprint => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, Object>{
            'schema': 'river.audio-brief.v1',
            'day': day.toIso8601String(),
            'language': language,
            'style': style.name,
            'maximumTotalCostMicros': maximumTotalCostMicros,
            'sources': <Object>[
              for (final source in sources)
                <String, Object>{
                  'id': source.sourceId,
                  'titleHash': _hash(source.title),
                  'textHash': _hash(source.text),
                },
            ],
          }),
        ),
      )
      .toString();
}

enum AudioBriefSafetyStage { source, script }

final class AudioBriefSafetyResult {
  const AudioBriefSafetyResult({required this.allowed, this.category});

  final bool allowed;
  final String? category;
}

abstract interface class AudioBriefSafetyGate {
  Future<AudioBriefSafetyResult> check(
    Iterable<String> fragments, {
    required AudioBriefSafetyStage stage,
  });
}

final class AudioBriefTurnDraft {
  AudioBriefTurnDraft({
    required this.text,
    required List<String> sourceIds,
    this.speaker,
  }) : sourceIds = List<String>.unmodifiable(sourceIds);

  final String text;
  final List<String> sourceIds;
  final String? speaker;
}

final class AudioBriefScriptProviderRequest {
  AudioBriefScriptProviderRequest({
    required this.day,
    required this.language,
    required this.style,
    required List<AudioBriefSource> sources,
    required this.maximumCostMicros,
  }) : sources = List<AudioBriefSource>.unmodifiable(sources);

  final DateTime day;
  final String language;
  final AudioBriefStyle style;
  final List<AudioBriefSource> sources;
  final int maximumCostMicros;
}

final class AudioBriefScriptProviderResult {
  AudioBriefScriptProviderResult({
    required List<AudioBriefTurnDraft> turns,
    required this.costMicros,
  }) : turns = List<AudioBriefTurnDraft>.unmodifiable(turns);

  final List<AudioBriefTurnDraft> turns;
  final int costMicros;
}

abstract interface class AudioBriefScriptProvider {
  Future<AudioBriefScriptProviderResult> generate(
    AudioBriefScriptProviderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  });
}

final class AudioBriefRenderRequest {
  AudioBriefRenderRequest({
    required this.language,
    required this.style,
    required List<AudioBriefTurnDraft> turns,
    required this.maximumCostMicros,
  }) : turns = List<AudioBriefTurnDraft>.unmodifiable(turns);

  final String language;
  final AudioBriefStyle style;
  final List<AudioBriefTurnDraft> turns;
  final int maximumCostMicros;
}

final class AudioBriefRenderResult {
  AudioBriefRenderResult({
    required Uint8List bytes,
    required this.mediaType,
    required this.duration,
    required this.billableDuration,
    required this.costMicros,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String mediaType;
  final Duration duration;
  final Duration billableDuration;
  final int costMicros;
}

abstract interface class AudioBriefRenderer {
  Future<AudioBriefRenderResult> render(
    AudioBriefRenderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  });
}

final class AudioBriefCitation {
  const AudioBriefCitation({required this.sourceId, required this.title});

  final String sourceId;
  final String title;
}

final class AudioBriefTurn {
  AudioBriefTurn({
    required this.text,
    required this.speaker,
    required List<AudioBriefCitation> citations,
  }) : citations = List<AudioBriefCitation>.unmodifiable(citations);

  final String text;
  final String? speaker;
  final List<AudioBriefCitation> citations;
}

final class AudioBriefArtifact {
  AudioBriefArtifact({
    required this.fingerprint,
    required this.day,
    required this.language,
    required this.style,
    required List<AudioBriefTurn> turns,
    required Uint8List audioBytes,
    required this.mediaType,
    required this.duration,
    required this.totalCostMicros,
    required this.createdAt,
  })  : turns = List<AudioBriefTurn>.unmodifiable(turns),
        audioBytes = Uint8List.fromList(audioBytes);

  final String fingerprint;
  final DateTime day;
  final String language;
  final AudioBriefStyle style;
  final List<AudioBriefTurn> turns;
  final Uint8List audioBytes;
  final String mediaType;
  final Duration duration;
  final int totalCostMicros;
  final DateTime createdAt;
}

final class AudioBriefService {
  AudioBriefService({
    required AudioBriefSafetyGate safety,
    required AudioBriefScriptProvider scriptProvider,
    required AudioBriefRenderer renderer,
    required PodcastAudioIntelligenceUsageLedger usageLedger,
    PodcastAudioIntelligenceClock clock =
        const SystemPodcastAudioIntelligenceClock(),
    this.maximumScriptCharacters = 20000,
    this.maximumAudioBytes = 100 * 1024 * 1024,
    this.maximumAudioDuration = const Duration(hours: 2),
  })  : _safety = safety,
        _scriptProvider = scriptProvider,
        _renderer = renderer,
        _usageLedger = usageLedger,
        _clock = clock {
    if (maximumScriptCharacters < 1 ||
        maximumScriptCharacters > 200000 ||
        maximumAudioBytes < 1 ||
        maximumAudioBytes > 500 * 1024 * 1024 ||
        maximumAudioDuration <= Duration.zero ||
        maximumAudioDuration > const Duration(hours: 12)) {
      throw ArgumentError('Invalid audio brief policy.');
    }
  }

  final AudioBriefSafetyGate _safety;
  final AudioBriefScriptProvider _scriptProvider;
  final AudioBriefRenderer _renderer;
  final PodcastAudioIntelligenceUsageLedger _usageLedger;
  final PodcastAudioIntelligenceClock _clock;
  final int maximumScriptCharacters;
  final int maximumAudioBytes;
  final Duration maximumAudioDuration;
  final Map<String, String> _fingerprints = <String, String>{};
  final Map<String, AudioBriefArtifact> _artifacts =
      <String, AudioBriefArtifact>{};

  Future<AudioBriefArtifact> generate(
    AudioBriefRequest request,
    PodcastTaskCancellation cancellation,
  ) async {
    final existing = _fingerprints[request.operationId];
    if (existing != null && existing != request.fingerprint) {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.idempotencyConflict,
        retryable: false,
      );
    }
    _fingerprints[request.operationId] = request.fingerprint;
    final completed = _artifacts[request.operationId];
    if (completed != null) return completed;
    cancellation.throwIfCancelled();
    final sourceSafety = await _safety.check(
      request.sources.map((value) => value.text),
      stage: AudioBriefSafetyStage.source,
    );
    if (!sourceSafety.allowed) _blocked();
    cancellation.throwIfCancelled();
    final scriptOperation = _stageOperationId(
      request.operationId,
      PodcastAudioIntelligenceUsageStage.briefScript,
    );
    AudioBriefScriptProviderResult script;
    try {
      final future = _scriptProvider.generate(
        AudioBriefScriptProviderRequest(
          day: request.day,
          language: request.language,
          style: request.style,
          sources: request.sources,
          maximumCostMicros: request.maximumTotalCostMicros,
        ),
        operationId: scriptOperation,
        cancellation: cancellation,
      );
      script = await _awaitCostedBrief(
        future,
        cancellation,
        onCost: (value) => _recordBriefUsage(
          request.operationId,
          PodcastAudioIntelligenceUsageStage.briefScript,
          value.costMicros,
          Duration.zero,
        ),
      );
    } on PodcastTaskCancelledException {
      rethrow;
    } on PodcastAudioIntelligenceFailure {
      rethrow;
    } on Object {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.providerFailure,
        retryable: true,
      );
    }
    _validateCost(script.costMicros, request.maximumTotalCostMicros);
    final turns = _validateAndMaterializeScript(request, script);
    final scriptSafety = await _safety.check(
      turns.map((value) => value.text),
      stage: AudioBriefSafetyStage.script,
    );
    if (!scriptSafety.allowed) _blocked();
    cancellation.throwIfCancelled();
    final remaining = request.maximumTotalCostMicros - script.costMicros;
    final renderOperation = _stageOperationId(
      request.operationId,
      PodcastAudioIntelligenceUsageStage.briefAudio,
    );
    AudioBriefRenderResult rendered;
    try {
      final future = _renderer.render(
        AudioBriefRenderRequest(
          language: request.language,
          style: request.style,
          turns: script.turns,
          maximumCostMicros: remaining,
        ),
        operationId: renderOperation,
        cancellation: cancellation,
      );
      rendered = await _awaitCostedBrief(
        future,
        cancellation,
        onCost: (value) => _recordBriefUsage(
          request.operationId,
          PodcastAudioIntelligenceUsageStage.briefAudio,
          value.costMicros,
          value.billableDuration,
        ),
      );
    } on PodcastTaskCancelledException {
      rethrow;
    } on PodcastAudioIntelligenceFailure {
      rethrow;
    } on Object {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.providerFailure,
        retryable: true,
      );
    }
    _validateRender(rendered, remaining);
    final artifact = AudioBriefArtifact(
      fingerprint: request.fingerprint,
      day: request.day,
      language: request.language,
      style: request.style,
      turns: turns,
      audioBytes: rendered.bytes,
      mediaType: rendered.mediaType,
      duration: rendered.duration,
      totalCostMicros: script.costMicros + rendered.costMicros,
      createdAt: _utcNow(),
    );
    _artifacts[request.operationId] = artifact;
    return artifact;
  }

  List<AudioBriefTurn> _validateAndMaterializeScript(
    AudioBriefRequest request,
    AudioBriefScriptProviderResult result,
  ) {
    final characters = result.turns.fold<int>(
      0,
      (total, turn) => total + turn.text.length,
    );
    if (result.turns.isEmpty ||
        result.turns.length > 100 ||
        characters > maximumScriptCharacters) {
      _invalidBriefOutput();
    }
    final sources = <String, AudioBriefSource>{
      for (final source in request.sources) source.sourceId: source,
    };
    final turns = <AudioBriefTurn>[];
    String? priorSpeaker;
    for (final draft in result.turns) {
      final validSpeaker = request.style == AudioBriefStyle.narration
          ? draft.speaker == null
          : (draft.speaker == 'host' || draft.speaker == 'guest') &&
              draft.speaker != priorSpeaker;
      if (draft.text.trim().isEmpty ||
          draft.text.length > 2000 ||
          !validSpeaker ||
          draft.sourceIds.isEmpty ||
          draft.sourceIds.length > 5 ||
          draft.sourceIds.toSet().length != draft.sourceIds.length ||
          draft.sourceIds.any((id) => !sources.containsKey(id))) {
        _invalidBriefOutput();
      }
      priorSpeaker = draft.speaker;
      turns.add(
        AudioBriefTurn(
          text: draft.text,
          speaker: draft.speaker,
          citations: <AudioBriefCitation>[
            for (final id in draft.sourceIds)
              AudioBriefCitation(sourceId: id, title: sources[id]!.title),
          ],
        ),
      );
    }
    return turns;
  }

  void _validateRender(AudioBriefRenderResult result, int remainingCost) {
    _validateCost(result.costMicros, remainingCost);
    if (result.bytes.isEmpty ||
        result.bytes.length > maximumAudioBytes ||
        (result.mediaType != 'audio/mpeg' && result.mediaType != 'audio/mp4') ||
        result.duration <= Duration.zero ||
        result.duration > maximumAudioDuration ||
        result.billableDuration.isNegative ||
        result.billableDuration > maximumAudioDuration) {
      _invalidBriefOutput();
    }
  }

  Never _blocked() => throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.contentBlocked,
        retryable: false,
      );

  Never _invalidBriefOutput() => throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.invalidProviderOutput,
        retryable: false,
      );

  Future<T> _awaitCostedBrief<T>(
    Future<T> future,
    PodcastTaskCancellation cancellation, {
    required Future<void> Function(T value) onCost,
  }) async {
    final metered = future.then<T>((value) async {
      await onCost(value);
      return value;
    });
    unawaited(metered.then<void>((_) {}, onError: (_, __) {}));
    return Future.any<T>(<Future<T>>[
      metered,
      cancellation.whenCancelled.then<T>((_) {
        throw const PodcastTaskCancelledException();
      }),
    ]);
  }

  Future<void> _recordBriefUsage(
    String operationId,
    PodcastAudioIntelligenceUsageStage stage,
    int costMicros,
    Duration billableDuration,
  ) async {
    if (costMicros < 0 || billableDuration.isNegative) {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.meteringFailure,
        retryable: false,
      );
    }
    try {
      await _usageLedger.recordOnce(
        PodcastAudioIntelligenceUsageRecord(
          recordKey: _usageKey(operationId, stage),
          stage: stage,
          costMicros: costMicros,
          billableDuration: billableDuration,
          recordedAt: _utcNow(),
        ),
      );
    } on PodcastAudioIntelligenceFailure {
      rethrow;
    } on Object {
      throw const PodcastAudioIntelligenceFailure(
        code: PodcastAudioIntelligenceFailureCode.meteringFailure,
        retryable: true,
      );
    }
  }

  DateTime _utcNow() {
    final value = _clock.now();
    if (!value.isUtc) throw StateError('Clock must return UTC');
    return value;
  }
}

void _validateCost(int costMicros, int maximum) {
  if (costMicros < 0 || costMicros > maximum) {
    throw const PodcastAudioIntelligenceFailure(
      code: PodcastAudioIntelligenceFailureCode.costLimit,
      retryable: false,
    );
  }
}

String _stageOperationId(
  String operationId,
  PodcastAudioIntelligenceUsageStage stage,
) =>
    'podcast-ai:${stage.name}:${_hash(operationId).substring(0, 48)}';

String _usageKey(
  String operationId,
  PodcastAudioIntelligenceUsageStage stage,
) =>
    _hash('${stage.name}\u0000$operationId');

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

Set<String> _searchTerms(String value) {
  final normalized = value.toLowerCase();
  final terms = <String>{};
  for (final match in RegExp(r'[a-z0-9]{2,}|[\u3400-\u9fff]').allMatches(
    normalized,
  )) {
    final term = match.group(0)!;
    if (!_questionStopWords.contains(term)) terms.add(term);
  }
  return terms;
}

final _safeOperationId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$');
final _safeSourceId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$');
final _languageTag = RegExp(r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$');
const _questionStopWords = <String>{
  'a',
  'an',
  'and',
  'are',
  'did',
  'does',
  'for',
  'from',
  'how',
  'in',
  'is',
  'of',
  'on',
  'the',
  'to',
  'was',
  'what',
  'when',
  'where',
  'which',
  'who',
  'why',
  'with',
};
