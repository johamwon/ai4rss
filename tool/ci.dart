import 'dart:io';

Future<void> main(List<String> arguments) async {
  final lane = arguments.isEmpty ? 'fast' : arguments.first;
  if (lane != 'fast') {
    stderr.writeln('Supported lane: fast');
    exitCode = 64;
    return;
  }

  await _run('flutter', <String>['pub', 'get']);
  await _run(
    'dart',
    <String>['format', '--output=none', '--set-exit-if-changed', '.'],
  );
  await _run(
    'flutter',
    <String>['analyze', '--fatal-infos', '--fatal-warnings'],
  );

  const pureDartPackages = <String>[
    'packages/river_domain',
    'packages/river_data',
    'packages/river_feed',
    'packages/river_extract',
    'packages/river_ai',
    'packages/river_preferences',
    'packages/river_audio',
    'packages/river_knowledge',
    'packages/river_sync',
    'packages/river_commerce',
    'packages/river_test_harness',
  ];
  for (final package in pureDartPackages) {
    if (Directory('$package/test').existsSync()) {
      await _run('dart', <String>['test'], workingDirectory: package);
    }
  }

  const flutterPackages = <String>[
    'packages/river_platform',
    'packages/river_design_system',
    'apps/river_app',
  ];
  for (final package in flutterPackages) {
    if (Directory('$package/test').existsSync()) {
      await _run('flutter', <String>['test'], workingDirectory: package);
    }
  }

  await _run(
    'dart',
    <String>[
      'run',
      'packages/river_test_harness/bin/river_harness.dart',
      'check',
    ],
  );
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final resolvedExecutable = _resolveSdkExecutable(executable);
  stdout.writeln('> $resolvedExecutable ${arguments.join(' ')}');
  final process = await Process.start(
    resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException(
      resolvedExecutable,
      arguments,
      'Command failed',
      code,
    );
  }
}

String _resolveSdkExecutable(String executable) {
  if (!Platform.isWindows) return executable;
  if (executable == 'dart') return Platform.resolvedExecutable;
  if (executable != 'flutter') return executable;

  final dartSdkBin = File(Platform.resolvedExecutable).parent;
  final flutterBin = dartSdkBin.parent.parent.parent;
  final flutterBatch =
      File('${flutterBin.path}${Platform.pathSeparator}flutter.bat');
  return flutterBatch.existsSync() ? flutterBatch.path : 'flutter.bat';
}
