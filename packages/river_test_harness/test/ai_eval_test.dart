import 'dart:convert';
import 'dart:io';

import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('production golden set meets bilingual and high-risk gates', () {
    final report = HarnessEvals(_workspaceRoot()).evaluateAiReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 8);
    expect(report.metrics['necessaryFactCoverage'], 1.0);
    expect(report.metrics['matchedNecessaryFacts'], 24);
    expect(report.metrics['forbiddenClaimHitRate'], 0.0);
    expect(report.metrics['forbiddenClaimHits'], 0);
    expect(report.metrics['highRiskCases'], 4);
    expect(
      report.metrics['languages'],
      <String>['en-US', 'zh-CN'],
    );
  });

  test('quality gate rejects weak coverage and a forbidden claim', () {
    final root = Directory.systemTemp.createTempSync('river-ai-eval-');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/evals').createSync(recursive: true);
    Directory('${root.path}/fixtures/ai').createSync(recursive: true);
    File('${root.path}/fixtures/ai/case.json').writeAsStringSync(
      jsonEncode(
        <String, Object>{
          'id': 'case-1',
          'title': 'Synthetic case',
          'language': 'en-US',
          'contentType': 'product',
          'riskLevel': 'low',
          'plainText': 'The source contains alpha and beta.',
        },
      ),
    );
    File('${root.path}/evals/summary_cases.json').writeAsStringSync(
      jsonEncode(
        <String, Object>{
          'qualityGate': <String, Object>{
            'minimumCases': 1,
            'minimumNecessaryFactCoverage': 0.9,
            'maximumForbiddenClaimHitRate': 0,
            'minimumHighRiskCases': 0,
            'requiredLanguages': <String>['en-US'],
            'requiredContentTypes': <String>['product'],
          },
          'cases': <Object>[
            <String, Object>{
              'id': 'case-1',
              'fixture': 'fixtures/ai/case.json',
              'contentType': 'product',
              'riskLevel': 'low',
              'model': 'replay-model',
              'promptVersion': 'article-summary@1',
              'language': 'en-US',
              'requiredFacts': <Object>[
                <String, Object>{
                  'id': 'alpha',
                  'sourceAnyOf': <String>['alpha'],
                  'outputAnyOf': <String>['alpha'],
                },
                <String, Object>{
                  'id': 'beta',
                  'sourceAnyOf': <String>['beta'],
                  'outputAnyOf': <String>['beta'],
                },
              ],
              'forbiddenClaims': <Object>[
                <String, Object>{
                  'id': 'guaranteed-profit',
                  'outputAnyOf': <String>['guaranteed profit'],
                },
              ],
              'replay': <String, Object>{
                'schemaVersion': 'river.article-summary.v1',
                'oneLine': 'The result mentions alpha and guaranteed profit.',
                'keyPoints': <String>[
                  'Alpha is present.',
                  'The second source fact is omitted.',
                  'The output contains an unsafe claim.',
                ],
                'whyItMatters': 'This replay must fail both quality gates.',
                'topics': <String>['testing'],
                'entities': <String>['synthetic case'],
                'estimatedReadingMinutes': 1,
                'language': 'en-US',
              },
            },
          ],
        },
      ),
    );

    final report = HarnessEvals(root).evaluateAiReplay();

    expect(report.isSuccess, isFalse);
    expect(report.metrics['necessaryFactCoverage'], 0.5);
    expect(report.metrics['forbiddenClaimHitRate'], 1.0);
    final messages =
        report.failures.map((failure) => failure.message).join('\n');
    expect(messages, contains('forbidden claim present'));
    expect(messages, contains('necessary fact coverage'));
    expect(messages, contains('forbidden claim hit rate'));
  });

  test('managed gateway replay covers provider resilience contracts', () async {
    final report =
        await HarnessEvals(_workspaceRoot()).evaluateManagedAiGatewayReplay();

    expect(report.isSuccess, isTrue);
    expect(report.total, 4);
    expect(report.metrics['providerCalls'], 7);
    expect(report.metrics['acceptedCostMicros'], 750);
    expect(report.metrics['privateContentInDiagnostics'], isFalse);
  });
}

Directory _workspaceRoot() {
  var current = Directory.current.absolute;
  while (true) {
    final pubspec = File('${current.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('river_workspace')) {
      return current;
    }
    if (current.parent.path == current.path) {
      throw StateError('Workspace root not found');
    }
    current = current.parent;
  }
}
