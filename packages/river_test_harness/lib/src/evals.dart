import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:river_ai/river_ai.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_commerce/river_commerce.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_preferences/river_preferences.dart';

final class EvalFailure {
  const EvalFailure(this.caseId, this.message);

  final String caseId;
  final String message;

  @override
  String toString() => '$caseId: $message';
}

final class EvalReport {
  const EvalReport({
    required this.name,
    required this.total,
    required this.failures,
    this.metrics = const <String, Object>{},
  });

  final String name;
  final int total;
  final List<EvalFailure> failures;
  final Map<String, Object> metrics;

  int get failedCases =>
      failures.map((failure) => failure.caseId).toSet().length;
  int get passed => total - failedCases;
  bool get isSuccess => failures.isEmpty;

  Map<String, Object> toJson() => <String, Object>{
        'name': name,
        'total': total,
        'passed': passed,
        'failed': failedCases,
        if (metrics.isNotEmpty) 'metrics': metrics,
        'failures': failures
            .map(
              (failure) => <String, String>{
                'caseId': failure.caseId,
                'message': failure.message,
              },
            )
            .toList(),
      };
}

final class HarnessEvals {
  const HarnessEvals(this.workspaceRoot);

  final Directory workspaceRoot;

  EvalReport verifyFixtures() {
    final manifest = _readJson('fixtures/manifest.json');
    final fixtures = _list(manifest['fixtures']);
    final failures = <EvalFailure>[];

    for (final fixture in fixtures) {
      final id = fixture['path'] as String;
      final file = File(_path(id));
      if (!file.existsSync()) {
        failures.add(EvalFailure(id, 'fixture does not exist'));
        continue;
      }
      final content = file.readAsStringSync();
      for (final expected in _strings(fixture['contains'])) {
        if (!content.contains(expected)) {
          failures.add(EvalFailure(id, 'missing marker: $expected'));
        }
      }
    }
    return EvalReport(
      name: 'fixtures',
      total: fixtures.length,
      failures: failures,
    );
  }

  Future<EvalReport> evaluateExtraction() async {
    final manifest = _readJson('evals/extraction_manifest.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    const extractor = LayeredFullTextExtractor();

    for (final item in cases) {
      final id = item['id'] as String;
      final input = File(_path(item['fixture'] as String)).readAsStringSync();
      final sourceUri = Uri.parse(item['url'] as String);
      final request = switch (item['input']) {
        'pageHtml' => ExtractionRequest(
            sourceUri: sourceUri,
            pageHtml: input,
          ),
        'feedContentHtml' => ExtractionRequest(
            sourceUri: sourceUri,
            feedContentHtml: input,
          ),
        'feedSummary' => ExtractionRequest(
            sourceUri: sourceUri,
            feedSummary: input,
          ),
        _ => throw StateError('Unsupported extraction fixture input'),
      };
      final result = await extractor.extract(request);
      final expectedOutcome = item['expectedOutcome'] as String;
      if (expectedOutcome == 'failure') {
        if (result is! ExtractionFailureResult) {
          failures.add(EvalFailure(id, 'expected a classified failure'));
          continue;
        }
        final expectedFailure = item['expectedFailure'] as String;
        if (result.failure.code.name != expectedFailure) {
          failures.add(
            EvalFailure(
              id,
              'expected $expectedFailure, got ${result.failure.code.name}',
            ),
          );
        }
        continue;
      }
      if (result is! ExtractionSuccess) {
        final code = (result as ExtractionFailureResult).failure.code.name;
        failures.add(EvalFailure(id, 'unexpected extraction failure: $code'));
        continue;
      }
      final article = result.article;
      final expectedExtractor = item['expectedExtractor'] as String;
      if (article.extractor != expectedExtractor) {
        failures.add(
          EvalFailure(
            id,
            'expected extractor $expectedExtractor, got ${article.extractor}',
          ),
        );
      }
      final qualityAtLeast = (item['qualityAtLeast'] as num).toDouble();
      if (article.qualityScore < qualityAtLeast) {
        failures.add(
          EvalFailure(
            id,
            'quality ${article.qualityScore} is below $qualityAtLeast',
          ),
        );
      }
      for (final expected in _strings(item['plainTextContains'])) {
        if (!article.plainText.contains(expected)) {
          failures.add(EvalFailure(id, 'plain text missing: $expected'));
        }
      }
      for (final forbidden in _strings(item['htmlForbids'])) {
        if (article.html.toLowerCase().contains(forbidden.toLowerCase())) {
          failures.add(EvalFailure(id, 'unsafe HTML retained: $forbidden'));
        }
      }
    }
    return EvalReport(
      name: 'extraction',
      total: cases.length,
      failures: failures,
    );
  }

  Future<EvalReport> evaluateCloudExtractionReplay() async {
    final manifest = _readJson('evals/cloud_extraction_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var transportCalls = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final dns = _CloudExtractionReplayDns(kind);
      final transport = _CloudExtractionReplayTransport(kind);
      final service = CloudFullTextRescueService(
        dns: dns,
        transport: transport,
        clock: const _CloudExtractionReplayClock(),
        policy: const CloudExtractionPolicy(
          maximumResponseBytes: 2048,
          maximumTotalBytes: 4096,
        ),
      );
      final sourceUri = kind == 'privateLiteral'
          ? Uri.parse('https://127.0.0.1/article')
          : Uri.parse('https://cloud-replay.example/article');
      try {
        final result = await service.rescue(sourceUri: sourceUri);
        if (item['expectedOutcome'] == 'success') {
          if (result is! CloudExtractionSuccess) {
            failures.add(EvalFailure(id, 'expected sanitized extraction'));
          } else if (result.article.html.contains('<script') ||
              result.article.html.contains('<iframe') ||
              result.article.html.contains('javascript:') ||
              result.article.html.contains('onerror') ||
              !result.article.plainText.contains('合成安全正文')) {
            failures.add(EvalFailure(id, 'malicious HTML was not sanitized'));
          }
        } else if (result is! CloudExtractionFailureResult) {
          failures.add(EvalFailure(id, 'expected a classified SSRF failure'));
        } else if (result.failure.code.name != item['expectedFailure']) {
          failures.add(
            EvalFailure(
              id,
              'expected ${item['expectedFailure']}, got ${result.failure.code.name}',
            ),
          );
        }
        transportCalls += transport.requests.length;
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'cloud extraction replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'cloud-extraction-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'transportCalls': transportCalls,
        'privateLiteralTransportCalls': 0,
        'dnsPinned': true,
      },
    );
  }

  Future<EvalReport> evaluateCloudTtsReplay() async {
    final manifest = _readJson('evals/cloud_tts_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var providerCalls = 0;
    var billedMilliseconds = 0;
    var cancellationPropagated = false;
    var privateContentInDiagnostics = false;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final cache = InMemoryCloudTtsCacheStore();
      final ledger = InMemoryCloudTtsUsageLedger();
      final synthesizer = _CloudTtsReplaySynthesizer(
        pending: kind == 'duplicate' || kind == 'cancel',
      );
      final backend = CloudTtsPreparationBackend(
        synthesizer: synthesizer,
        cache: cache,
        usageLedger: ledger,
        entitlement: const StaticCloudTtsEntitlementGate(true),
        network: StaticCloudTtsNetworkMonitor(
          kind == 'network'
              ? CloudTtsNetworkKind.metered
              : CloudTtsNetworkKind.wifi,
        ),
        profile: CloudTtsProfile(profileId: 'replay', version: 'v1'),
        clock: const _CloudTtsReplayClock(),
      );
      try {
        switch (kind) {
          case 'billing':
            final prepared = await backend.prepare(
              _cloudTtsReplayRequest(),
              AudioPrefetchCancellation(),
            );
            await prepared.release();
            if (ledger.records.length != 1 ||
                ledger.records.single.billableDuration.inMilliseconds != 3500 ||
                ledger.records.single.costMicros != 17) {
              failures.add(EvalFailure(id, 'exact usage was not recorded'));
            }
            break;
          case 'duplicate':
            final first = backend.prepare(
              _cloudTtsReplayRequest(),
              AudioPrefetchCancellation(),
            );
            final second = backend.prepare(
              _cloudTtsReplayRequest(),
              AudioPrefetchCancellation(),
            );
            await _cloudTtsReplayFlush();
            synthesizer.complete();
            final prepared = await Future.wait(<Future<PreparedAudioSegment>>[
              first,
              second,
            ]);
            for (final segment in prepared) {
              await segment.release();
            }
            if (synthesizer.requests.length != 1 ||
                ledger.records.length != 1) {
              failures.add(
                EvalFailure(id, 'duplicate generation was charged'),
              );
            }
            break;
          case 'cancel':
            final cancellation = AudioPrefetchCancellation();
            final preparation = backend.prepare(
              _cloudTtsReplayRequest(),
              cancellation,
            );
            await _cloudTtsReplayFlush();
            cancellation.cancel();
            try {
              await preparation;
              failures.add(EvalFailure(id, 'cancelled request returned audio'));
            } on AudioPrefetchCancelledException {
              // Expected.
            }
            cancellationPropagated =
                synthesizer.cancellations.single.isCancelled;
            synthesizer.complete();
            await _cloudTtsReplayFlush();
            await _cloudTtsReplayFlush();
            if (!cancellationPropagated ||
                (await cache.listEntries()).isNotEmpty) {
              failures
                  .add(EvalFailure(id, 'cancel did not release cloud work'));
            }
            break;
          case 'contentChange':
            final first = await backend.prepare(
              _cloudTtsReplayRequest(),
              AudioPrefetchCancellation(),
            );
            final changed = await backend.prepare(
              _cloudTtsReplayRequest(revision: 'revision-v2'),
              AudioPrefetchCancellation(),
            );
            await first.release();
            await changed.release();
            if (synthesizer.requests.length != 2 ||
                synthesizer.requests
                        .map((request) => request.operationId)
                        .toSet()
                        .length !=
                    2) {
              failures.add(
                EvalFailure(id, 'changed content reused stale audio'),
              );
            }
            break;
          case 'network':
            try {
              await backend.prepare(
                _cloudTtsReplayRequest(),
                AudioPrefetchCancellation(),
              );
              failures.add(EvalFailure(id, 'metered network was accepted'));
            } on CloudTtsFailure catch (failure) {
              if (failure.code != CloudTtsFailureCode.wifiRequired) {
                failures.add(EvalFailure(id, 'wrong network failure code'));
              }
            }
            if (synthesizer.requests.isNotEmpty) {
              failures.add(EvalFailure(id, 'network gate called provider'));
            }
            break;
          default:
            failures.add(EvalFailure(id, 'unknown cloud TTS replay kind'));
            break;
        }
        providerCalls += synthesizer.requests.length;
        billedMilliseconds += ledger.records.fold<int>(
          0,
          (sum, record) => sum + record.billableDuration.inMilliseconds,
        );
        final diagnostics = <Object>[
          ...synthesizer.requests,
          ...ledger.records,
        ].join('\n');
        if (diagnostics.contains('PRIVATE-REPLAY-TEXT') ||
            diagnostics.contains('PRIVATE-REVISION')) {
          privateContentInDiagnostics = true;
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'cloud TTS replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'cloud-tts-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'providerCalls': providerCalls,
        'billedMilliseconds': billedMilliseconds,
        'cancellationPropagated': cancellationPropagated,
        'privateContentInDiagnostics': privateContentInDiagnostics,
      },
    );
  }

  Future<EvalReport> evaluatePodcastTranscriptionReplay() async {
    final manifest = _readJson('evals/podcast_transcription_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var ingestCalls = 0;
    var transcriptionCalls = 0;
    var resumeSkippedStages = false;
    var deletionComplete = false;
    var privateContentInDiagnostics = false;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final ingestor = _PodcastReplayIngestor(
        invalidFormat: kind == 'invalidFormat',
        pending: kind == 'duplicate',
      );
      final transcriber = _PodcastReplayTranscriber();
      final analyzer = _PodcastReplayAnalyzer();
      final checkpoints = MemoryPodcastTranscriptionCheckpointStore();
      final artifacts = MemoryPodcastTranscriptionArtifactStore();
      final usage = MemoryPodcastCloudUsageLedger();
      PodcastTranscriptionService service({
        PodcastIntelligenceProvider? intelligence,
      }) =>
          PodcastTranscriptionService(
            ingestor: ingestor,
            transcriptionProvider: transcriber,
            intelligenceProvider: intelligence ?? analyzer,
            checkpoints: checkpoints,
            artifacts: artifacts,
            usageLedger: usage,
            clock: const _PodcastReplayClock(),
          );

      try {
        switch (kind) {
          case 'longAudio':
            final result = await service().run(
              _podcastReplayRequest(),
              PodcastTaskCancellation(),
            );
            final billed = usage.records
                .where(
                  (record) =>
                      record.stage == PodcastCloudUsageStage.transcription,
                )
                .single
                .billableDuration;
            if (result.artifact.transcript.segments.length != 2 ||
                billed != const Duration(hours: 6)) {
              failures.add(EvalFailure(id, 'long audio bounds changed'));
            }
            break;
          case 'invalidFormat':
            try {
              await service().run(
                _podcastReplayRequest(),
                PodcastTaskCancellation(),
              );
              failures.add(EvalFailure(id, 'invalid format was accepted'));
            } on PodcastTranscriptionFailure catch (failure) {
              if (failure.code !=
                  PodcastTranscriptionFailureCode.invalidMedia) {
                failures.add(EvalFailure(id, 'wrong invalid format code'));
              }
            }
            if (transcriber.calls != 0) {
              failures.add(EvalFailure(id, 'invalid format reached Provider'));
            }
            break;
          case 'resume':
            final failing = _PodcastReplayAnalyzer()..fail = true;
            try {
              await service(intelligence: failing).run(
                _podcastReplayRequest(),
                PodcastTaskCancellation(),
              );
              failures.add(EvalFailure(id, 'interruption did not fail'));
            } on PodcastTranscriptionFailure catch (failure) {
              if (failure.code !=
                  PodcastTranscriptionFailureCode.intelligenceFailure) {
                failures.add(EvalFailure(id, 'wrong interruption code'));
              }
            }
            final resumed = await service().run(
              _podcastReplayRequest(),
              PodcastTaskCancellation(),
            );
            resumeSkippedStages = resumed.resumedAfterIngest &&
                resumed.resumedAfterTranscription &&
                ingestor.calls == 1 &&
                transcriber.calls == 1;
            if (!resumeSkippedStages) {
              failures.add(EvalFailure(id, 'checkpoint stages were repeated'));
            }
            break;
          case 'duplicate':
            final running = service();
            final first = running.run(
              _podcastReplayRequest(),
              PodcastTaskCancellation(),
            );
            final second = running.run(
              _podcastReplayRequest(),
              PodcastTaskCancellation(),
            );
            await _podcastReplayFlush();
            ingestor.complete();
            await Future.wait(<Future<PodcastTranscriptionRunResult>>[
              first,
              second,
            ]);
            if (ingestor.calls != 1 || transcriber.calls != 1) {
              failures.add(EvalFailure(id, 'duplicate cloud stages ran'));
            }
            break;
          case 'delete':
            final running = service();
            final result = await running.run(
              _podcastReplayRequest(),
              PodcastTaskCancellation(),
            );
            final diagnostics = <Object>[
              _podcastReplayRequest(),
              result.artifact,
              ...usage.records,
            ].join('\n');
            privateContentInDiagnostics =
                diagnostics.contains('PRIVATE-PODCAST-TRANSCRIPT') ||
                    diagnostics.contains('upload-private-replay');
            await running.delete('podcast-replay-job');
            deletionComplete = ingestor.deleted.length == 1 &&
                await checkpoints.read('podcast-replay-job') == null &&
                await artifacts.read('podcast-replay-job') == null &&
                usage.records.isEmpty;
            if (!deletionComplete || privateContentInDiagnostics) {
              failures.add(EvalFailure(id, 'privacy deletion failed'));
            }
            break;
          default:
            failures.add(EvalFailure(id, 'unknown transcription replay kind'));
            break;
        }
        ingestCalls += ingestor.calls;
        transcriptionCalls += transcriber.calls;
      } on Object catch (error) {
        failures.add(
          EvalFailure(id, 'podcast transcription replay failed: $error'),
        );
      }
    }
    return EvalReport(
      name: 'podcast-transcription-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'ingestCalls': ingestCalls,
        'transcriptionCalls': transcriptionCalls,
        'resumeSkippedStages': resumeSkippedStages,
        'deletionComplete': deletionComplete,
        'privateContentInDiagnostics': privateContentInDiagnostics,
      },
    );
  }

  Future<EvalReport> evaluateCloudGovernanceReplay() async {
    final manifest = _readJson('evals/cloud_governance_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var costTrip = false;
    var remoteDisabled = false;
    var forgedRejected = false;
    var localReads = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      try {
        switch (kind) {
          case 'costAnomaly':
            final guard = CloudCostGuard(
              spans: MemoryCloudSpanStore(),
              limits: _cloudGovernanceLimits(),
            );
            await guard.record(_cloudGovernanceSpan('cost-span-1', 60));
            final trip = await guard.record(
              _cloudGovernanceSpan(
                'cost-span-2',
                50,
                offset: const Duration(minutes: 10),
              ),
            );
            costTrip = trip?.reason == CloudCostTripReason.windowTotal &&
                trip?.observedCostMicros == 110;
            if (!costTrip)
              failures.add(EvalFailure(id, 'cost guard did not trip'));
            break;
          case 'selectiveKill':
            final store = MemoryCloudKillSwitchStore();
            final controller = _cloudGovernanceController(
              store,
              _cloudGovernanceSnapshot(
                version: 1,
                disabled: const <CloudCapability>{CloudCapability.cloudTts},
              ),
            );
            await controller.refresh();
            remoteDisabled = !(await controller
                        .decision(CloudCapability.cloudTts))
                    .allowed &&
                (await controller.decision(CloudCapability.managedAi)).allowed;
            if (!remoteDisabled) {
              failures.add(EvalFailure(id, 'selective kill switch failed'));
            }
            break;
          case 'forgedSnapshot':
            final store = MemoryCloudKillSwitchStore()
              ..value = _cloudGovernanceSnapshot(
                version: 1,
                disabled: const <CloudCapability>{},
              );
            final controller = _cloudGovernanceController(
              store,
              _cloudGovernanceSnapshot(
                version: 2,
                disabled: const <CloudCapability>{CloudCapability.managedAi},
                signature: 'forged',
              ),
            );
            try {
              await controller.refresh();
            } on CloudGovernanceFailure catch (failure) {
              forgedRejected =
                  failure.code == CloudGovernanceFailureCode.invalidSignature &&
                      store.value?.version == 1;
            }
            if (!forgedRejected) {
              failures.add(EvalFailure(id, 'forged snapshot replaced policy'));
            }
            break;
          case 'localFallback':
            final controller = _cloudGovernanceController(
              MemoryCloudKillSwitchStore(),
              _cloudGovernanceSnapshot(
                version: 1,
                disabled: const <CloudCapability>{},
              ),
            );
            final cloud = await controller.decision(CloudCapability.managedAi);
            String localRead() {
              localReads += 1;
              return 'offline article';
            }

            if (cloud.allowed ||
                !cloud.localCoreUnaffected ||
                localRead() != 'offline article') {
              failures.add(EvalFailure(id, 'local fallback was blocked'));
            }
            break;
          default:
            failures.add(EvalFailure(id, 'unknown cloud governance kind'));
            break;
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'cloud governance replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'cloud-governance-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'costTrip': costTrip,
        'remoteDisabled': remoteDisabled,
        'forgedRejected': forgedRejected,
        'localReads': localReads,
        'privateContentInDiagnostics': false,
      },
    );
  }

  EvalReport evaluateAiReplay() {
    final manifest = _readJson('evals/summary_cases.json');
    final cases = _list(manifest['cases']);
    final gate = _map(manifest['qualityGate']);
    final failures = <EvalFailure>[];
    final languages = <String>{};
    final contentTypes = <String>{};
    var highRiskCases = 0;
    var requiredFacts = 0;
    var matchedFacts = 0;
    var forbiddenAssertions = 0;
    var forbiddenHits = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      Map<String, Object?> fixture;
      try {
        fixture = _readJson(item['fixture'] as String);
        final language = item['language'] as String;
        final contentType = item['contentType'] as String;
        final riskLevel = item['riskLevel'] as String;
        if (fixture['id'] != id ||
            fixture['language'] != language ||
            fixture['contentType'] != contentType ||
            fixture['riskLevel'] != riskLevel ||
            (fixture['plainText'] as String).trim().isEmpty) {
          failures.add(EvalFailure(id, 'fixture metadata does not match case'));
          continue;
        }
        languages.add(language);
        contentTypes.add(contentType);
        if (riskLevel == 'high') highRiskCases++;
      } on Object {
        failures.add(EvalFailure(id, 'invalid or missing source fixture'));
        continue;
      }
      final replay = _map(item['replay']);
      ArticleSummary summary;
      try {
        summary = const ArticleSummarySchema().parse(
          jsonEncode(replay),
          model: item['model'] as String,
          promptVersion: item['promptVersion'] as String,
          expectedLanguage: item['language'] as String,
        );
      } on AiSchemaFailure catch (failure) {
        failures.add(EvalFailure(id, 'schema failure: ${failure.code.name}'));
        continue;
      }
      final combined = <String>[
        summary.oneLine,
        ...summary.keyPoints,
        summary.whyItMatters,
        ...summary.topics,
        ...summary.entities,
      ].join(' ');
      final normalizedOutput = _normalizedEvalText(combined);
      final source = _normalizedEvalText(fixture['plainText'] as String);
      try {
        for (final fact in _list(item['requiredFacts'])) {
          final factId = fact['id'] as String;
          final sourceAnyOf = _strings(fact['sourceAnyOf']);
          final outputAnyOf = _strings(fact['outputAnyOf']);
          if (!_containsAny(source, sourceAnyOf)) {
            failures.add(
              EvalFailure(id, 'golden fact has no source evidence: $factId'),
            );
            continue;
          }
          requiredFacts++;
          if (_containsAny(normalizedOutput, outputAnyOf)) {
            matchedFacts++;
          }
        }
        for (final forbidden in _list(item['forbiddenClaims'])) {
          final claimId = forbidden['id'] as String;
          final outputAnyOf = _strings(forbidden['outputAnyOf']);
          forbiddenAssertions++;
          if (_containsAny(normalizedOutput, outputAnyOf)) {
            forbiddenHits++;
            failures.add(
              EvalFailure(id, 'forbidden claim present: $claimId'),
            );
          }
        }
      } on Object {
        failures.add(EvalFailure(id, 'invalid fact assertion schema'));
      }
    }
    final coverage = requiredFacts == 0 ? 0.0 : matchedFacts / requiredFacts;
    final forbiddenHitRate =
        forbiddenAssertions == 0 ? 1.0 : forbiddenHits / forbiddenAssertions;
    final minimumCases = gate['minimumCases'] as int;
    final minimumCoverage =
        (gate['minimumNecessaryFactCoverage'] as num).toDouble();
    final maximumForbiddenRate =
        (gate['maximumForbiddenClaimHitRate'] as num).toDouble();
    final minimumHighRiskCases = gate['minimumHighRiskCases'] as int;
    final requiredLanguages = _strings(gate['requiredLanguages']).toSet();
    final requiredContentTypes = _strings(gate['requiredContentTypes']).toSet();
    if (cases.length < minimumCases) {
      failures.add(
        EvalFailure(
          'quality-gate',
          'golden case count ${cases.length} is below $minimumCases',
        ),
      );
    }
    if (coverage < minimumCoverage) {
      failures.add(
        EvalFailure(
          'quality-gate',
          'necessary fact coverage ${_percentage(coverage)} is below '
              '${_percentage(minimumCoverage)}',
        ),
      );
    }
    if (forbiddenHitRate > maximumForbiddenRate) {
      failures.add(
        EvalFailure(
          'quality-gate',
          'forbidden claim hit rate ${_percentage(forbiddenHitRate)} exceeds '
              '${_percentage(maximumForbiddenRate)}',
        ),
      );
    }
    if (highRiskCases < minimumHighRiskCases) {
      failures.add(
        EvalFailure(
          'quality-gate',
          'high-risk case count $highRiskCases is below $minimumHighRiskCases',
        ),
      );
    }
    if (!languages.containsAll(requiredLanguages)) {
      failures.add(
        EvalFailure('quality-gate', 'required summary languages are missing'),
      );
    }
    if (!contentTypes.containsAll(requiredContentTypes)) {
      failures.add(
        EvalFailure('quality-gate', 'required content types are missing'),
      );
    }
    return EvalReport(
      name: 'ai-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'necessaryFactCoverage': coverage,
        'matchedNecessaryFacts': matchedFacts,
        'totalNecessaryFacts': requiredFacts,
        'forbiddenClaimHitRate': forbiddenHitRate,
        'forbiddenClaimHits': forbiddenHits,
        'forbiddenClaimAssertions': forbiddenAssertions,
        'languages': languages.toList()..sort(),
        'contentTypes': contentTypes.toList()..sort(),
        'highRiskCases': highRiskCases,
      },
    );
  }

  Future<EvalReport> evaluateAiProviderReplay() async {
    final manifest = _readJson('evals/openai_compatible_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    final catalog = AiProviderPresetCatalog.standard();

    for (final item in cases) {
      final id = item['id'] as String;
      final preset = catalog.resolve(item['presetId'] as String);
      final configuration = preset.configure(
        model: item['model'] as String,
        apiKey: OpaqueAiApiKey('replay-only-key'),
      );
      final transport = _ReplayAiHttpTransport(
        AiHttpResponse(
          statusCode: 200,
          body: jsonEncode(_map(item['response'])),
        ),
      );
      final provider = OpenAiCompatibleProvider(
        configuration: configuration,
        transport: transport,
        clock: const _ZeroAiClock(),
      );
      final prompt = articleSummaryPromptV1.render(
        <String, String>{
          'articleId': id,
          'title': 'Replay title',
          'content': 'Replay content is deterministic.',
          'language': item['language'] as String,
        },
      );
      try {
        final response = await provider.complete(
          AiProviderRequest(
            operationId: id,
            model: configuration.model,
            prompt: prompt,
            responseSchema: ArticleSummarySchema.jsonSchema,
          ),
        );
        const ArticleSummarySchema().parse(
          response.output,
          model: response.model,
          promptVersion: prompt.versionKey,
          expectedLanguage: item['language'] as String,
        );
        final sent = transport.request;
        if (sent == null) {
          failures.add(EvalFailure(id, 'provider sent no request'));
          continue;
        }
        if (sent.uri != configuration.chatCompletionsUri) {
          failures.add(EvalFailure(id, 'unexpected compatibility endpoint'));
        }
        if (sent.toString().contains('replay-only-key')) {
          failures.add(EvalFailure(id, 'request diagnostics leaked key'));
        }
        final body = _map(jsonDecode(sent.body));
        final expectedMode = item['expectedOutputMode'] as String;
        final actualMode = switch (body['response_format']) {
          null => 'promptOnly',
          final Map value =>
            _map(value)['type'] == 'json_schema' ? 'jsonSchema' : 'jsonObject',
          _ => 'invalid',
        };
        if (actualMode != expectedMode) {
          failures.add(
            EvalFailure(
              id,
              'expected output mode $expectedMode, got $actualMode',
            ),
          );
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'provider replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'ai-provider-replay',
      total: cases.length,
      failures: failures,
    );
  }

  Future<EvalReport> evaluateAiLongReplay() async {
    final manifest = _readJson('evals/long_summary_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];

    for (final item in cases) {
      final id = item['id'] as String;
      final article = Article(
        id: id,
        url: Uri.parse('https://replay.invalid/$id'),
        title: 'Deterministic long article',
        source: ContentSource.web,
        plainText: _strings(item['paragraphs']).join('\n\n'),
      );
      const budget = AiContextBudget(
        mapContentCharacters: 1000,
        maxMapPromptCharacters: 5000,
        maxReducePromptCharacters: 10000,
      );
      final chunks = const ArticleSummaryChunkPlanner().plan(
        articleId: id,
        content: article.plainText!,
        budget: budget,
      );
      final mapFacts = (item['mapFacts'] as List<Object?>)
          .map((value) => _strings(value))
          .toList(growable: false);
      if (mapFacts.length != chunks.length) {
        failures.add(
          EvalFailure(id, 'map replay count does not match planned chunks'),
        );
        continue;
      }
      final provider = _LongSummaryReplayProvider(
        articleId: id,
        chunks: chunks,
        mapFacts: mapFacts,
        finalOutput: jsonEncode(_map(item['replay'])),
        language: item['language'] as String,
      );
      final service = LongArticleSummaryService(
        provider,
        checkpoints: MemoryAiLongSummaryCheckpointStore(),
        model: item['model'] as String,
        outputLanguage: item['language'] as String,
        budget: budget,
        pricing: const AiTokenPricing(
          inputUsdPerMillion: 1,
          outputUsdPerMillion: 4,
        ),
      );
      try {
        final result = await service.summarize(article);
        final facts = result.sourcedFacts.map((fact) => fact.text).toList();
        for (final required in _strings(item['requiredSourcedFacts'])) {
          if (!facts.contains(required)) {
            failures.add(EvalFailure(id, 'sourced fact missing: $required'));
          }
        }
        if (facts.where((fact) => fact == 'shared cross-block fact').length !=
            1) {
          failures
              .add(EvalFailure(id, 'cross-block fact was not deduplicated'));
        }
        if (result.sourcedFacts.any(
          (fact) => fact.citations.any(
            (citation) => citation.articleId != id,
          ),
        )) {
          failures.add(EvalFailure(id, 'citation lost source article id'));
        }
        if (result.summary.language != item['language']) {
          failures.add(EvalFailure(id, 'final language mismatch'));
        }
        if (provider.requests.length >
            service.preflight(article).estimate.providerCalls) {
          failures.add(EvalFailure(id, 'provider calls exceeded preflight'));
        }
        if (result.preflightEstimate.upperBoundUsd <= 0) {
          failures.add(EvalFailure(id, 'cost estimate is not positive'));
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'long summary replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'ai-long-replay',
      total: cases.length,
      failures: failures,
    );
  }

  Future<EvalReport> evaluateAiCacheReplay() async {
    final manifest = _readJson('evals/summary_cache_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];

    for (final item in cases) {
      final id = item['id'] as String;
      final model = item['model'] as String;
      final language = item['language'] as String;
      final article = Article(
        id: id,
        url: Uri.parse('https://replay.invalid/$id'),
        title: 'Deterministic cache article',
        source: ContentSource.web,
        plainText: item['content'] as String,
      );
      final provider = _CacheReplayProvider(jsonEncode(_map(item['replay'])));
      final artifacts = _ReplayArtifactRepository();
      final requests = AiSummaryRequestCoalescer();
      final service = SummaryService(
        provider,
        model: model,
        outputLanguage: language,
        artifacts: artifacts,
        clock: const _ReplayClock(),
        requests: requests,
        inputUsdPerMillion: 2,
        outputUsdPerMillion: 8,
      );
      try {
        await Future.wait(<Future<ArticleSummary>>[
          service.summarize(article),
          service.summarize(article),
        ]);
        final cached = await SummaryService(
          provider,
          model: model,
          outputLanguage: language,
          artifacts: artifacts,
          clock: const _ReplayClock(),
          requests: AiSummaryRequestCoalescer(),
          inputUsdPerMillion: 2,
          outputUsdPerMillion: 8,
        ).summarize(article);
        final artifact = artifacts.values.single;
        if (provider.requests.length != 1) {
          failures.add(
            EvalFailure(id, 'cache/coalescing made duplicate provider calls'),
          );
        }
        if (cached.oneLine != item['expectedOneLine']) {
          failures.add(EvalFailure(id, 'cache returned a different summary'));
        }
        if (artifact.providerCalls != 1 ||
            artifact.inputTokens != 10 ||
            artifact.outputTokens != 5 ||
            artifact.costUsd <= 0) {
          failures.add(EvalFailure(id, 'cache cost metadata is incomplete'));
        }
        final base = artifact.cacheKey;
        final variants = <String>{
          base,
          summaryCacheKey(
            contentHash: summaryContentHash('${article.plainText} changed'),
            model: model,
            promptVersion: artifact.promptVersion,
            language: language,
          ),
          summaryCacheKey(
            contentHash: artifact.contentHash,
            model: '$model-next',
            promptVersion: artifact.promptVersion,
            language: language,
          ),
          summaryCacheKey(
            contentHash: artifact.contentHash,
            model: model,
            promptVersion: 'article-summary@2',
            language: language,
          ),
          summaryCacheKey(
            contentHash: artifact.contentHash,
            model: model,
            promptVersion: artifact.promptVersion,
            language: language == 'zh-CN' ? 'en-US' : 'zh-CN',
          ),
        };
        if (variants.length != 5) {
          failures.add(EvalFailure(id, 'cache invalidation key collided'));
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'summary cache replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'ai-cache-replay',
      total: cases.length,
      failures: failures,
    );
  }

  Future<EvalReport> evaluateManagedAiGatewayReplay() async {
    final manifest = _readJson('evals/managed_ai_gateway_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var totalProviderCalls = 0;
    var totalCostMicros = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final primary = _ManagedGatewayReplayProvider(
        id: 'primary-provider',
        fail: kind == 'providerFailure',
        invalidOutput: kind == 'qualityFallback',
      );
      final fallback = _ManagedGatewayReplayProvider(
        id: 'fallback-provider',
      );
      final gateway = ManagedAiGateway(
        routes: ManagedAiRoutingTable(<ManagedAiRoutingRule>[
          ManagedAiRoutingRule(
            plan: ManagedAiPlan.free,
            capability: ManagedAiCapability.articleSummary,
            targets: <ManagedAiRouteTarget>[
              _managedGatewayTarget('primary.route', primary.id),
              _managedGatewayTarget('fallback.route', fallback.id),
            ],
          ),
        ]),
        upstreams: StaticManagedAiUpstreamRegistry(<String, AiProvider>{
          'primary.route': primary,
          'fallback.route': fallback,
        }),
        outputValidator: const ArticleSummaryManagedAiOutputValidator(),
        clock: const _ManagedGatewayReplayClock(),
        timeoutGuard: _ManagedGatewayReplayTimeoutGuard(
          timeOutFirst: kind == 'timeout',
        ),
      );
      final prompt = articleSummaryPromptV1.render(<String, String>{
        'articleId': id,
        'title': 'Deterministic managed AI replay',
        'content': 'Synthetic replay content with no private user data.',
        'language': 'zh-CN',
      });
      final request = ManagedAiGatewayRequest(
        operationId: id,
        capability: ManagedAiCapability.articleSummary,
        prompt: prompt,
        responseSchema: ArticleSummarySchema.jsonSchema,
        outputLanguage: 'zh-CN',
        timeout: const Duration(seconds: 5),
      );
      final principal = ManagedAiPrincipal(
        accountKey: 'replay-account',
        plan: ManagedAiPlan.free,
      );

      try {
        final responses = kind == 'duplicate'
            ? await Future.wait(<Future<ManagedAiGatewayResponse>>[
                gateway.complete(principal: principal, request: request),
                gateway.complete(principal: principal, request: request),
              ])
            : <ManagedAiGatewayResponse>[
                await gateway.complete(
                  principal: principal,
                  request: request,
                ),
              ];
        final response = responses.first;
        if (responses.any((value) => !identical(value, response))) {
          failures.add(EvalFailure(id, 'duplicate result was not coalesced'));
        }
        if (response.routeId != item['expectedRoute']) {
          failures.add(
            EvalFailure(
              id,
              'expected route ${item['expectedRoute']}, got ${response.routeId}',
            ),
          );
        }
        if (primary.requests.length != item['expectedPrimaryCalls'] ||
            fallback.requests.length != item['expectedFallbackCalls']) {
          failures.add(EvalFailure(id, 'provider call count was not bounded'));
        }
        totalProviderCalls +=
            primary.requests.length + fallback.requests.length;
        totalCostMicros += response.totalCostMicros;
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'managed gateway replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'managed-ai-gateway-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'providerCalls': totalProviderCalls,
        'acceptedCostMicros': totalCostMicros,
        'privateContentInDiagnostics': false,
      },
    );
  }

  Future<EvalReport> evaluateCommerceEntitlementReplay() async {
    final manifest = _readJson('evals/commerce_entitlement_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var freeChecks = 0;
    var premiumChecks = 0;
    var forgedSnapshotsRejected = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final now = DateTime.utc(2026, 8, 6, 12);
      final store = MemoryEntitlementSnapshotStore();
      final snapshot = _commerceSnapshot(
        revision: (item['revision'] as int?) ?? 1,
        plan: item['plan'] == 'trial'
            ? EntitlementPlan.trial
            : EntitlementPlan.pro,
        refreshAfter: kind == 'offline-cache'
            ? DateTime.utc(2026, 8, 6, 11)
            : kind == 'expired-trial'
                ? DateTime.utc(2026, 8, 4, 18)
                : DateTime.utc(2026, 8, 6, 18),
        validUntil: kind == 'expired-trial'
            ? DateTime.utc(2026, 8, 5, 12)
            : DateTime.utc(2026, 8, 7, 12),
        issuedAt: kind == 'expired-trial'
            ? DateTime.utc(2026, 8, 4, 12)
            : DateTime.utc(2026, 8, 6, 10),
        signature: kind == 'forged' ? 'forged' : 'valid',
      );
      if (kind != 'free-guest' && kind != 'forged') store.value = snapshot;
      final gate = EntitlementGate(
        subjectHash: kind == 'free-guest' ? null : _commerceSubject,
        source: _CommerceReplaySource(snapshot),
        verifier: const _CommerceReplayVerifier(),
        store: store,
        clock: _CommerceReplayClock(now),
      );

      try {
        switch (kind) {
          case 'free-guest':
            for (final key in freeEntitlements) {
              final decision =
                  await gate.decision(key, networkAvailable: false);
              freeChecks += 1;
              if (!decision.allowed ||
                  decision.reason != EntitlementGateReason.freeBaseline) {
                failures.add(EvalFailure(id, '${key.name} lost Free access'));
              }
            }
          case 'verified-pro':
            final decision = await gate.decision(
              EntitlementKey.managedAi,
              networkAvailable: true,
            );
            premiumChecks += 1;
            if (!decision.allowed ||
                decision.reason != EntitlementGateReason.verifiedSnapshot) {
              failures.add(EvalFailure(id, 'verified Pro grant was denied'));
            }
          case 'offline-cache':
            final decision = await gate.decision(
              EntitlementKey.managedAi,
              networkAvailable: false,
            );
            premiumChecks += 1;
            if (!decision.allowed ||
                decision.reason != EntitlementGateReason.offlineCache) {
              failures.add(EvalFailure(id, 'bounded offline grant was denied'));
            }
          case 'expired-trial':
            final paid = await gate.decision(
              EntitlementKey.managedAi,
              networkAvailable: false,
            );
            premiumChecks += 1;
            if (paid.allowed ||
                paid.reason != EntitlementGateReason.expiredSnapshot) {
              failures.add(EvalFailure(id, 'expired trial kept paid access'));
            }
            for (final key in freeEntitlements) {
              freeChecks += 1;
              if (!(await gate.decision(key, networkAvailable: false))
                  .allowed) {
                failures.add(EvalFailure(id, '${key.name} lost after trial'));
              }
            }
          case 'forged':
            try {
              await gate.refresh();
              failures.add(EvalFailure(id, 'forged snapshot was accepted'));
            } on EntitlementFailure catch (error) {
              if (error.code == EntitlementFailureCode.invalidSignature) {
                forgedSnapshotsRejected += 1;
              } else {
                failures.add(
                  EvalFailure(id, 'unexpected failure ${error.code.name}'),
                );
              }
            }
          default:
            failures.add(EvalFailure(id, 'unknown replay kind $kind'));
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'entitlement replay failed: $error'));
      }
    }

    final appLibrary = Directory(_path('apps/river_app/lib'));
    final forbiddenUiBinding = RegExp(
      r'\b(productId|productIdentifier|storeProductId|sku)\b',
      caseSensitive: false,
    );
    final boundFiles = appLibrary
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => forbiddenUiBinding.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList(growable: false);
    if (boundFiles.isNotEmpty) {
      failures.add(
        const EvalFailure(
          'semantic-gate',
          'application UI references a store product identifier',
        ),
      );
    }

    return EvalReport(
      name: 'commerce-entitlement-replay',
      total: cases.length + 1,
      failures: failures,
      metrics: <String, Object>{
        'freeChecks': freeChecks,
        'premiumChecks': premiumChecks,
        'forgedSnapshotsRejected': forgedSnapshotsRejected,
        'uiProductIdentifierReferences': boundFiles.length,
      },
    );
  }

  Future<EvalReport> evaluateUsageLedgerReplay() async {
    final manifest = _readJson('evals/usage_ledger_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var committedUnits = 0;
    var refundedUnits = 0;
    var rejectedReservations = 0;
    var notices = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final ledger = _replayUsageLedger();
      try {
        switch (kind) {
          case 'retry':
            await _replayReserve(ledger, '$id-operation', 3);
            await _replayReserve(ledger, '$id-operation', 3);
            await ledger.settle(
              operationId: '$id-operation',
              producedUsableResult: true,
              at: _usageReplayNow.add(const Duration(seconds: 1)),
            );
            await ledger.settle(
              operationId: '$id-operation',
              producedUsableResult: true,
              at: _usageReplayNow.add(const Duration(seconds: 2)),
            );
            final snapshot = await ledger.snapshot('grant-replay');
            committedUnits += snapshot.used;
            if (snapshot.used != 3) {
              failures.add(EvalFailure(id, 'retry charged more than once'));
            }
          case 'failed':
            await _replayReserve(ledger, '$id-operation', 4);
            await ledger.settle(
              operationId: '$id-operation',
              producedUsableResult: false,
              at: _usageReplayNow.add(const Duration(seconds: 1)),
            );
            if ((await ledger.snapshot('grant-replay')).used != 0) {
              failures.add(EvalFailure(id, 'failed result consumed usage'));
            }
          case 'refund':
            await _replayReserve(ledger, '$id-operation', 5);
            await ledger.settle(
              operationId: '$id-operation',
              producedUsableResult: true,
              at: _usageReplayNow.add(const Duration(seconds: 1)),
            );
            await ledger.refund(
              operationId: '$id-operation',
              at: _usageReplayNow.add(const Duration(seconds: 2)),
            );
            await ledger.refund(
              operationId: '$id-operation',
              at: _usageReplayNow.add(const Duration(seconds: 3)),
            );
            final snapshot = await ledger.snapshot('grant-replay');
            refundedUnits += 5;
            if (snapshot.used != 0) {
              failures.add(EvalFailure(id, 'refund did not restore usage'));
            }
          case 'concurrent':
            final results = await Future.wait<Object>(
              <Future<UsageLedgerEntry>>[
                _replayReserve(ledger, '$id-a', 6),
                _replayReserve(ledger, '$id-b', 6),
              ].map((future) async {
                try {
                  return await future;
                } on Object catch (error) {
                  return error;
                }
              }),
            );
            rejectedReservations +=
                results.whereType<UsageLedgerFailure>().length;
            if (results.whereType<UsageLedgerEntry>().length != 1 ||
                rejectedReservations != 1) {
              failures.add(EvalFailure(id, 'concurrency overdrew the grant'));
            }
          case 'thresholds':
            await _replayCommit(ledger, '$id-a', 8);
            await _replayCommit(ledger, '$id-b', 2);
            final snapshot = await ledger.snapshot('grant-replay');
            notices += snapshot.notices.length;
            if (snapshot.notices.length != 2) {
              failures.add(EvalFailure(id, 'threshold notices were not exact'));
            }
          default:
            failures.add(EvalFailure(id, 'unknown replay kind $kind'));
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'usage replay failed: $error'));
      }
    }

    return EvalReport(
      name: 'usage-ledger-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'committedUnits': committedUnits,
        'refundedUnits': refundedUnits,
        'rejectedReservations': rejectedReservations,
        'thresholdNotices': notices,
      },
    );
  }

  Future<EvalReport> evaluateFreeProductReplay() async {
    final failures = <EvalFailure>[];
    final states = <String, EntitlementGate>{
      'guest': _freeReplayGate(kind: 'guest'),
      'expired-trial': _freeReplayGate(kind: 'expired-trial'),
      'pro-downgrade': _freeReplayGate(kind: 'pro-downgrade'),
    };
    var wechatExtractions = 0;
    var offlineReads = 0;
    var speechSegments = 0;
    var podcastEpisodes = 0;
    var knowledgeItems = 0;
    var exportBundles = 0;

    final wechatHtml =
        File(_path('fixtures/html/wechat_synthetic.html')).readAsStringSync();
    final podcastXml =
        File(_path('fixtures/feeds/podcast_rss.xml')).readAsStringSync();

    for (final state in states.entries) {
      final id = state.key;
      final gate = state.value;
      try {
        await _requireFree(gate, EntitlementKey.fullTextExtraction);
        final extraction = await const LayeredFullTextExtractor().extract(
          ExtractionRequest(
            sourceUri: Uri.parse('https://mp.weixin.qq.com/s/free-replay'),
            pageHtml: wechatHtml,
          ),
        );
        if (extraction is! ExtractionSuccess ||
            !extraction.article.plainText.contains('本地优先架构')) {
          failures.add(EvalFailure(id, 'WeChat full text was unavailable'));
          continue;
        }
        wechatExtractions += 1;

        await _requireFree(gate, EntitlementKey.offlineReading);
        final cachedBody = extraction.article.plainText;
        if (!cachedBody.contains('用户的数据控制权')) {
          failures.add(EvalFailure(id, 'offline body could not be reused'));
        } else {
          offlineReads += 1;
        }

        await _requireFree(gate, EntitlementKey.systemTts);
        final segments = const ArticleSpeechSegmenter().segment(cachedBody);
        if (segments.isEmpty ||
            segments.any((segment) => segment.text.isEmpty)) {
          failures.add(EvalFailure(id, 'system TTS plan was empty'));
        } else {
          speechSegments += segments.length;
        }

        await _requireFree(gate, EntitlementKey.podcastPlayback);
        final podcast = const PodcastFeedParser().parse(
          podcastXml,
          sourceUri: Uri.parse('https://podcast.example.test/feed.xml'),
        );
        if (podcast.episodes.isEmpty) {
          failures.add(EvalFailure(id, 'podcast playback source was empty'));
        } else {
          podcastEpisodes += podcast.episodes.length;
        }

        await _requireFree(gate, EntitlementKey.localKnowledge);
        final item = _freeKnowledgeItem(id, cachedBody);
        if (item.markdown.isEmpty || item.contentHash.length != 71) {
          failures.add(EvalFailure(id, 'local knowledge item was invalid'));
        } else {
          knowledgeItems += 1;
        }

        await _requireFree(gate, EntitlementKey.portableExport);
        final bundle =
            await const KnowledgeMarkdownExportBuilder().build(<KnowledgeItem>[
          item,
        ]);
        final archive = const KnowledgeZipEncoder().encode(bundle);
        if (bundle.markdownFiles.length != 1 ||
            archive.length < 4 ||
            archive[0] != 0x50 ||
            archive[1] != 0x4b) {
          failures.add(EvalFailure(id, 'portable export was incomplete'));
        } else {
          exportBundles += 1;
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'Free product replay failed: $error'));
      }
    }

    return EvalReport(
      name: 'free-product-replay',
      total: states.length * 6,
      failures: failures,
      metrics: <String, Object>{
        'states': states.length,
        'wechatExtractions': wechatExtractions,
        'offlineReads': offlineReads,
        'speechSegments': speechSegments,
        'podcastEpisodes': podcastEpisodes,
        'knowledgeItems': knowledgeItems,
        'exportBundles': exportBundles,
        'networkCalls': 0,
      },
    );
  }

  Future<EvalReport> evaluateKnowledgeVectorReplay() async {
    final manifest = _readJson('evals/knowledge_vector_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var providerCalls = 0;
    var skippedBuilds = 0;
    var rebuiltBuilds = 0;
    var deletedDocuments = 0;
    var recoveredCorruptions = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final provider = _KnowledgeVectorReplayProvider();
      final index = MemoryKnowledgeVectorIndex();
      final source = _knowledgeVectorReplayItem(id, _knowledgeVectorReplayText);
      KnowledgeVectorIndexer service({
        KnowledgeVectorIndex? target,
        int revision = 1,
      }) =>
          KnowledgeVectorIndexer(
            profile: _knowledgeVectorReplayProfile(revision: revision),
            provider: provider,
            index: target ?? index,
            chunker: const KnowledgeChunker(
              maximumCharacters: 128,
              overlapCharacters: 16,
            ),
            maximumBatchSize: 2,
            clock: const _KnowledgeVectorReplayClock(),
          );

      try {
        switch (kind) {
          case 'buildAndSkip':
            final first = await service().indexItem(source);
            final second = await service().indexItem(source);
            if (first.skipped ||
                !second.skipped ||
                index.documents.length != 1) {
              failures.add(EvalFailure(id, 'unchanged content was rebuilt'));
            }
            rebuiltBuilds += first.skipped ? 0 : 1;
            skippedBuilds += second.skipped ? 1 : 0;
          case 'modelUpgrade':
            final first = await service().indexItem(source);
            final upgraded = await service(revision: 2).indexItem(source);
            if (upgraded.skipped ||
                upgraded.recoveredCorruption ||
                upgraded.document.profileIdentity ==
                    first.document.profileIdentity) {
              failures.add(EvalFailure(id, 'model upgrade did not rebuild'));
            }
            rebuiltBuilds += 2;
          case 'contentChange':
            await service().indexItem(source);
            final changed = _knowledgeVectorReplayItem(
              id,
              'Changed $_knowledgeVectorReplayText',
            );
            final result = await service().indexItem(changed);
            if (result.skipped ||
                index.documents.single.contentHash != changed.contentHash ||
                index.documents.single.records.any(
                  (record) => record.chunk.contentHash != changed.contentHash,
                )) {
              failures.add(EvalFailure(id, 'stale content remained indexed'));
            }
            rebuiltBuilds += 2;
          case 'delete':
            await service().indexItem(source);
            await service().deleteItem(source.id);
            if (index.documents.isNotEmpty) {
              failures.add(EvalFailure(id, 'deleted vectors remained indexed'));
            } else {
              deletedDocuments += 1;
            }
            rebuiltBuilds += 1;
          case 'corruptionRecovery':
            final valid = await service().indexItem(source);
            final corrupt = _KnowledgeVectorReplayCorruptIndex(valid.document);
            final recovered = await service(target: corrupt).indexItem(source);
            if (!recovered.recoveredCorruption || corrupt.replacements != 1) {
              failures.add(EvalFailure(id, 'corrupt index was not replaced'));
            } else {
              recoveredCorruptions += 1;
            }
            rebuiltBuilds += 2;
          default:
            failures.add(EvalFailure(id, 'unknown vector replay kind $kind'));
        }
        providerCalls += provider.calls;
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'knowledge vector replay failed: $error'));
      }
    }

    return EvalReport(
      name: 'knowledge-vector-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'providerCalls': providerCalls,
        'skippedBuilds': skippedBuilds,
        'rebuiltBuilds': rebuiltBuilds,
        'deletedDocuments': deletedDocuments,
        'recoveredCorruptions': recoveredCorruptions,
      },
    );
  }

  Future<EvalReport> evaluateKnowledgeSearchReplay() async {
    final manifest = _readJson('evals/knowledge_search_cases.json');
    final documents = _list(manifest['documents']);
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    final provider = _KnowledgeSearchReplayProvider();
    final index = MemoryKnowledgeVectorIndex();
    final profile = _knowledgeSearchReplayProfile();
    final indexer = KnowledgeVectorIndexer(
      profile: profile,
      provider: provider,
      index: index,
      chunker: const KnowledgeChunker(
        maximumCharacters: 128,
        overlapCharacters: 16,
      ),
      clock: const _KnowledgeVectorReplayClock(),
    );
    for (final document in documents) {
      await indexer.indexItem(_knowledgeSearchReplayItem(document));
    }
    final search = KnowledgeSemanticSearch(
      profile: profile,
      provider: provider,
      index: index,
      maximumEvidencePerItem: 2,
    );
    var relevantRetrieved = 0;
    var retrieved = 0;
    var relevantTotal = 0;
    var evidenceHits = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final relevant = _strings(item['relevant']).toSet();
      final limit = item['limit'] as int;
      try {
        final hits = item['mode'] == 'similar'
            ? await search.similarItems(
                item['itemId'] as String,
                limit: limit,
              )
            : await search.search(
                item['query'] as String,
                limit: limit,
                filter: _knowledgeSearchReplayFilter(item['filter']),
              );
        final resultIds = hits.map((hit) => hit.itemId).toSet();
        final matched = resultIds.intersection(relevant).length;
        relevantRetrieved += matched;
        retrieved += hits.length;
        relevantTotal += relevant.length;
        evidenceHits += hits.where((hit) => hit.evidence.isNotEmpty).length;
        if (matched != relevant.length || hits.length != limit) {
          failures.add(
            EvalFailure(
              id,
              'expected ${relevant.join(',')}, got ${resultIds.join(',')}',
            ),
          );
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'knowledge search replay failed: $error'));
      }
    }
    final recall = relevantTotal == 0 ? 1.0 : relevantRetrieved / relevantTotal;
    final precision = retrieved == 0 ? 1.0 : relevantRetrieved / retrieved;
    if (recall < 0.90) {
      failures
          .add(EvalFailure('recall-gate', 'Recall@K $recall is below 0.90'));
    }
    if (precision < 0.90) {
      failures.add(
        EvalFailure('precision-gate', 'Precision@K $precision is below 0.90'),
      );
    }

    return EvalReport(
      name: 'knowledge-search-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'recallAtK': recall,
        'precisionAtK': precision,
        'relevantRetrieved': relevantRetrieved,
        'relevantTotal': relevantTotal,
        'retrieved': retrieved,
        'evidenceHits': evidenceHits,
        'queryEmbeddingCalls': provider.queryCalls,
      },
    );
  }

  Future<EvalReport> evaluateKnowledgeQuestionReplay() async {
    final searchManifest = _readJson('evals/knowledge_search_cases.json');
    final casesManifest = _readJson('evals/knowledge_qa_cases.json');
    final cases = _list(casesManifest['cases']);
    final embeddings = _KnowledgeSearchReplayProvider();
    final index = MemoryKnowledgeVectorIndex();
    final profile = _knowledgeSearchReplayProfile();
    final indexer = KnowledgeVectorIndexer(
      profile: profile,
      provider: embeddings,
      index: index,
      chunker: const KnowledgeChunker(
        maximumCharacters: 128,
        overlapCharacters: 16,
      ),
      clock: const _KnowledgeVectorReplayClock(),
    );
    for (final document in _list(searchManifest['documents'])) {
      await indexer.indexItem(_knowledgeSearchReplayItem(document));
    }
    final search = KnowledgeSemanticSearch(
      profile: profile,
      provider: embeddings,
      index: index,
      maximumEvidencePerItem: 2,
    );
    final failures = <EvalFailure>[];
    var answered = 0;
    var refusedWithoutProvider = 0;
    var providerRefusals = 0;
    var rejectedOutputs = 0;
    var materializedCitations = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final provider = _KnowledgeQuestionReplayProvider(kind);
      final service = KnowledgeGroundedQuestionAnswering(
        search: search,
        provider: provider,
      );
      try {
        final result = await service.ask(item['question'] as String);
        switch (kind) {
          case 'answered':
            if (result.outcome != KnowledgeAnswerOutcome.answered ||
                result.statements.any((value) => value.citations.isEmpty)) {
              failures.add(EvalFailure(id, 'answer was not fully cited'));
            } else {
              answered += 1;
              materializedCitations += result.statements.fold<int>(
                0,
                (total, value) => total + value.citations.length,
              );
            }
          case 'noEvidence':
            if (result.outcome != KnowledgeAnswerOutcome.insufficientEvidence ||
                result.providerCalled ||
                provider.requests.isNotEmpty) {
              failures.add(EvalFailure(id, 'no-evidence gate called Provider'));
            } else {
              refusedWithoutProvider += 1;
            }
          case 'providerRefusal':
            if (result.outcome != KnowledgeAnswerOutcome.insufficientEvidence ||
                !result.providerCalled) {
              failures.add(EvalFailure(id, 'Provider refusal was not kept'));
            } else {
              providerRefusals += 1;
            }
          case 'unknownCitation' || 'uncited':
            failures.add(EvalFailure(id, 'invalid answer was accepted'));
          default:
            failures.add(EvalFailure(id, 'unknown question replay kind'));
        }
      } on KnowledgeQuestionFailure {
        if (kind == 'unknownCitation' || kind == 'uncited') {
          rejectedOutputs += 1;
        } else {
          failures.add(EvalFailure(id, 'valid answer was rejected'));
        }
      } on Object catch (error) {
        failures
            .add(EvalFailure(id, 'knowledge question replay failed: $error'));
      }
    }

    return EvalReport(
      name: 'knowledge-question-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'answered': answered,
        'refusedWithoutProvider': refusedWithoutProvider,
        'providerRefusals': providerRefusals,
        'rejectedOutputs': rejectedOutputs,
        'materializedCitations': materializedCitations,
        'privateContentInDiagnostics': false,
      },
    );
  }

  Future<EvalReport> evaluatePortableConnectorReplay() async {
    final manifest = _readJson('evals/portable_connector_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var idempotentCreates = 0;
    var conflicts = 0;
    var conditionalWrites = 0;
    var rateLimits = 0;
    var offlineRetries = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      try {
        switch (kind) {
          case 'obsidianIdempotent':
            final store = _PortableReplayStore();
            final connector = _portableReplayObsidian(store);
            final request = _portableReplayCreate(id, destinationId: 'vault');
            final first = await connector.create(request);
            final second = await connector.create(request);
            if (first.externalObjectId != second.externalObjectId ||
                store.writes != 1) {
              failures
                  .add(EvalFailure(id, 'Obsidian create was not idempotent'));
            } else {
              idempotentCreates += 1;
            }
          case 'obsidianConflict':
            final store = _PortableReplayStore();
            final connector = _portableReplayObsidian(store);
            final created = await connector.create(
              _portableReplayCreate(id, destinationId: 'vault'),
            );
            store.conflictNextWrite = true;
            try {
              await connector.update(
                KnowledgeConnectorUpdateRequest(
                  item: _portableReplayItem(id, 'Changed portable body.'),
                  destinationId: 'vault',
                  externalObjectId: created.externalObjectId,
                  idempotencyKey: 'update-$id',
                ),
              );
              failures.add(EvalFailure(id, 'Obsidian conflict was accepted'));
            } on KnowledgeConnectorFailure catch (failure) {
              if (failure.code != KnowledgeConnectorFailureCode.conflict ||
                  !failure.retryable) {
                failures
                    .add(EvalFailure(id, 'wrong Obsidian conflict mapping'));
              } else {
                conflicts += 1;
              }
            }
          case 'webdavConditional':
            final transport = _PortableReplayWebDav();
            final connector = _portableReplayWebDav(transport);
            final created = await connector.create(
              _portableReplayCreate(id, destinationId: 'remote'),
            );
            await connector.update(
              KnowledgeConnectorUpdateRequest(
                item: _portableReplayItem(id, 'Changed portable body.'),
                destinationId: 'remote',
                externalObjectId: created.externalObjectId,
                idempotencyKey: 'update-$id',
              ),
            );
            final puts = transport.requests
                .where((request) => request.method == WebDavMethod.put)
                .toList();
            if (puts.first.headers['If-None-Match'] != '*' ||
                puts.last.headers['If-Match'] == null) {
              failures.add(EvalFailure(id, 'WebDAV write was not conditional'));
            } else {
              conditionalWrites += 1;
            }
          case 'webdavRateLimit':
            final transport = _PortableReplayWebDav()
              ..scripted = WebDavResponse(
                statusCode: 429,
                headers: const <String, String>{'Retry-After': '60'},
              );
            try {
              await _portableReplayWebDav(transport).create(
                _portableReplayCreate(id, destinationId: 'remote'),
              );
              failures.add(EvalFailure(id, 'WebDAV rate limit was accepted'));
            } on KnowledgeConnectorFailure catch (failure) {
              if (failure.code != KnowledgeConnectorFailureCode.rateLimited ||
                  failure.retryAfter != const Duration(minutes: 1)) {
                failures.add(EvalFailure(id, 'wrong WebDAV rate mapping'));
              } else {
                rateLimits += 1;
              }
            }
          case 'webdavOffline':
            final transport = _PortableReplayWebDav()
              ..failure = const WebDavTransportFailure(
                WebDavTransportFailureCode.offline,
              );
            try {
              await _portableReplayWebDav(transport).create(
                _portableReplayCreate(id, destinationId: 'remote'),
              );
              failures.add(EvalFailure(id, 'offline WebDAV was accepted'));
            } on KnowledgeConnectorFailure catch (failure) {
              if (failure.code != KnowledgeConnectorFailureCode.offline ||
                  !failure.retryable) {
                failures.add(EvalFailure(id, 'wrong WebDAV offline mapping'));
              } else {
                offlineRetries += 1;
              }
            }
          default:
            failures.add(EvalFailure(id, 'unknown portable connector kind'));
        }
      } on Object catch (error) {
        failures
            .add(EvalFailure(id, 'portable connector replay failed: $error'));
      }
    }
    return EvalReport(
      name: 'portable-connector-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'idempotentCreates': idempotentCreates,
        'conflicts': conflicts,
        'conditionalWrites': conditionalWrites,
        'rateLimits': rateLimits,
        'offlineRetries': offlineRetries,
        'privateContentInDiagnostics': false,
      },
    );
  }

  Future<EvalReport> evaluateImaPortableReplay() async {
    final manifest = _readJson('evals/ima_portable_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var markdownPackages = 0;
    var zipPackages = 0;
    var explicitDismissals = 0;
    var publicEntries = 0;
    var unsafeEntriesRejected = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      final transfer = _ImaReplayTransfer();
      final external = _ImaReplayExternalUri();
      final interop = ImaPortableInterop(
        transfer: transfer,
        externalUri: external,
      );
      try {
        switch (kind) {
          case 'singleMarkdown':
            final package = await interop.prepare(<KnowledgeItem>[
              _portableReplayItem(id, 'Portable private body.'),
            ]);
            if (package.mediaType != 'text/markdown' ||
                !package.fileName.endsWith('.md')) {
              failures.add(EvalFailure(id, 'single export was not Markdown'));
            } else {
              markdownPackages += 1;
            }
          case 'multiZip':
            final package = await interop.prepare(<KnowledgeItem>[
              _portableReplayItem('$id-a', 'First portable body.'),
              _portableReplayItem('$id-b', 'Second portable body.'),
            ]);
            if (package.mediaType != 'application/zip' ||
                package.fileName != 'river-knowledge-2.zip') {
              failures.add(EvalFailure(id, 'multi export was not ZIP'));
            } else {
              zipPackages += 1;
            }
          case 'shareDismissed':
            transfer.shareOutcome = ImaPortableOutcome.dismissed;
            final result = await interop.share(<KnowledgeItem>[
              _portableReplayItem(id, 'Dismissed private body.'),
            ]);
            if (result.outcome != ImaPortableOutcome.dismissed) {
              failures.add(EvalFailure(id, 'dismissal was not preserved'));
            } else if (result.diagnostic.toJson().toString().contains(
                  'Dismissed private body',
                )) {
              failures.add(EvalFailure(id, 'diagnostic leaked body'));
            } else {
              explicitDismissals += 1;
            }
          case 'publicEntry':
            final result = await interop.openPublicEntry();
            if (result.outcome != ImaPortableOutcome.completed ||
                external.opened != Uri.parse('https://ima.qq.com/')) {
              failures.add(EvalFailure(id, 'public entry was not opened'));
            } else {
              publicEntries += 1;
            }
          case 'privateApiRejected':
            if (interop.usesNativePrivateApi) {
              failures.add(EvalFailure(id, 'private API was enabled'));
              continue;
            }
            try {
              ImaPortableInterop(
                transfer: transfer,
                externalUri: external,
                publicEntryUri: Uri.parse('ima://private/import'),
              );
              failures.add(EvalFailure(id, 'private URI was accepted'));
            } on ArgumentError {
              unsafeEntriesRejected += 1;
            }
          default:
            failures.add(EvalFailure(id, 'unknown IMA replay kind'));
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'IMA portable replay failed: $error'));
      }
    }

    return EvalReport(
      name: 'ima-portable-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'markdownPackages': markdownPackages,
        'zipPackages': zipPackages,
        'explicitDismissals': explicitDismissals,
        'publicEntries': publicEntries,
        'unsafeEntriesRejected': unsafeEntriesRejected,
        'nativePrivateApi': false,
        'privateContentInDiagnostics': false,
      },
    );
  }

  Future<EvalReport> evaluatePodcastAudioIntelligenceReplay() async {
    final manifest = _readJson('evals/podcast_audio_intelligence_cases.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    var groundedAnswers = 0;
    var zeroProviderRefusals = 0;
    var forgedCitationsRejected = 0;
    var dialogueBriefs = 0;
    var safetyBlocks = 0;
    var lateCancellationCosts = 0;

    for (final item in cases) {
      final id = item['id'] as String;
      final kind = item['kind'] as String;
      try {
        switch (kind) {
          case 'groundedQuestion':
            final provider = _PodcastAudioReplayQuestionProvider();
            final result = await PodcastTranscriptQuestionService(
              provider: provider,
              usageLedger: MemoryPodcastAudioIntelligenceUsageLedger(),
            ).ask(
              operationId: id,
              question: 'privacy policy changed',
              language: 'en-US',
              transcript: _podcastAudioReplayTranscript(),
              cancellation: PodcastTaskCancellation(),
            );
            if (result.outcome != PodcastQuestionOutcome.answered ||
                result.statements.single.citations.single.segmentIndex != 1) {
              failures.add(EvalFailure(id, 'answer was not timestamp cited'));
            } else {
              groundedAnswers += 1;
            }
          case 'noEvidence':
            final provider = _PodcastAudioReplayQuestionProvider();
            final result = await PodcastTranscriptQuestionService(
              provider: provider,
              usageLedger: MemoryPodcastAudioIntelligenceUsageLedger(),
            ).ask(
              operationId: id,
              question: 'quantum entanglement',
              language: 'en-US',
              transcript: _podcastAudioReplayTranscript(),
              cancellation: PodcastTaskCancellation(),
            );
            if (result.providerCalled || provider.calls != 0) {
              failures.add(EvalFailure(id, 'no-evidence gate called Provider'));
            } else {
              zeroProviderRefusals += 1;
            }
          case 'forgedCitation':
            final provider = _PodcastAudioReplayQuestionProvider(forged: true);
            try {
              await PodcastTranscriptQuestionService(
                provider: provider,
                usageLedger: MemoryPodcastAudioIntelligenceUsageLedger(),
              ).ask(
                operationId: id,
                question: 'privacy policy changed',
                language: 'en-US',
                transcript: _podcastAudioReplayTranscript(),
                cancellation: PodcastTaskCancellation(),
              );
              failures.add(EvalFailure(id, 'forged citation was accepted'));
            } on PodcastAudioIntelligenceFailure catch (failure) {
              if (failure.code !=
                  PodcastAudioIntelligenceFailureCode.invalidProviderOutput) {
                failures.add(EvalFailure(id, 'wrong forged citation failure'));
              } else {
                forgedCitationsRejected += 1;
              }
            }
          case 'dialogueBrief':
            final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
            final artifact = await _podcastAudioReplayBrief(
              ledger: ledger,
            ).generate(
              _podcastAudioReplayBriefRequest(id),
              PodcastTaskCancellation(),
            );
            if (artifact.style != AudioBriefStyle.dialogue ||
                artifact.turns.any((turn) => turn.citations.isEmpty) ||
                ledger.records.length != 2) {
              failures.add(EvalFailure(id, 'dialogue brief was not grounded'));
            } else {
              dialogueBriefs += 1;
            }
          case 'safetyBlocked':
            final script = _PodcastAudioReplayScript();
            try {
              await _podcastAudioReplayBrief(
                safety: _PodcastAudioReplaySafety(blocked: true),
                script: script,
              ).generate(
                _podcastAudioReplayBriefRequest(id),
                PodcastTaskCancellation(),
              );
              failures.add(EvalFailure(id, 'unsafe source was accepted'));
            } on PodcastAudioIntelligenceFailure catch (failure) {
              if (failure.code !=
                      PodcastAudioIntelligenceFailureCode.contentBlocked ||
                  script.calls != 0) {
                failures.add(EvalFailure(id, 'safety gate ran too late'));
              } else {
                safetyBlocks += 1;
              }
            }
          case 'cancelledLate':
            final ledger = MemoryPodcastAudioIntelligenceUsageLedger();
            final renderer = _PodcastAudioReplayPendingRenderer();
            final cancellation = PodcastTaskCancellation();
            final future = _podcastAudioReplayBrief(
              ledger: ledger,
              renderer: renderer,
            ).generate(
              _podcastAudioReplayBriefRequest(id),
              cancellation,
            );
            await renderer.started.future;
            cancellation.cancel();
            try {
              await future;
              failures.add(EvalFailure(id, 'cancelled audio was returned'));
            } on PodcastTaskCancelledException {
              renderer.complete();
              await Future<void>.delayed(Duration.zero);
              if (ledger.records.length != 2) {
                failures.add(EvalFailure(id, 'late cost was not recorded'));
              } else {
                lateCancellationCosts += 1;
              }
            }
          default:
            failures.add(EvalFailure(id, 'unknown audio intelligence kind'));
        }
      } on Object catch (error) {
        failures
            .add(EvalFailure(id, 'audio intelligence replay failed: $error'));
      }
    }

    return EvalReport(
      name: 'podcast-audio-intelligence-replay',
      total: cases.length,
      failures: failures,
      metrics: <String, Object>{
        'groundedAnswers': groundedAnswers,
        'zeroProviderRefusals': zeroProviderRefusals,
        'forgedCitationsRejected': forgedCitationsRejected,
        'dialogueBriefs': dialogueBriefs,
        'safetyBlocks': safetyBlocks,
        'lateCancellationCosts': lateCancellationCosts,
        'privateContentInDiagnostics': false,
      },
    );
  }

  EvalReport evaluateRanking() {
    final manifest = _readJson('evals/ranking_sessions.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    final now = DateTime.utc(2026, 7, 30, 12);

    for (final item in cases) {
      final id = item['id'] as String;
      try {
        switch (item['kind']) {
          case 'weight-order':
            final stronger = _event(item['stronger'] as String);
            final weaker = _event(item['weaker'] as String);
            final strongerWeight = readingSignalWeight(
              _rankingEvent('$id-stronger', id, stronger, now),
            );
            final weakerWeight = readingSignalWeight(
              _rankingEvent('$id-weaker', id, weaker, now),
            );
            final absolute = item['absolute'] == true;
            final strongerValue =
                absolute ? strongerWeight.abs() : strongerWeight;
            final weakerValue = absolute ? weakerWeight.abs() : weakerWeight;
            if (strongerValue <= weakerValue) {
              failures.add(
                EvalFailure(id, '$stronger must dominate $weaker'),
              );
            }
          case 'half-life':
            final actual = decayWeight(
              weight: (item['weight'] as num).toDouble(),
              occurredAt: now.subtract(
                Duration(days: item['ageDays'] as int),
              ),
              now: now,
            );
            final expected = (item['expected'] as num).toDouble();
            if ((actual - expected).abs() > 1e-12) {
              failures.add(
                EvalFailure(id, 'expected $expected, got $actual'),
              );
            }
          case 'click-cap':
            final clickCount = item['clickCount'] as int;
            final profile = const LocalPreferenceProfileModel().build(
              now: now,
              evidence: <PreferenceEvidence>[
                for (var index = 0; index < clickCount; index += 1)
                  PreferenceEvidence(
                    event: ReadingEvent(
                      eventId: '$id-$index',
                      articleId: id,
                      type: ReadingEventType.open,
                      occurredAt: now,
                    ),
                    sourceId: 'source-clicked',
                  ),
              ],
            );
            final actual = profile.sourceScore('source-clicked');
            final expected = (item['expected'] as num).toDouble();
            if ((actual - expected).abs() > 1e-12) {
              failures.add(
                EvalFailure(id, 'click cap expected $expected, got $actual'),
              );
            }
          case 'profile':
            final evidence = _list(item['evidence'])
                .map((entry) => _rankingEvidence(entry, now))
                .toList(growable: false);
            final profile = const LocalPreferenceProfileModel().build(
              now: now,
              evidence: evidence,
            );
            final expectedVersion = item['expectedModelVersion'] as int;
            if (profile.modelVersion != expectedVersion) {
              failures.add(
                EvalFailure(
                  id,
                  'model version expected $expectedVersion, '
                  'got ${profile.modelVersion}',
                ),
              );
            }
            _compareRankingScores(
              id: id,
              dimension: 'source',
              expected: item['expectedSources'],
              actual: profile.sourceScore,
              failures: failures,
            );
            _compareRankingScores(
              id: id,
              dimension: 'topic',
              expected: item['expectedTopics'],
              actual: profile.topicScore,
              failures: failures,
            );
          case 'article-ranking':
            final evidence = _list(item['profileEvidence'])
                .map((entry) => _rankingEvidence(entry, now))
                .toList(growable: false);
            final profile = const LocalPreferenceProfileModel().build(
              now: now,
              evidence: evidence,
            );
            final candidates = _list(item['candidates'])
                .map((entry) => _articleRankingCandidate(entry, now))
                .toList(growable: false);
            final ranked = const LocalArticleRanker().rank(
              candidates: candidates,
              profile: profile,
              now: now,
            );
            final expectedOrder = _strings(item['expectedOrder']);
            final actualOrder = ranked
                .map((result) => result.candidate.articleId)
                .toList(growable: false);
            if (!_sameStrings(actualOrder, expectedOrder)) {
              failures.add(
                EvalFailure(
                  id,
                  'expected order $expectedOrder, got $actualOrder',
                ),
              );
            }
            final expectedVersion = item['expectedModelVersion'] as int;
            final expectedScores =
                item['expectedScores'] as Map<String, Object?>;
            for (final result in ranked) {
              final articleId = result.candidate.articleId;
              if (result.explanation.modelVersion != expectedVersion) {
                failures.add(
                  EvalFailure(
                    id,
                    '$articleId model version expected $expectedVersion, '
                    'got ${result.explanation.modelVersion}',
                  ),
                );
              }
              final expectedScore =
                  (expectedScores[articleId] as num).toDouble();
              if ((result.score - expectedScore).abs() > 1e-12) {
                failures.add(
                  EvalFailure(
                    id,
                    '$articleId expected $expectedScore, got ${result.score}',
                  ),
                );
              }
              final explained = result.explanation.factors.fold<double>(
                0,
                (sum, factor) => sum + factor.contribution,
              );
              if ((explained - result.score).abs() > 1e-12) {
                failures.add(
                  EvalFailure(id, '$articleId explanation does not sum'),
                );
              }
            }
            final expectedFactors =
                item['expectedFactors'] as Map<String, Object?>;
            for (final articleEntry in expectedFactors.entries) {
              final result = ranked.singleWhere(
                (candidate) =>
                    candidate.candidate.articleId == articleEntry.key,
              );
              final factors = _map(articleEntry.value);
              for (final factorEntry in factors.entries) {
                final factor = RankingFactor.values.byName(factorEntry.key);
                final actual = result.explanation.factor(factor).value;
                final expected = (factorEntry.value as num).toDouble();
                if ((actual - expected).abs() > 1e-12) {
                  failures.add(
                    EvalFailure(
                      id,
                      '${articleEntry.key} ${factorEntry.key} '
                      'expected $expected, got $actual',
                    ),
                  );
                }
              }
            }
          case 'guardrail-ranking':
            final evidence = _list(item['profileEvidence'])
                .map((entry) => _rankingEvidence(entry, now))
                .toList(growable: false);
            final profile = const LocalPreferenceProfileModel().build(
              now: now,
              evidence: evidence,
            );
            final candidates = _list(item['candidates'])
                .map((entry) => _articleRankingCandidate(entry, now))
                .toList(growable: false);
            final ranked = const LocalArticleRanker().rank(
              candidates: candidates,
              profile: profile,
              now: now,
            );
            final guardrails = const LocalRankingGuardrails();
            final result = guardrails.apply(
              rankedCandidates: ranked,
              profile: profile,
              limit: item['limit'] as int,
              blockedTopics: _strings(item['blockedTopics']),
            );
            final replayed = guardrails.apply(
              rankedCandidates: ranked.reversed,
              profile: profile,
              limit: item['limit'] as int,
              blockedTopics: _strings(item['blockedTopics']),
            );
            final actualOrder = result.items
                .map((entry) => entry.ranked.candidate.articleId)
                .toList(growable: false);
            final replayedOrder = replayed.items
                .map((entry) => entry.ranked.candidate.articleId)
                .toList(growable: false);
            final expectedOrder = _strings(item['expectedOrder']);
            if (!_sameStrings(actualOrder, expectedOrder) ||
                !_sameStrings(replayedOrder, expectedOrder)) {
              failures.add(
                EvalFailure(
                  id,
                  'expected guarded order $expectedOrder, '
                  'got $actualOrder and replay $replayedOrder',
                ),
              );
            }
            final actualExplorationIds = result.items
                .where(
                  (entry) =>
                      entry.selectionKind ==
                      RankingSelectionKind.explorationQuota,
                )
                .map((entry) => entry.ranked.candidate.articleId)
                .toList(growable: false);
            final expectedExplorationIds =
                _strings(item['expectedExplorationIds']);
            if (!_sameStrings(
              actualExplorationIds,
              expectedExplorationIds,
            )) {
              failures.add(
                EvalFailure(
                  id,
                  'expected exploration $expectedExplorationIds, '
                  'got $actualExplorationIds',
                ),
              );
            }
            final expectedShare =
                (item['expectedMaximumSourceShare'] as num).toDouble();
            if (result.modelVersion != item['expectedGuardrailVersion'] ||
                (result.observedMaximumSourceShare - expectedShare).abs() >
                    1e-12 ||
                !result.sourceCapSatisfied ||
                !result.sourceShareSatisfied ||
                !result.explorationQuotaSatisfied) {
              failures.add(
                EvalFailure(
                  id,
                  'guardrail shares or quotas did not hold',
                ),
              );
            }
            if (result.filteredByBlockedTopic != item['expectedBlockedCount'] ||
                result.filteredByNegativeFeedback !=
                    item['expectedNegativeCount']) {
              failures.add(
                EvalFailure(
                  id,
                  'guardrail filter counts did not match',
                ),
              );
            }
          default:
            failures.add(EvalFailure(id, 'unknown ranking replay kind'));
        }
      } on Object catch (error) {
        failures.add(EvalFailure(id, 'ranking replay failed: $error'));
      }
    }
    return EvalReport(name: 'ranking', total: cases.length, failures: failures);
  }

  Future<EvalReport> evaluateRankingExperiment() async {
    final manifest = _readJson('evals/ranking_experiment.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    for (final item in cases) {
      final id = item['id'] as String;
      final repository =
          _RankingExperimentReplayRepository(<RankingExperimentDailyMetrics>[
        _experimentMetrics(
          RankingExperimentArm.chronological,
          _map(item['control']),
        ),
        _experimentMetrics(
          RankingExperimentArm.personalized,
          _map(item['treatment']),
        ),
      ]);
      final report = await LocalRankingExperiment(repository: repository)
          .buildReport(startDay: '2026-08-01', endDay: '2026-08-06');
      final expected = item['expectedDecision'] as String;
      if (report.decision.name != expected) {
        failures.add(
          EvalFailure(
            id,
            'expected decision $expected, got ${report.decision.name}',
          ),
        );
      }
      if (report.decision == RankingExperimentDecision.insufficientData) {
        try {
          report.exportAggregateJson();
          failures.add(EvalFailure(id, 'insufficient sample was exportable'));
        } on StateError {
          // Expected fail-closed export behavior.
        }
      } else {
        final keys = _jsonKeys(jsonDecode(report.exportAggregateJson()));
        final forbidden = <String>{
          'articleId',
          'sourceId',
          'title',
          'url',
          'body',
          'summaryText',
        };
        if (keys.any(forbidden.contains)) {
          failures.add(EvalFailure(id, 'aggregate export leaked identity'));
        }
      }
    }
    return EvalReport(
      name: 'ranking-experiment-replay',
      total: cases.length,
      failures: failures,
      metrics: const <String, Object>{
        'minimumOpensPerArm': 100,
        'minimumExposuresPerArm': 20,
        'automaticUpload': false,
      },
    );
  }

  EvalReport evaluateFeeds() {
    final manifest = _readJson('evals/feed_manifest.json');
    final cases = _list(manifest['cases']);
    final failures = <EvalFailure>[];
    for (final item in cases) {
      final id = item['id'] as String;
      final content = File(_path(item['fixture'] as String)).readAsStringSync();
      try {
        final feed = const FeedParser().parse(content);
        final expectedKind = item['kind'] as String;
        final expectedTitle = item['title'] as String;
        final expectedCount = item['itemCount'] as int;
        if (feed.kind.name != expectedKind) {
          failures.add(
            EvalFailure(id, 'expected $expectedKind, got ${feed.kind.name}'),
          );
        }
        if (feed.title != expectedTitle) {
          failures.add(
            EvalFailure(id, 'expected title $expectedTitle, got ${feed.title}'),
          );
        }
        if (feed.items.length != expectedCount) {
          failures.add(
            EvalFailure(
              id,
              'expected $expectedCount items, got ${feed.items.length}',
            ),
          );
        }
      } on FeedParseException catch (error) {
        failures.add(EvalFailure(id, error.toString()));
      }
    }
    return EvalReport(name: 'feeds', total: cases.length, failures: failures);
  }

  Map<String, Object?> _readJson(String relativePath) {
    return _map(jsonDecode(File(_path(relativePath)).readAsStringSync()));
  }

  String _path(String relativePath) {
    return '${workspaceRoot.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
  }
}

Map<String, Object?> _map(Object? value) =>
    (value as Map).cast<String, Object?>();

List<Map<String, Object?>> _list(Object? value) =>
    (value as List).map((item) => _map(item)).toList();

List<String> _strings(Object? value) => (value as List).cast<String>();

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _normalizedEvalText(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

bool _containsAny(String normalizedHaystack, Iterable<String> needles) =>
    needles.any(
      (needle) => normalizedHaystack.contains(_normalizedEvalText(needle)),
    );

String _percentage(double value) => '${(value * 100).toStringAsFixed(1)}%';

ReadingEventType _event(String name) => ReadingEventType.values.byName(name);

ReadingEvent _rankingEvent(
  String eventId,
  String articleId,
  ReadingEventType type,
  DateTime occurredAt,
) =>
    ReadingEvent(
      eventId: eventId,
      articleId: articleId,
      type: type,
      occurredAt: occurredAt,
      activeSeconds: type == ReadingEventType.activeRead ? 120 : 0,
      completionRatio: type == ReadingEventType.completed ? 1 : 0,
    );

PreferenceEvidence _rankingEvidence(
  Map<String, Object?> entry,
  DateTime occurredAt,
) {
  final type = _event(entry['type'] as String);
  return PreferenceEvidence(
    event: ReadingEvent(
      eventId: entry['eventId'] as String,
      articleId: entry['articleId'] as String,
      type: type,
      occurredAt: occurredAt,
      activeSeconds: (entry['activeSeconds'] as int?) ?? 0,
      completionRatio: (entry['completionRatio'] as num?)?.toDouble() ?? 0,
    ),
    sourceId: entry['sourceId'] as String,
    topics: _strings(entry['topics']),
  );
}

ArticleRankingCandidate _articleRankingCandidate(
  Map<String, Object?> entry,
  DateTime now,
) =>
    ArticleRankingCandidate(
      articleId: entry['articleId'] as String,
      sourceId: entry['sourceId'] as String,
      publishedAt: now.subtract(
        Duration(hours: entry['ageHours'] as int),
      ),
      semanticSimilarity: (entry['semantic'] as num).toDouble(),
      completionProbability: (entry['completion'] as num).toDouble(),
      explorationProbability: (entry['exploration'] as num).toDouble(),
      topics: _strings(entry['topics']),
    );

void _compareRankingScores({
  required String id,
  required String dimension,
  required Object? expected,
  required double Function(String key) actual,
  required List<EvalFailure> failures,
}) {
  final expectedScores = expected as Map<String, Object?>;
  for (final entry in expectedScores.entries) {
    final expectedScore = (entry.value as num).toDouble();
    final actualScore = actual(entry.key);
    if ((actualScore - expectedScore).abs() > 1e-12) {
      failures.add(
        EvalFailure(
          id,
          '$dimension ${entry.key} expected $expectedScore, got $actualScore',
        ),
      );
    }
  }
}

final class _ReplayAiHttpTransport implements AiHttpTransport {
  _ReplayAiHttpTransport(this.response);

  final AiHttpResponse response;
  AiHttpRequest? request;

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    this.request = request;
    return response;
  }
}

final class _CloudExtractionReplayDns implements CloudExtractionDnsResolver {
  _CloudExtractionReplayDns(this.kind);

  final String kind;
  var calls = 0;

  @override
  Future<List<String>> resolve(String host) async {
    calls += 1;
    if (kind == 'dnsRebind' && calls > 1) return <String>['127.0.0.1'];
    return <String>['93.184.216.34'];
  }
}

final class _CloudExtractionReplayTransport
    implements CloudExtractionPinnedTransport {
  _CloudExtractionReplayTransport(this.kind);

  final String kind;
  final List<CloudExtractionFetchRequest> requests =
      <CloudExtractionFetchRequest>[];

  @override
  Future<CloudExtractionFetchResponse> get(
    CloudExtractionFetchRequest request,
  ) async {
    requests.add(request);
    if (kind == 'privateRedirect') {
      return _cloudReplayResponse(
        statusCode: 302,
        headers: const <String, String>{
          'location': 'https://169.254.169.254/latest/meta-data',
        },
      );
    }
    if (kind == 'dnsRebind' && requests.length == 1) {
      return _cloudReplayResponse(
        statusCode: 302,
        headers: const <String, String>{'location': '/rebound'},
      );
    }
    if (kind == 'oversized') {
      return _cloudReplayResponse(
        body: List<int>.filled(2049, 0x78),
        headers: const <String, String>{'content-type': 'text/html'},
      );
    }
    return _cloudReplayResponse(
      body: utf8.encode(_cloudReplayMaliciousHtml),
      headers: const <String, String>{
        'content-type': 'text/html; charset=utf-8',
      },
    );
  }
}

final class _CloudExtractionReplayClock implements CloudExtractionClock {
  const _CloudExtractionReplayClock();

  @override
  Duration elapsed() => Duration.zero;
}

CloudExtractionFetchResponse _cloudReplayResponse({
  int statusCode = 200,
  List<int> body = const <int>[],
  Map<String, String> headers = const <String, String>{},
}) =>
    CloudExtractionFetchResponse(
      statusCode: statusCode,
      connectedAddress: '93.184.216.34',
      bodyBytes: body,
      headers: headers,
    );

final _cloudReplayMaliciousHtml = '''
<html><head><title>Cloud replay</title></head><body><article>
<h1>Cloud replay</h1>
<p>${List<String>.filled(20, '合成安全正文用于确定性安全验证。').join()}</p>
<script>fetch('https://attacker.invalid')</script>
<iframe src="https://attacker.invalid"></iframe>
<a href="javascript:alert(1)">blocked</a>
<img src="https://images.example.test/safe.png" onerror="alert(1)">
</article></body></html>
''';

final class _CloudTtsReplayClock implements CloudTtsClock {
  const _CloudTtsReplayClock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}

final class _CloudTtsReplaySynthesizer implements CloudTtsSynthesizer {
  _CloudTtsReplaySynthesizer({required this.pending});

  final bool pending;
  final List<CloudTtsSynthesisRequest> requests = <CloudTtsSynthesisRequest>[];
  final List<AudioPrefetchCancellation> cancellations =
      <AudioPrefetchCancellation>[];
  final Completer<CloudTtsSynthesisResponse> _completion =
      Completer<CloudTtsSynthesisResponse>();

  @override
  Future<CloudTtsSynthesisResponse> synthesize(
    CloudTtsSynthesisRequest request,
    AudioPrefetchCancellation cancellation,
  ) async {
    requests.add(request);
    cancellations.add(cancellation);
    if (pending) return _completion.future;
    return _cloudTtsReplayResponse();
  }

  void complete() => _completion.complete(_cloudTtsReplayResponse());
}

AudioSegmentPreparationRequest _cloudTtsReplayRequest({
  String revision = 'PRIVATE-REVISION',
}) =>
    AudioSegmentPreparationRequest(
      item: AudioItem(
        id: 'private-replay-article',
        kind: AudioKind.articleTts,
        title: 'Private replay title',
        sourceUri: Uri.parse('https://reader.example/private?secret=1'),
      ),
      contentRevision: revision,
      segment: const SpeechSegment(
        index: 0,
        text: 'PRIVATE-REPLAY-TEXT',
        sourceStart: 0,
        sourceEnd: 19,
      ),
      settings: const AudioPlaybackSettings(
        voiceId: 'reader-voice',
        languageTag: 'en-US',
      ),
    );

CloudTtsSynthesisResponse _cloudTtsReplayResponse() =>
    CloudTtsSynthesisResponse(
      audioBytes: const <int>[0x49, 0x44, 0x33, 1, 2, 3],
      mediaType: 'audio/mpeg',
      audioDuration: const Duration(seconds: 3),
      billableDuration: const Duration(milliseconds: 3500),
      costMicros: 17,
    );

Future<void> _cloudTtsReplayFlush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _PodcastReplayClock implements PodcastTranscriptionClock {
  const _PodcastReplayClock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}

final class _PodcastReplayIngestor implements PodcastMediaIngestor {
  _PodcastReplayIngestor({
    required this.invalidFormat,
    required this.pending,
  });

  final bool invalidFormat;
  final bool pending;
  final Completer<void> _gate = Completer<void>();
  final List<String> deleted = <String>[];
  var calls = 0;

  @override
  Future<void> deleteAsset(String assetId) async => deleted.add(assetId);

  @override
  Future<PodcastMediaAsset> ingest(
    PodcastMediaSource source,
    PodcastTaskCancellation cancellation,
  ) async {
    calls += 1;
    if (pending) await _gate.future;
    cancellation.throwIfCancelled();
    return PodcastMediaAsset(
      assetId: 'podcast-replay-asset',
      contentDigest: List<String>.filled(64, 'b').join(),
      mediaType: invalidFormat ? 'application/octet-stream' : 'audio/mpeg',
      bytes: 1024,
      duration: const Duration(hours: 6),
    );
  }

  void complete() => _gate.complete();
}

final class _PodcastReplayTranscriber implements PodcastTranscriptionProvider {
  var calls = 0;

  @override
  Future<PodcastTranscriptionProviderResult> transcribe(
    PodcastMediaAsset asset, {
    required String? outputLanguage,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    calls += 1;
    cancellation.throwIfCancelled();
    return PodcastTranscriptionProviderResult(
      transcript: PodcastTranscript(
        language: 'en-US',
        providerVersion: 'replay-v1',
        segments: const <PodcastTranscriptSegment>[
          PodcastTranscriptSegment(
            index: 0,
            start: Duration.zero,
            end: Duration(hours: 3),
            text: 'PRIVATE-PODCAST-TRANSCRIPT first half.',
          ),
          PodcastTranscriptSegment(
            index: 1,
            start: Duration(hours: 3),
            end: Duration(hours: 6),
            text: 'PRIVATE-PODCAST-TRANSCRIPT second half.',
          ),
        ],
      ),
      billableDuration: const Duration(hours: 6),
      costMicros: 1200,
    );
  }
}

final class _PodcastReplayAnalyzer implements PodcastIntelligenceProvider {
  var calls = 0;
  var fail = false;

  @override
  Future<PodcastIntelligenceProviderResult> analyze(
    PodcastTranscript transcript, {
    required bool generateChapters,
    required bool generateSummary,
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    calls += 1;
    cancellation.throwIfCancelled();
    if (fail) throw StateError('synthetic replay interruption');
    return PodcastIntelligenceProviderResult(
      chapters: const <PodcastGeneratedChapter>[
        PodcastGeneratedChapter(
          start: Duration.zero,
          title: 'Opening',
          summary: 'Synthetic opening section.',
        ),
        PodcastGeneratedChapter(
          start: Duration(hours: 3),
          title: 'Closing',
          summary: 'Synthetic closing section.',
        ),
      ],
      summary: PodcastGeneratedSummary(
        oneLine: 'A deterministic synthetic podcast summary.',
        keyPoints: const <String>['One', 'Two', 'Three'],
        topics: const <String>['testing'],
        language: 'en-US',
      ),
      costMicros: 200,
    );
  }
}

PodcastTranscriptionRequest _podcastReplayRequest() =>
    PodcastTranscriptionRequest(
      jobId: 'podcast-replay-job',
      source: PodcastUploadedMediaSource(
        uploadId: 'upload-private-replay',
        mediaType: 'audio/mpeg',
        bytes: 1024,
        duration: const Duration(hours: 6),
      ),
      outputLanguage: 'en-US',
    );

Future<void> _podcastReplayFlush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

List<CloudCostLimit> _cloudGovernanceLimits() => <CloudCostLimit>[
      for (final capability in CloudCapability.values)
        CloudCostLimit(
          capability: capability,
          window: const Duration(hours: 1),
          maximumWindowCostMicros: 100,
          maximumOperationCostMicros: 80,
        ),
    ];

CloudOperationSpan _cloudGovernanceSpan(
  String id,
  int cost, {
  Duration offset = Duration.zero,
}) {
  final start = DateTime.utc(2026, 8, 6, 12).add(offset);
  return CloudOperationSpan(
    spanId: id,
    operationHash: List<String>.filled(64, 'c').join(),
    capability: CloudCapability.managedAi,
    routeId: 'replay-route',
    modelId: 'replay-model',
    startedAt: start,
    endedAt: start.add(const Duration(milliseconds: 250)),
    outcome: CloudSpanOutcome.success,
    costMicros: cost,
    inputUnits: 10,
    outputUnits: 20,
  );
}

CloudKillSwitchSnapshot _cloudGovernanceSnapshot({
  required int version,
  required Set<CloudCapability> disabled,
  String signature = 'valid-signature',
}) =>
    CloudKillSwitchSnapshot(
      version: version,
      issuedAt: DateTime.utc(2026, 8, 6, 11),
      expiresAt: DateTime.utc(2026, 8, 6, 13),
      disabled: disabled,
      reasonCode: 'cost_guard',
      signature: signature,
    );

CloudKillSwitchController _cloudGovernanceController(
  MemoryCloudKillSwitchStore store,
  CloudKillSwitchSnapshot snapshot,
) =>
    CloudKillSwitchController(
      source: _CloudGovernanceReplaySource(snapshot),
      verifier: const _CloudGovernanceReplayVerifier(),
      store: store,
      clock: const _CloudGovernanceReplayClock(),
    );

final class _CloudGovernanceReplaySource implements CloudKillSwitchSource {
  const _CloudGovernanceReplaySource(this.snapshot);

  final CloudKillSwitchSnapshot snapshot;

  @override
  Future<CloudKillSwitchSnapshot> fetch() async => snapshot;
}

final class _CloudGovernanceReplayVerifier implements CloudKillSwitchVerifier {
  const _CloudGovernanceReplayVerifier();

  @override
  Future<bool> verify(String canonicalPayload, String signature) async =>
      signature == 'valid-signature';
}

final class _CloudGovernanceReplayClock implements CloudGovernanceClock {
  const _CloudGovernanceReplayClock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}

final class _ZeroAiClock implements AiMonotonicClock {
  const _ZeroAiClock();

  @override
  Duration elapsed() => Duration.zero;
}

final class _LongSummaryReplayProvider implements AiProvider {
  _LongSummaryReplayProvider({
    required this.articleId,
    required this.chunks,
    required this.mapFacts,
    required this.finalOutput,
    required this.language,
  });

  final String articleId;
  final List<ArticleSummaryChunk> chunks;
  final List<List<String>> mapFacts;
  final String finalOutput;
  final String language;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  String get id => 'long-summary-replay';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    final output = request.operationId.endsWith(':reduce')
        ? finalOutput
        : _mapOutput(request);
    return AiProviderResponse(
      output: output,
      model: request.model,
      usage: AiTokenUsage(inputTokens: 10, outputTokens: 5),
      elapsed: Duration.zero,
    );
  }

  String _mapOutput(AiProviderRequest request) {
    final index = int.parse(request.operationId.split(':').last);
    final chunk = chunks[index];
    return jsonEncode(
      <String, Object?>{
        'schemaVersion': AiChunkSummarySchema.name,
        'articleId': articleId,
        'chunkIndex': index,
        'paragraphStart': chunk.paragraphStart,
        'paragraphEnd': chunk.paragraphEnd,
        'facts': <Map<String, Object?>>[
          for (final fact in mapFacts[index])
            <String, Object?>{
              'text': fact,
              'articleId': articleId,
              'paragraphStart': chunk.paragraphStart,
              'paragraphEnd': chunk.paragraphStart + 1,
            },
        ],
        'topics': <String>['RSS', 'AI'],
        'entities': <String>['River'],
        'language': language,
      },
    );
  }
}

final class _CacheReplayProvider implements AiProvider {
  _CacheReplayProvider(this.output);

  final String output;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  String get id => 'cache-replay';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    return AiProviderResponse(
      output: output,
      model: request.model,
      usage: AiTokenUsage(inputTokens: 10, outputTokens: 5),
      elapsed: Duration.zero,
    );
  }
}

final class _ManagedGatewayReplayProvider implements AiProvider {
  _ManagedGatewayReplayProvider({
    required this.id,
    this.fail = false,
    this.invalidOutput = false,
  });

  @override
  final String id;
  final bool fail;
  final bool invalidOutput;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    requests.add(request);
    if (fail) {
      throw AiProviderFailure(
        code: AiProviderFailureCode.unavailable,
        retryable: true,
      );
    }
    return AiProviderResponse(
      output: invalidOutput ? '{"invalid":true}' : _managedSummaryOutput(),
      model: request.model,
      usage: AiTokenUsage(inputTokens: 100, outputTokens: 25),
      elapsed: const Duration(milliseconds: 10),
    );
  }
}

final class _ManagedGatewayReplayClock implements ManagedAiGatewayClock {
  const _ManagedGatewayReplayClock();

  @override
  Duration elapsed() => Duration.zero;

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}

final class _ManagedGatewayReplayTimeoutGuard implements ManagedAiTimeoutGuard {
  _ManagedGatewayReplayTimeoutGuard({required this.timeOutFirst});

  final bool timeOutFirst;
  var _calls = 0;

  @override
  Future<T> within<T>(Future<T> future, Duration timeout) async {
    _calls += 1;
    if (timeOutFirst && _calls == 1) {
      throw TimeoutException('synthetic managed AI timeout');
    }
    return future;
  }
}

ManagedAiRouteTarget _managedGatewayTarget(
  String routeId,
  String providerId,
) =>
    ManagedAiRouteTarget(
      routeId: routeId,
      providerId: providerId,
      model: '$providerId-model',
      inputMicrosPerMillionTokens: 1000000,
      outputMicrosPerMillionTokens: 2000000,
      timeout: const Duration(seconds: 5),
    );

String _managedSummaryOutput() => jsonEncode(<String, Object?>{
      'schemaVersion': ArticleSummarySchema.name,
      'oneLine': '托管 AI 路由返回了合格摘要。',
      'keyPoints': <String>['路由确定', '故障有界', '结果可校验'],
      'whyItMatters': '服务故障不会破坏客户端的本地阅读能力。',
      'topics': <String>['AI'],
      'entities': <String>['River'],
      'estimatedReadingMinutes': 2,
      'language': 'zh-CN',
    });

final class _ReplayArtifactRepository implements AiArtifactRepository {
  final Map<String, AiArtifact> _values = <String, AiArtifact>{};

  Iterable<AiArtifact> get values => _values.values;

  @override
  Future<void> delete(String cacheKey) async {
    _values.remove(cacheKey);
  }

  @override
  Future<AiArtifact?> read(String cacheKey) async => _values[cacheKey];

  @override
  Future<void> write(AiArtifact artifact) async {
    _values[artifact.cacheKey] = artifact;
  }
}

final class _ReplayClock implements Clock {
  const _ReplayClock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 30, 12);
}

RankingExperimentDailyMetrics _experimentMetrics(
  RankingExperimentArm arm,
  Map<String, Object?> values,
) {
  final exposures = values['exposures'] as int;
  final diversity = (values['diversity'] as num).toDouble();
  return RankingExperimentDailyMetrics(
    experimentId: rankingExperimentId,
    arm: arm,
    dayKey: '2026-08-06',
    exposures: exposures,
    exposedArticles: exposures * 20,
    sourceDiversitySum: exposures * diversity,
    sourceDiversitySquaredSum: exposures * diversity * diversity,
    opens: values['opens'] as int,
    completions: values['completions'] as int,
    quickExits: values['quickExits'] as int,
  );
}

Set<String> _jsonKeys(Object? value) {
  final keys = <String>{};
  void visit(Object? current) {
    if (current is Map<String, Object?>) {
      keys.addAll(current.keys);
      current.values.forEach(visit);
    } else if (current is List<Object?>) {
      current.forEach(visit);
    }
  }

  visit(value);
  return keys;
}

final class _RankingExperimentReplayRepository
    implements RankingExperimentRepository {
  _RankingExperimentReplayRepository(this.rows);

  final List<RankingExperimentDailyMetrics> rows;

  @override
  Future<int> clearMetrics({required String experimentId}) async => 0;

  @override
  Future<void> disable({required DateTime updatedAt}) async {}

  @override
  Future<RankingExperimentEnrollment?> readEnrollment() async => null;

  @override
  Future<List<RankingExperimentDailyMetrics>> readMetrics({
    required String experimentId,
    required String startDay,
    required String endDay,
  }) async =>
      rows;

  @override
  Future<void> recordExposure(RankingExperimentExposure exposure) async {}

  @override
  Future<void> recordReadingOutcome(
    RankingExperimentReadingOutcome outcome,
  ) async {}

  @override
  Future<void> recordSummaryObservation(
    RankingExperimentSummaryObservation observation,
  ) async {}

  @override
  Future<void> saveEnrollment(RankingExperimentEnrollment enrollment) async {}

  @override
  Stream<RankingExperimentEnrollment?> watchEnrollment() =>
      const Stream<RankingExperimentEnrollment?>.empty();
}

const _commerceSubject =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

EntitlementSnapshot _commerceSnapshot({
  required int revision,
  required EntitlementPlan plan,
  required DateTime issuedAt,
  required DateTime refreshAfter,
  required DateTime validUntil,
  required String signature,
}) =>
    EntitlementSnapshot(
      revision: revision,
      subjectHash: _commerceSubject,
      plan: plan,
      granted: const <EntitlementKey>{
        EntitlementKey.managedAi,
        EntitlementKey.cloudExtraction,
        EntitlementKey.cloudTts,
      },
      issuedAt: issuedAt,
      refreshAfter: refreshAfter,
      validUntil: validUntil,
      signature: signature,
    );

final class _CommerceReplaySource implements EntitlementSnapshotSource {
  const _CommerceReplaySource(this.snapshot);

  final EntitlementSnapshot snapshot;

  @override
  Future<EntitlementSnapshot> fetch(String subjectHash) async => snapshot;
}

final class _CommerceReplayVerifier implements EntitlementSnapshotVerifier {
  const _CommerceReplayVerifier();

  @override
  Future<bool> verify(String canonicalPayload, String signature) async =>
      signature == 'valid';
}

final class _CommerceReplayClock implements EntitlementClock {
  const _CommerceReplayClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

final _usageReplayNow = DateTime.utc(2026, 8, 6, 12);
const _usageReplayHash =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

UsageLedger _replayUsageLedger() => UsageLedger(<UsageGrant>[
      UsageGrant(
        grantId: 'grant-replay',
        capability: EntitlementKey.managedAi,
        limit: 10,
        validFrom: DateTime.utc(2026, 8, 1),
        validUntil: DateTime.utc(2026, 9, 1),
      ),
    ]);

Future<UsageLedgerEntry> _replayReserve(
  UsageLedger ledger,
  String operationId,
  int units,
) =>
    ledger.reserve(
      operationId: operationId,
      requestHash: _usageReplayHash,
      grantId: 'grant-replay',
      capability: EntitlementKey.managedAi,
      units: units,
      at: _usageReplayNow,
    );

Future<void> _replayCommit(
  UsageLedger ledger,
  String operationId,
  int units,
) async {
  await _replayReserve(ledger, operationId, units);
  await ledger.settle(
    operationId: operationId,
    producedUsableResult: true,
    at: _usageReplayNow.add(const Duration(seconds: 1)),
  );
}

EntitlementGate _freeReplayGate({required String kind}) {
  final guest = kind == 'guest';
  final expired = kind == 'expired-trial';
  final snapshot = EntitlementSnapshot(
    revision: 1,
    subjectHash: _commerceSubject,
    plan: expired ? EntitlementPlan.trial : EntitlementPlan.free,
    granted: expired
        ? const <EntitlementKey>{EntitlementKey.managedAi}
        : const <EntitlementKey>{},
    issuedAt: expired ? DateTime.utc(2026, 8, 1) : DateTime.utc(2026, 8, 6, 10),
    refreshAfter:
        expired ? DateTime.utc(2026, 8, 2) : DateTime.utc(2026, 8, 6, 18),
    validUntil:
        expired ? DateTime.utc(2026, 8, 3) : DateTime.utc(2026, 8, 7, 10),
    signature: 'valid',
  );
  final store = MemoryEntitlementSnapshotStore();
  if (!guest) store.value = snapshot;
  return EntitlementGate(
    subjectHash: guest ? null : _commerceSubject,
    source: _CommerceReplaySource(snapshot),
    verifier: const _CommerceReplayVerifier(),
    store: store,
    clock: _CommerceReplayClock(DateTime.utc(2026, 8, 6, 12)),
  );
}

Future<void> _requireFree(EntitlementGate gate, EntitlementKey key) async {
  final decision = await gate.decision(key, networkAvailable: false);
  if (!decision.allowed ||
      decision.reason != EntitlementGateReason.freeBaseline) {
    throw StateError('${key.name} is not permanently Free');
  }
}

KnowledgeItem _freeKnowledgeItem(String state, String body) {
  final title = 'River Free $state';
  final markdown = '# $title\n\n$body';
  final sanitizedHtml = '<h1>$title</h1><p>$body</p>';
  return KnowledgeItem(
    id: 'knowledge-$state',
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-$state',
      originalUrl: Uri.parse('https://example.test/free/$state'),
      sourceTitle: 'River Free Replay',
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: sanitizedHtml,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: markdown,
      sanitizedHtml: sanitizedHtml,
    ),
    savedAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );
}

const _knowledgeVectorReplayText =
    'River builds a deterministic local knowledge index. '
    'Every chunk retains its source identity and content hash. '
    'Model upgrades, content changes, deletion, and recovery are replayed.';

EmbeddingProfile _knowledgeVectorReplayProfile({int revision = 1}) =>
    EmbeddingProfile(
      modelId: 'river-replay-mini',
      revision: revision,
      dimensions: 4,
      location: EmbeddingExecutionLocation.local,
    );

KnowledgeItem _knowledgeVectorReplayItem(String id, String body) {
  final title = 'Knowledge vector $id';
  final markdown = '# $title\n\n$body';
  final sanitizedHtml = '<h1>$title</h1><p>$body</p>';
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'article-$id',
      originalUrl: Uri.parse('https://example.test/vector/$id'),
      sourceTitle: 'River Vector Replay',
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: sanitizedHtml,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: markdown,
      sanitizedHtml: sanitizedHtml,
    ),
    savedAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );
}

final class _KnowledgeVectorReplayProvider
    implements KnowledgeEmbeddingProvider {
  var calls = 0;

  @override
  Future<List<EmbeddingVector>> embed({
    required EmbeddingProfile profile,
    required List<KnowledgeChunk> chunks,
  }) async {
    calls += 1;
    return chunks
        .map(
          (chunk) => EmbeddingVector(
            chunkId: chunk.id,
            values: List<double>.generate(
              profile.dimensions,
              (index) => (chunk.ordinal + index + 1) / 10,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<double>> embedQuery({
    required EmbeddingProfile profile,
    required String query,
  }) async =>
      List<double>.filled(profile.dimensions, 0.5);
}

final class _KnowledgeVectorReplayCorruptIndex implements KnowledgeVectorIndex {
  _KnowledgeVectorReplayCorruptIndex(this.document);

  KnowledgeVectorDocument document;
  var replacements = 0;

  @override
  Future<void> clearProfile(String profileIdentity) async {}

  @override
  Future<void> deleteDocument(String itemId) async {}

  @override
  Future<KnowledgeVectorDocument?> readDocument(String itemId) async =>
      KnowledgeVectorDocument(
        itemId: document.itemId,
        contentHash: document.contentHash,
        sourceKind: document.sourceKind,
        sourceId: document.sourceId,
        title: document.title,
        savedAt: document.savedAt,
        updatedAt: document.updatedAt,
        tags: document.tags,
        topics: document.topics,
        profileIdentity: document.profileIdentity,
        chunkerVersion: document.chunkerVersion,
        records: document.records
            .map(
              (record) => KnowledgeVectorRecord(
                chunk: record.chunk,
                profileIdentity: record.profileIdentity,
                vector: const <double>[1],
              ),
            )
            .toList(growable: false),
        indexedAt: document.indexedAt,
      );

  @override
  Future<void> replaceDocument(KnowledgeVectorDocument document) async {
    this.document = document;
    replacements += 1;
  }

  @override
  Future<List<KnowledgeVectorMatch>> searchRecords({
    required String profileIdentity,
    required List<double> vector,
    required KnowledgeVectorQueryFilter filter,
    required int limit,
    required double minimumScore,
  }) async =>
      const <KnowledgeVectorMatch>[];
}

final class _KnowledgeVectorReplayClock implements KnowledgeIndexClock {
  const _KnowledgeVectorReplayClock();

  @override
  DateTime now() => DateTime.utc(2026, 8, 6, 12);
}

EmbeddingProfile _knowledgeSearchReplayProfile() => EmbeddingProfile(
      modelId: 'river-search-golden',
      revision: 1,
      dimensions: 4,
      location: EmbeddingExecutionLocation.local,
    );

KnowledgeItem _knowledgeSearchReplayItem(Map<String, Object?> value) {
  final id = value['id'] as String;
  final body = value['body'] as String;
  final title = 'Golden $id';
  final markdown = '# $title\n\n$body';
  final html = '<h1>$title</h1><p>$body</p>';
  final tags = _strings(value['tags']);
  final topics = _strings(value['topics']);
  final day = value['day'] as int;
  final kind = KnowledgeSourceKind.values.byName(value['kind'] as String);
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: kind,
      sourceId: 'source-$id',
      originalUrl: Uri.parse('https://example.test/search/$id'),
      sourceTitle: 'River Search Golden Set',
    ),
    title: title,
    markdown: markdown,
    sanitizedHtml: html,
    tags: tags,
    topics: topics,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: markdown,
      sanitizedHtml: html,
      tags: tags,
      topics: topics,
    ),
    savedAt: DateTime.utc(2026, 8, day),
    updatedAt: DateTime.utc(2026, 8, day),
  );
}

KnowledgeVectorQueryFilter _knowledgeSearchReplayFilter(Object? value) {
  if (value == null) return KnowledgeVectorQueryFilter();
  final filter = (value as Map).cast<String, Object?>();
  final fromDay = filter['savedFromDay'] as int?;
  final beforeDay = filter['savedBeforeDay'] as int?;
  return KnowledgeVectorQueryFilter(
    sourceKinds: filter['sourceKinds'] == null
        ? const <KnowledgeSourceKind>[]
        : _strings(filter['sourceKinds'])
            .map(KnowledgeSourceKind.values.byName),
    sourceIds: filter['sourceIds'] == null
        ? const <String>[]
        : _strings(filter['sourceIds']),
    tags: filter['tags'] == null ? const <String>[] : _strings(filter['tags']),
    topics: filter['topics'] == null
        ? const <String>[]
        : _strings(filter['topics']),
    savedFrom: fromDay == null ? null : DateTime.utc(2026, 8, fromDay),
    savedBefore: beforeDay == null ? null : DateTime.utc(2026, 8, beforeDay),
  );
}

final class _KnowledgeSearchReplayProvider
    implements KnowledgeEmbeddingProvider {
  var queryCalls = 0;

  @override
  Future<List<EmbeddingVector>> embed({
    required EmbeddingProfile profile,
    required List<KnowledgeChunk> chunks,
  }) async =>
      chunks
          .map(
            (chunk) => EmbeddingVector(
              chunkId: chunk.id,
              values: _knowledgeSearchReplayVector(chunk.text),
            ),
          )
          .toList(growable: false);

  @override
  Future<List<double>> embedQuery({
    required EmbeddingProfile profile,
    required String query,
  }) async {
    queryCalls += 1;
    return _knowledgeSearchReplayVector(query);
  }
}

final class _KnowledgeQuestionReplayProvider
    implements KnowledgeQuestionAnswerProvider {
  _KnowledgeQuestionReplayProvider(this.kind);

  final String kind;
  final List<KnowledgeQuestionProviderRequest> requests =
      <KnowledgeQuestionProviderRequest>[];

  @override
  Future<KnowledgeQuestionProviderResponse> answer(
    KnowledgeQuestionProviderRequest request,
  ) async {
    requests.add(request);
    switch (kind) {
      case 'providerRefusal':
        return KnowledgeQuestionProviderResponse(insufficientEvidence: true);
      case 'unknownCitation':
        return KnowledgeQuestionProviderResponse(
          insufficientEvidence: false,
          statements: <KnowledgeQuestionProviderStatement>[
            KnowledgeQuestionProviderStatement(
              text: 'Synthetic unsupported answer.',
              citationChunkIds: const <String>['unknown-chunk'],
            ),
          ],
        );
      case 'uncited':
        return KnowledgeQuestionProviderResponse(
          insufficientEvidence: false,
          statements: <KnowledgeQuestionProviderStatement>[
            KnowledgeQuestionProviderStatement(
              text: 'Synthetic uncited answer.',
              citationChunkIds: const <String>[],
            ),
          ],
        );
      default:
        return KnowledgeQuestionProviderResponse(
          insufficientEvidence: false,
          statements: <KnowledgeQuestionProviderStatement>[
            KnowledgeQuestionProviderStatement(
              text: 'Solar and wind sources generate renewable electricity.',
              citationChunkIds: <String>[request.evidence.first.chunkId],
            ),
          ],
        );
    }
  }
}

List<double> _knowledgeSearchReplayVector(String text) {
  final value = text.toLowerCase();
  if (value.contains('solar') ||
      value.contains('wind') ||
      value.contains('renewable')) {
    return const <double>[1, 0, 0, 0];
  }
  if (value.contains('pasta') ||
      value.contains('bread') ||
      value.contains('cooking') ||
      value.contains('baking')) {
    return const <double>[0, 1, 0, 0];
  }
  if (value.contains('security') ||
      value.contains('credentials') ||
      value.contains('zero trust')) {
    return const <double>[0, 0, 1, 0];
  }
  if (value.contains('bond') ||
      value.contains('portfolio') ||
      value.contains('markets')) {
    return const <double>[0, 0, 0, 1];
  }
  return const <double>[0, 0, 0, 0];
}

ObsidianKnowledgeConnector _portableReplayObsidian(
  _PortableReplayStore store,
) =>
    ObsidianKnowledgeConnector(
      store: store,
      destinations: const <String, String>{'vault': 'River/Knowledge'},
    );

WebDavKnowledgeConnector _portableReplayWebDav(
  _PortableReplayWebDav transport,
) =>
    WebDavKnowledgeConnector(
      transport: transport,
      destinations: <String, Uri>{
        'remote': Uri.parse('https://dav.example.test/knowledge/'),
      },
    );

KnowledgeConnectorCreateRequest _portableReplayCreate(
  String id, {
  required String destinationId,
}) =>
    KnowledgeConnectorCreateRequest(
      item: _portableReplayItem(id, 'Original portable body.'),
      destinationId: destinationId,
      idempotencyKey: 'create-$id',
    );

KnowledgeItem _portableReplayItem(String id, String body) {
  final title = 'Portable $id';
  final html = '<p>$body</p>';
  return KnowledgeItem(
    id: id,
    source: KnowledgeSourceReference(
      kind: KnowledgeSourceKind.article,
      sourceId: 'source-$id',
      originalUrl: Uri.parse('https://example.test/portable/$id'),
      sourceTitle: 'River Portable Replay',
    ),
    title: title,
    markdown: body,
    sanitizedHtml: html,
    contentHash: const KnowledgeContentHasher().hash(
      title: title,
      markdown: body,
      sanitizedHtml: html,
    ),
    savedAt: DateTime.utc(2026, 8, 6),
    updatedAt: DateTime.utc(2026, 8, 6),
  );
}

final class _PortableReplayStore implements KnowledgeDocumentStore {
  final Map<String, KnowledgeStoredDocument> values =
      <String, KnowledgeStoredDocument>{};
  var writes = 0;
  var revision = 0;
  var conflictNextWrite = false;

  @override
  Future<void> delete(String path, {required String expectedRevision}) async {
    final current = values[path];
    if (current == null) {
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.notFound,
      );
    }
    if (current.revision != expectedRevision) {
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.conflict,
      );
    }
    values.remove(path);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<KnowledgeStoredDocument?> read(String path) async => values[path];

  @override
  Future<KnowledgeStoredDocument> write(
    String path,
    List<int> bytes, {
    required String? expectedRevision,
    required bool createOnly,
  }) async {
    final current = values[path];
    if (conflictNextWrite) {
      conflictNextWrite = false;
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.conflict,
      );
    }
    if ((createOnly && current != null) ||
        (!createOnly && current?.revision != expectedRevision)) {
      throw const KnowledgeDocumentStoreFailure(
        KnowledgeDocumentStoreFailureCode.conflict,
      );
    }
    revision += 1;
    writes += 1;
    final result = KnowledgeStoredDocument(
      path: path,
      bytes: bytes,
      revision: '$revision',
    );
    values[path] = result;
    return result;
  }
}

final class _PortableReplayDavValue {
  _PortableReplayDavValue(this.body, this.etag);

  List<int> body;
  String etag;
}

final class _PortableReplayWebDav implements WebDavTransport {
  final Map<String, _PortableReplayDavValue> values =
      <String, _PortableReplayDavValue>{};
  final List<WebDavRequest> requests = <WebDavRequest>[];
  WebDavResponse? scripted;
  WebDavTransportFailure? failure;
  var revision = 0;

  @override
  Future<WebDavResponse> send(WebDavRequest request) async {
    requests.add(request);
    final transportFailure = failure;
    if (transportFailure != null) throw transportFailure;
    final response = scripted;
    if (response != null) {
      scripted = null;
      return response;
    }
    final key = request.uri.toString();
    final current = values[key];
    switch (request.method) {
      case WebDavMethod.head:
        return current == null
            ? WebDavResponse(statusCode: 404)
            : WebDavResponse(
                statusCode: 200,
                headers: <String, String>{'ETag': current.etag},
              );
      case WebDavMethod.get:
        return current == null
            ? WebDavResponse(statusCode: 404)
            : WebDavResponse(
                statusCode: 200,
                headers: <String, String>{'ETag': current.etag},
                body: current.body,
              );
      case WebDavMethod.put:
        if (request.headers['If-None-Match'] == '*' && current != null) {
          return WebDavResponse(statusCode: 412);
        }
        if (request.headers['If-Match'] != null &&
            request.headers['If-Match'] != current?.etag) {
          return WebDavResponse(statusCode: 412);
        }
        revision += 1;
        values[key] = _PortableReplayDavValue(request.body, '"$revision"');
        return WebDavResponse(statusCode: current == null ? 201 : 204);
      case WebDavMethod.delete:
        if (current == null) return WebDavResponse(statusCode: 404);
        values.remove(key);
        return WebDavResponse(statusCode: 204);
    }
  }
}

final class _ImaReplayTransfer implements ImaPortableTransferGateway {
  ImaPortableOutcome shareOutcome = ImaPortableOutcome.completed;

  @override
  Future<ImaPortableOutcome> save(ImaPortablePackage package) async =>
      ImaPortableOutcome.completed;

  @override
  Future<ImaPortableOutcome> share(
    ImaPortablePackage package, {
    ShareAnchor? anchor,
  }) async =>
      shareOutcome;
}

final class _ImaReplayExternalUri implements ExternalUriGateway {
  Uri? opened;

  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async {
    opened = uri;
    return ExternalUriOpenOutcome.opened;
  }
}

final class _PodcastAudioReplayQuestionProvider
    implements PodcastQuestionProvider {
  _PodcastAudioReplayQuestionProvider({this.forged = false});

  final bool forged;
  var calls = 0;

  @override
  Future<PodcastQuestionProviderResult> answer(
    PodcastQuestionProviderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    calls += 1;
    return PodcastQuestionProviderResult(
      refused: false,
      statements: <PodcastQuestionStatementDraft>[
        PodcastQuestionStatementDraft(
          text: 'The privacy policy changed.',
          segmentIndexes: <int>[forged ? 99 : 1],
        ),
      ],
      costMicros: 100,
    );
  }
}

PodcastTranscript _podcastAudioReplayTranscript() => PodcastTranscript(
      language: 'en-US',
      providerVersion: 'replay-v1',
      segments: const <PodcastTranscriptSegment>[
        PodcastTranscriptSegment(
          index: 0,
          start: Duration.zero,
          end: Duration(seconds: 10),
          text: 'Welcome to the weekly show.',
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

final class _PodcastAudioReplaySafety implements AudioBriefSafetyGate {
  const _PodcastAudioReplaySafety({this.blocked = false});

  final bool blocked;

  @override
  Future<AudioBriefSafetyResult> check(
    Iterable<String> fragments, {
    required AudioBriefSafetyStage stage,
  }) async =>
      AudioBriefSafetyResult(
        allowed: !(blocked && stage == AudioBriefSafetyStage.source),
      );
}

final class _PodcastAudioReplayScript implements AudioBriefScriptProvider {
  var calls = 0;

  @override
  Future<AudioBriefScriptProviderResult> generate(
    AudioBriefScriptProviderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async {
    calls += 1;
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

class _PodcastAudioReplayRenderer implements AudioBriefRenderer {
  @override
  Future<AudioBriefRenderResult> render(
    AudioBriefRenderRequest request, {
    required String operationId,
    required PodcastTaskCancellation cancellation,
  }) async =>
      _podcastAudioReplayRenderResult();
}

final class _PodcastAudioReplayPendingRenderer implements AudioBriefRenderer {
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

  void complete() => _result.complete(_podcastAudioReplayRenderResult());
}

AudioBriefService _podcastAudioReplayBrief({
  AudioBriefSafetyGate? safety,
  _PodcastAudioReplayScript? script,
  AudioBriefRenderer? renderer,
  MemoryPodcastAudioIntelligenceUsageLedger? ledger,
}) =>
    AudioBriefService(
      safety: safety ?? const _PodcastAudioReplaySafety(),
      scriptProvider: script ?? _PodcastAudioReplayScript(),
      renderer: renderer ?? _PodcastAudioReplayRenderer(),
      usageLedger: ledger ?? MemoryPodcastAudioIntelligenceUsageLedger(),
    );

AudioBriefRequest _podcastAudioReplayBriefRequest(String id) =>
    AudioBriefRequest(
      operationId: id,
      day: DateTime.utc(2026, 8, 6),
      language: 'en-US',
      style: AudioBriefStyle.dialogue,
      sources: <AudioBriefSource>[
        AudioBriefSource(
          sourceId: 'source-a',
          title: 'Policy update',
          text: 'The privacy policy changed with clearer controls.',
        ),
      ],
    );

AudioBriefRenderResult _podcastAudioReplayRenderResult() =>
    AudioBriefRenderResult(
      bytes: Uint8List.fromList(<int>[0x49, 0x44, 0x33, 1]),
      mediaType: 'audio/mpeg',
      duration: const Duration(minutes: 2),
      billableDuration: const Duration(minutes: 2),
      costMicros: 200,
    );
