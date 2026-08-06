import 'dart:async';
import 'dart:typed_data';

import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  test('podcast question materializes exact timestamp evidence and cost',
      () async {
    final provider = _QuestionProvider();
    final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
    final service = PodcastTranscriptQuestionService(
      provider: provider,
      usageLedger: ledger,
      clock: _Clock(),
    );

    final result = await service.ask(
      operationId: 'question-1',
      question: 'What changed in the privacy policy?',
      language: 'en-US',
      transcript: _transcript(),
      cancellation: PodcastTaskCancellation(),
    );

    expect(result.outcome, PodcastQuestionOutcome.answered);
    expect(result.statements.single.citations.single.segmentIndex, 1);
    expect(
      result.statements.single.citations.single.start,
      const Duration(seconds: 10),
    );
    expect(
      result.statements.single.citations.single.quote,
      contains('privacy policy'),
    );
    expect(provider.requests.single.evidence, hasLength(1));
    expect(ledger.records.single.costMicros, 120);
    expect(result.diagnostic.toString(), isNot(contains('privacy policy')));
  });

  test('no lexical evidence refuses before question provider', () async {
    final provider = _QuestionProvider();
    final service = PodcastTranscriptQuestionService(
      provider: provider,
      usageLedger: MemoryPodcastAudioIntelligenceUsageLedger(),
    );

    final result = await service.ask(
      operationId: 'question-2',
      question: 'quantum entanglement',
      language: 'en-US',
      transcript: _transcript(),
      cancellation: PodcastTaskCancellation(),
    );

    expect(result.outcome, PodcastQuestionOutcome.insufficientEvidence);
    expect(result.providerCalled, isFalse);
    expect(provider.requests, isEmpty);
  });

  test('forged transcript citation fails closed but incurred cost is metered',
      () async {
    final provider = _QuestionProvider(
      result: PodcastQuestionProviderResult(
        refused: false,
        statements: <PodcastQuestionStatementDraft>[
          PodcastQuestionStatementDraft(
            text: 'Unsupported answer',
            segmentIndexes: <int>[99],
          ),
        ],
        costMicros: 75,
      ),
    );
    final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
    final service = PodcastTranscriptQuestionService(
      provider: provider,
      usageLedger: ledger,
    );

    await _expectFailure(
      service.ask(
        operationId: 'question-3',
        question: 'privacy policy changed',
        language: 'en-US',
        transcript: _transcript(),
        cancellation: PodcastTaskCancellation(),
      ),
      PodcastAudioIntelligenceFailureCode.invalidProviderOutput,
    );
    expect(ledger.records.single.costMicros, 75);
  });

  test('daily dialogue brief cites sources and meters script plus audio',
      () async {
    final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
    final script = _ScriptProvider();
    final renderer = _Renderer();
    final service = _briefService(
      ledger: ledger,
      script: script,
      renderer: renderer,
    );

    final artifact = await service.generate(
      _briefRequest(),
      PodcastTaskCancellation(),
    );

    expect(artifact.style, AudioBriefStyle.dialogue);
    expect(
      artifact.turns.map((value) => value.speaker),
      <String>['host', 'guest'],
    );
    expect(artifact.turns.every((value) => value.citations.isNotEmpty), isTrue);
    expect(artifact.totalCostMicros, 700);
    expect(ledger.records, hasLength(2));
    expect(renderer.requests.single.maximumCostMicros, 9500);
  });

  test('narration is the safe default and carries source citations', () async {
    final service = AudioBriefService(
      safety: _Safety(),
      scriptProvider: _NarrationScriptProvider(),
      renderer: _Renderer(),
      usageLedger: MemoryPodcastAudioIntelligenceUsageLedger(),
      clock: _Clock(),
    );
    final request = AudioBriefRequest(
      operationId: 'narration-brief',
      day: DateTime.utc(2026, 8, 6),
      language: 'en-US',
      sources: _briefRequest().sources,
    );

    final artifact = await service.generate(
      request,
      PodcastTaskCancellation(),
    );

    expect(artifact.style, AudioBriefStyle.narration);
    expect(artifact.turns.single.speaker, isNull);
    expect(artifact.turns.single.citations.single.sourceId, 'source-a');
  });

  test('completed daily brief retry reuses artifact without new cost',
      () async {
    final script = _ScriptProvider();
    final renderer = _Renderer();
    final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
    final service = _briefService(
      script: script,
      renderer: renderer,
      ledger: ledger,
    );

    final first = await service.generate(
      _briefRequest(),
      PodcastTaskCancellation(),
    );
    final second = await service.generate(
      _briefRequest(),
      PodcastTaskCancellation(),
    );

    expect(second, same(first));
    expect(script.requests, hasLength(1));
    expect(renderer.requests, hasLength(1));
    expect(ledger.records, hasLength(2));
  });

  test('unsafe source blocks before script and audio providers', () async {
    final safety = _Safety()..blockedStage = AudioBriefSafetyStage.source;
    final script = _ScriptProvider();
    final renderer = _Renderer();
    final service = _briefService(
      safety: safety,
      script: script,
      renderer: renderer,
    );

    await _expectFailure(
      service.generate(_briefRequest(), PodcastTaskCancellation()),
      PodcastAudioIntelligenceFailureCode.contentBlocked,
    );
    expect(script.requests, isEmpty);
    expect(renderer.requests, isEmpty);
  });

  test('unsafe generated script blocks audio while preserving script cost',
      () async {
    final safety = _Safety()..blockedStage = AudioBriefSafetyStage.script;
    final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
    final renderer = _Renderer();
    final service = _briefService(
      safety: safety,
      ledger: ledger,
      renderer: renderer,
    );

    await _expectFailure(
      service.generate(_briefRequest(), PodcastTaskCancellation()),
      PodcastAudioIntelligenceFailureCode.contentBlocked,
    );
    expect(renderer.requests, isEmpty);
    expect(
      ledger.records.single.stage,
      PodcastAudioIntelligenceUsageStage.briefScript,
    );
  });

  test('renderer cannot exceed remaining cost budget', () async {
    final renderer = _Renderer(
      result: _renderResult(costMicros: 9600),
    );
    final service = _briefService(renderer: renderer);

    await _expectFailure(
      service.generate(_briefRequest(), PodcastTaskCancellation()),
      PodcastAudioIntelligenceFailureCode.costLimit,
    );
  });

  test('late audio result after cancellation is still metered', () async {
    final renderer = _PendingRenderer();
    final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
    final service = _briefService(renderer: renderer, ledger: ledger);
    final cancellation = PodcastTaskCancellation();

    final future = service.generate(_briefRequest(), cancellation);
    await renderer.started.future;
    cancellation.cancel();
    await expectLater(future, throwsA(isA<PodcastTaskCancelledException>()));
    renderer.complete(_renderResult(costMicros: 200));
    await Future<void>.delayed(Duration.zero);

    expect(ledger.records, hasLength(2));
    expect(
      ledger.records
          .singleWhere(
            (value) =>
                value.stage == PodcastAudioIntelligenceUsageStage.briefAudio,
          )
          .costMicros,
      200,
    );
  });

  test('same operation with different evidence conflicts', () async {
    final service = _briefService();
    await service.generate(_briefRequest(), PodcastTaskCancellation());
    final changed = AudioBriefRequest(
      operationId: 'brief-2026-08-06',
      day: DateTime.utc(2026, 8, 6),
      language: 'en-US',
      style: AudioBriefStyle.dialogue,
      sources: <AudioBriefSource>[
        AudioBriefSource(
          sourceId: 'source-a',
          title: 'Changed',
          text: 'Changed evidence.',
        ),
      ],
    );

    await _expectFailure(
      service.generate(changed, PodcastTaskCancellation()),
      PodcastAudioIntelligenceFailureCode.idempotencyConflict,
    );
  });
}

final class _Clock implements PodcastAudioIntelligenceClock {
  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 8);
}

final class _QuestionProvider implements PodcastQuestionProvider {
  _QuestionProvider({PodcastQuestionProviderResult? result})
      : result = result ??
            PodcastQuestionProviderResult(
              refused: false,
              statements: <PodcastQuestionStatementDraft>[
                PodcastQuestionStatementDraft(
                  text: 'The privacy policy changed.',
                  segmentIndexes: <int>[1],
                ),
              ],
              costMicros: 120,
            );

  final PodcastQuestionProviderResult result;
  final List<PodcastQuestionProviderRequest> requests =
      <PodcastQuestionProviderRequest>[];

  @override
  Future<PodcastQuestionProviderResult> answer(
    PodcastQuestionProviderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    requests.add(request);
    return result;
  }
}

final class _Safety implements AudioBriefSafetyGate {
  AudioBriefSafetyStage? blockedStage;

  @override
  Future<AudioBriefSafetyResult> check(
    Iterable<String> fragments, {
    required AudioBriefSafetyStage stage,
  }) async =>
      AudioBriefSafetyResult(
        allowed: stage != blockedStage,
        category: stage == blockedStage ? 'blocked' : null,
      );
}

final class _ScriptProvider implements AudioBriefScriptProvider {
  final List<AudioBriefScriptProviderRequest> requests =
      <AudioBriefScriptProviderRequest>[];

  @override
  Future<AudioBriefScriptProviderResult> generate(
    AudioBriefScriptProviderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    requests.add(request);
    return AudioBriefScriptProviderResult(
      turns: <AudioBriefTurnDraft>[
        AudioBriefTurnDraft(
          text: 'Today we review the policy update.',
          sourceIds: <String>['source-a'],
          speaker: 'host',
        ),
        AudioBriefTurnDraft(
          text: 'The source says controls became clearer.',
          sourceIds: <String>['source-a'],
          speaker: 'guest',
        ),
      ],
      costMicros: 500,
    );
  }
}

final class _NarrationScriptProvider implements AudioBriefScriptProvider {
  @override
  Future<AudioBriefScriptProviderResult> generate(
    AudioBriefScriptProviderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async =>
      AudioBriefScriptProviderResult(
        turns: <AudioBriefTurnDraft>[
          AudioBriefTurnDraft(
            text: 'Today the policy update made controls clearer.',
            sourceIds: <String>['source-a'],
          ),
        ],
        costMicros: 500,
      );
}

final class _Renderer implements AudioBriefRenderer {
  _Renderer({AudioBriefRenderResult? result})
      : result = result ?? _renderResult(costMicros: 200);

  final AudioBriefRenderResult result;
  final List<AudioBriefRenderRequest> requests = <AudioBriefRenderRequest>[];

  @override
  Future<AudioBriefRenderResult> render(
    AudioBriefRenderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    requests.add(request);
    return result;
  }
}

final class _PendingRenderer implements AudioBriefRenderer {
  final Completer<void> started = Completer<void>();
  final Completer<AudioBriefRenderResult> _result =
      Completer<AudioBriefRenderResult>();

  @override
  Future<AudioBriefRenderResult> render(
    AudioBriefRenderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) {
    started.complete();
    return _result.future;
  }

  void complete(AudioBriefRenderResult value) => _result.complete(value);
}

AudioBriefService _briefService({
  _Safety? safety,
  _ScriptProvider? script,
  AudioBriefRenderer? renderer,
  MemoryPodcastAudioIntelligenceUsageLedger? ledger,
}) =>
    AudioBriefService(
      safety: safety ?? _Safety(),
      scriptProvider: script ?? _ScriptProvider(),
      renderer: renderer ?? _Renderer(),
      usageLedger: ledger ?? MemoryPodcastAudioIntelligenceUsageLedger(),
      clock: _Clock(),
    );

AudioBriefRequest _briefRequest() => AudioBriefRequest(
      operationId: 'brief-2026-08-06',
      day: DateTime.utc(2026, 8, 6),
      language: 'en-US',
      style: AudioBriefStyle.dialogue,
      maximumTotalCostMicros: 10000,
      sources: <AudioBriefSource>[
        AudioBriefSource(
          sourceId: 'source-a',
          title: 'Policy update',
          text: 'The privacy policy changed with clearer controls.',
        ),
      ],
    );

AudioBriefRenderResult _renderResult({required int costMicros}) =>
    AudioBriefRenderResult(
      bytes: Uint8List.fromList(<int>[0x49, 0x44, 0x33, 1]),
      mediaType: 'audio/mpeg',
      duration: const Duration(minutes: 2),
      billableDuration: const Duration(minutes: 2),
      costMicros: costMicros,
    );

PodcastTranscript _transcript() => PodcastTranscript(
      language: 'en-US',
      providerVersion: 'fixture-v1',
      segments: const <PodcastTranscriptSegment>[
        PodcastTranscriptSegment(
          index: 0,
          start: Duration.zero,
          end: Duration(seconds: 10),
          text: 'Welcome to the weekly product show.',
          speaker: 'host',
        ),
        PodcastTranscriptSegment(
          index: 1,
          start: Duration(seconds: 10),
          end: Duration(seconds: 20),
          text: 'The privacy policy changed with clearer controls.',
          speaker: 'guest',
        ),
      ],
    );

Future<void> _expectFailure(
  Future<Object?> future,
  PodcastAudioIntelligenceFailureCode code,
) =>
    expectLater(
      future,
      throwsA(
        isA<PodcastAudioIntelligenceFailure>().having(
          (value) => value.code,
          'code',
          code,
        ),
      ),
    );
