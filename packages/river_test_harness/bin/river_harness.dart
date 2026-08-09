import 'dart:convert';
import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';

Future<void> main(List<String> arguments) async {
  final root = _findWorkspaceRoot(Directory.current);
  final evals = HarnessEvals(root);
  final command = arguments.isEmpty ? 'check' : arguments.first;
  final reports = <EvalReport>[];

  switch (command) {
    case 'check':
      reports
        ..add(evals.verifyFixtures())
        ..add(evals.evaluateFeeds())
        ..add(await evals.evaluateExtraction())
        ..add(await evals.evaluateCloudExtractionReplay())
        ..add(await evals.evaluateCloudTtsReplay())
        ..add(await evals.evaluatePodcastTranscriptionReplay())
        ..add(await evals.evaluateCloudGovernanceReplay())
        ..add(await evals.evaluateCommerceEntitlementReplay())
        ..add(await evals.evaluateUsageLedgerReplay())
        ..add(await evals.evaluateFreeProductReplay())
        ..add(await evals.evaluateKnowledgeVectorReplay())
        ..add(await evals.evaluateKnowledgeSearchReplay())
        ..add(evals.evaluateAiReplay())
        ..add(await evals.evaluateAiProviderReplay())
        ..add(await evals.evaluateAiLongReplay())
        ..add(await evals.evaluateAiCacheReplay())
        ..add(await evals.evaluateManagedAiGatewayReplay())
        ..add(evals.evaluateRanking())
        ..add(await evals.evaluateRankingExperiment());
      break;
    case 'fixture':
      reports.add(evals.verifyFixtures());
      break;
    case 'feed':
      reports.add(evals.evaluateFeeds());
      break;
    case 'extract':
      reports
        ..add(await evals.evaluateExtraction())
        ..add(await evals.evaluateCloudExtractionReplay());
      break;
    case 'tts':
      reports.add(await evals.evaluateCloudTtsReplay());
      break;
    case 'transcribe':
      reports.add(await evals.evaluatePodcastTranscriptionReplay());
      break;
    case 'governance':
      reports.add(await evals.evaluateCloudGovernanceReplay());
      break;
    case 'commerce':
      reports
        ..add(await evals.evaluateCommerceEntitlementReplay())
        ..add(await evals.evaluateUsageLedgerReplay())
        ..add(await evals.evaluateFreeProductReplay());
      break;
    case 'free':
      reports.add(await evals.evaluateFreeProductReplay());
      break;
    case 'knowledge':
      reports
        ..add(await evals.evaluateKnowledgeVectorReplay())
        ..add(await evals.evaluateKnowledgeSearchReplay());
      break;
    case 'ai':
      reports
        ..add(evals.evaluateAiReplay())
        ..add(await evals.evaluateAiProviderReplay())
        ..add(await evals.evaluateAiLongReplay())
        ..add(await evals.evaluateAiCacheReplay())
        ..add(await evals.evaluateManagedAiGatewayReplay());
      break;
    case 'rank':
      reports
        ..add(evals.evaluateRanking())
        ..add(await evals.evaluateRankingExperiment());
      break;
    default:
      stderr.writeln(
        'Usage: river_harness '
        '[check|fixture|feed|extract|tts|transcribe|governance|commerce|free|knowledge|ai|rank]',
      );
      exitCode = 64;
      return;
  }

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(
      reports.map((report) => report.toJson()).toList(),
    ),
  );
  if (reports.any((report) => !report.isSuccess)) exitCode = 1;
}

Directory _findWorkspaceRoot(Directory start) {
  var current = start.absolute;
  while (true) {
    final pubspec =
        File('${current.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('river_workspace')) {
      return current;
    }
    if (current.parent.path == current.path) {
      throw StateError('River workspace root not found from ${start.path}');
    }
    current = current.parent;
  }
}
