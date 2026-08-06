import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:river_ai/river_ai.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_commerce/river_commerce.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
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
