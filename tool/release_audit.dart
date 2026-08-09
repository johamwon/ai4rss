import 'dart:convert';
import 'dart:io';

enum AuditLevel { passed, warning, error }

final class AuditCheck {
  const AuditCheck({
    required this.id,
    required this.level,
    required this.message,
  });

  final String id;
  final AuditLevel level;
  final String message;

  Map<String, Object> toJson() => <String, Object>{
        'id': id,
        'level': level.name,
        'message': message,
      };
}

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final root = Directory.current.absolute;
  final checks = _audit(root);
  final errors =
      checks.where((check) => check.level == AuditLevel.error).length;
  final warnings =
      checks.where((check) => check.level == AuditLevel.warning).length;
  final strictFailure = options.mode == 'store' && warnings > 0;
  final report = <String, Object>{
    'schema': 'river.release-readiness/1',
    'mode': options.mode,
    'ready': errors == 0 && !strictFailure,
    'summary': <String, int>{
      'passed':
          checks.where((check) => check.level == AuditLevel.passed).length,
      'warnings': warnings,
      'errors': errors,
    },
    'checks': checks.map((check) => check.toJson()).toList(growable: false),
  };

  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  stdout.writeln(encoded);
  if (options.output != null) {
    final output = File(_resolve(root, options.output!));
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('$encoded\n');
  }
  if (errors > 0 || strictFailure) exitCode = 1;
}

List<AuditCheck> _audit(Directory root) {
  final checks = <AuditCheck>[];
  final rootPubspec = _read(root, 'pubspec.yaml', checks);
  final appPubspec = _read(root, 'apps/river_app/pubspec.yaml', checks);
  final lockfile = _read(root, 'pubspec.lock', checks);
  final release = _read(root, '.github/workflows/release.yml', checks);
  final android =
      _read(root, 'apps/river_app/android/app/build.gradle.kts', checks);
  final ios = _read(
    root,
    'apps/river_app/ios/Runner.xcodeproj/project.pbxproj',
    checks,
  );
  final windows =
      _read(root, 'apps/river_app/windows/runner/Runner.rc', checks);
  final dependencies =
      _read(root, 'apps/river_app/lib/app/app_dependencies.dart', checks);
  final gitignore = _read(root, '.gitignore', checks);

  final workspaceVersion = _version(rootPubspec);
  final appVersion = _version(appPubspec);
  checks.add(
    _check(
      id: 'version.aligned',
      passed: workspaceVersion != null &&
          appVersion != null &&
          appVersion.split('+').first == workspaceVersion,
      pass: 'Workspace and application versions are aligned.',
      fail:
          'Workspace and application versions must share the same base version.',
    ),
  );
  checks.add(
    _check(
      id: 'version.build-number',
      passed: appVersion != null &&
          RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(appVersion),
      pass: 'Application version includes a numeric build number.',
      fail: 'Application version must use semantic-version+numeric-build.',
    ),
  );
  checks.add(
    _check(
      id: 'dependencies.locked',
      passed: lockfile.contains('sdks:') && lockfile.contains('sha256:'),
      pass: 'Dependency lockfile contains SDK and checksum metadata.',
      fail: 'Dependency lockfile is missing or incomplete.',
    ),
  );
  checks.add(
    _check(
      id: 'app.production-dependencies',
      passed: !appPubspec.contains('river_test_harness:'),
      pass: 'The production app does not depend on the test harness.',
      fail: 'The production app must not depend on river_test_harness.',
    ),
  );
  checks.add(
    _check(
      id: 'release.draft',
      passed:
          release.contains('gh release create') && release.contains('--draft'),
      pass: 'Release publication is draft-only pending human approval.',
      fail: 'Release workflow must create a draft release.',
    ),
  );
  checks.add(
    _check(
      id: 'release.checksums',
      passed: release.contains('sha256sum * > SHA256SUMS.txt'),
      pass: 'Release workflow emits SHA-256 checksums.',
      fail: 'Release workflow must emit SHA-256 checksums.',
    ),
  );
  checks.add(
    _check(
      id: 'release.platforms',
      passed: <String>['android', 'ios', 'windows']
          .every((target) => release.contains('target: $target')),
      pass: 'Release workflow packages Android, iOS, and Windows.',
      fail: 'Release workflow must package all three supported platforms.',
    ),
  );
  checks.add(
    _check(
      id: 'release.optional-services',
      passed: dependencies.contains("'RIVER_RESOURCE_PROXY_URL'") &&
          dependencies.contains("'RIVER_NOTION_BROKER_URL'") &&
          dependencies.contains('resourceProxyUrl.isEmpty') &&
          dependencies.contains('notionBrokerUrl.isNotEmpty'),
      pass:
          'Optional remote services remain compile-time configured and off when empty.',
      fail: 'Optional remote services must fail closed when not configured.',
    ),
  );
  checks.add(
    _check(
      id: 'repository.secret-ignores',
      passed: <String>['*.jks', '*.p12', '*.mobileprovision', '**/secrets.*']
          .every(gitignore.contains),
      pass: 'Common signing and secret files are excluded from source control.',
      fail: 'Secret and signing file ignore rules are incomplete.',
    ),
  );
  checks.add(
    _exists(
      root,
      'docs/PRIVACY.md',
      'docs.privacy',
      'A product data-processing disclosure is present.',
    ),
  );
  checks.add(
    _exists(
      root,
      'docs/SECURITY.md',
      'docs.security',
      'A vulnerability reporting and security-boundary document is present.',
    ),
  );

  checks.addAll(<AuditCheck>[
    _warning(
      'store.android-identity',
      android.contains('com.example'),
      'Android still uses a template application ID; choose the permanent store ID.',
      'Android application ID is no longer a template.',
    ),
    _warning(
      'store.android-signing',
      android.contains('signingConfigs.getByName("debug")'),
      'Android release still uses debug signing; provision managed release signing.',
      'Android release no longer uses debug signing.',
    ),
    _warning(
      'store.ios-identity',
      ios.contains('PRODUCT_BUNDLE_IDENTIFIER = com.example'),
      'iOS still uses a template bundle ID; choose the permanent App Store ID.',
      'iOS bundle ID is no longer a template.',
    ),
    _warning(
      'store.windows-identity',
      windows.contains('com.example') || windows.contains('"river_app"'),
      'Windows metadata still contains template publisher/product values.',
      'Windows publisher and product metadata are release-specific.',
    ),
    _warning(
      'store.signing-and-accounts',
      true,
      'Store signing, platform accounts, legal approval, and deletion rehearsal require external owners and secrets.',
      '',
    ),
    _warning(
      'validation.physical-devices',
      true,
      'Android/iOS/Windows device, interruption, Bluetooth, background, weak-network, low-storage, and clean-install matrices remain physical release evidence.',
      '',
    ),
    _warning(
      'commerce.deferred',
      false,
      '',
      'Payment integration is intentionally excluded; permanent Free capabilities remain releaseable and regression-gated.',
    ),
  ]);
  return checks;
}

AuditCheck _check({
  required String id,
  required bool passed,
  required String pass,
  required String fail,
}) =>
    AuditCheck(
      id: id,
      level: passed ? AuditLevel.passed : AuditLevel.error,
      message: passed ? pass : fail,
    );

AuditCheck _warning(
  String id,
  bool blocked,
  String warning,
  String pass,
) =>
    AuditCheck(
      id: id,
      level: blocked ? AuditLevel.warning : AuditLevel.passed,
      message: blocked ? warning : pass,
    );

AuditCheck _exists(
  Directory root,
  String path,
  String id,
  String message,
) =>
    _check(
      id: id,
      passed: File(_resolve(root, path)).existsSync(),
      pass: message,
      fail: 'Required release document is missing: $path',
    );

String _read(Directory root, String path, List<AuditCheck> checks) {
  final file = File(_resolve(root, path));
  if (!file.existsSync()) {
    checks.add(
      AuditCheck(
        id: 'file.${path.replaceAll('/', '.')}',
        level: AuditLevel.error,
        message: 'Required release input is missing: $path',
      ),
    );
    return '';
  }
  return file.readAsStringSync();
}

String? _version(String pubspec) => RegExp(
      r'^version:\s*([^\s]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

String _resolve(Directory root, String path) =>
    '${root.path}${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}';

final class _Options {
  const _Options({required this.mode, this.output});

  final String mode;
  final String? output;

  static _Options parse(List<String> arguments) {
    var mode = 'candidate';
    String? output;
    for (final argument in arguments) {
      if (argument.startsWith('--mode=')) {
        mode = argument.substring('--mode='.length);
      } else if (argument.startsWith('--output=')) {
        output = argument.substring('--output='.length);
      } else {
        stderr.writeln('Unknown release audit option: $argument');
        exit(64);
      }
    }
    if (mode != 'candidate' && mode != 'store') {
      stderr.writeln('Release audit mode must be candidate or store.');
      exit(64);
    }
    if (output != null) {
      final normalized = output.replaceAll('\\', '/');
      final segments = normalized.split('/');
      if (normalized.isEmpty ||
          normalized.startsWith('/') ||
          RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
          segments.contains('..')) {
        stderr.writeln('Release audit output must stay inside the workspace.');
        exit(64);
      }
    }
    return _Options(mode: mode, output: output);
  }
}
