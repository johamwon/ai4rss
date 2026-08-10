import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('river-font-test-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('valid TTF is stored, verified and restored', () async {
    final repository = PlatformCustomFontAssetRepository(
      directoryProvider: () async => root,
      picker: () async => CustomFontSelection(
        fileName: '阅读字体.ttf',
        bytes: _ttfBytes(24),
      ),
    );

    final picked = await repository.pick();
    expect(picked, isNotNull);
    expect(picked!.displayName, '阅读字体.ttf');
    expect(picked.extension, 'ttf');
    expect(picked.family, startsWith('RiverCustomFont_'));
    expect(picked.toString(), isNot(contains('阅读字体')));

    await File(
      '${root.path}${Platform.pathSeparator}'
      'font-${picked.sha256Hex}.ttf.tmp',
    ).writeAsString('interrupted font write');
    await File(
      '${root.path}${Platform.pathSeparator}active.json.tmp',
    ).writeAsString('interrupted metadata write');
    await repository.saveActive(picked);
    final restored = await repository.loadActive();
    expect(restored, isNotNull);
    expect(restored!.sha256Hex, picked.sha256Hex);
    expect(restored.bytes, picked.bytes);
  });

  test('OTF signature determines the persisted file type', () async {
    final repository = PlatformCustomFontAssetRepository(
      directoryProvider: () async => root,
      picker: () async => CustomFontSelection(
        fileName: 'river-font.otf',
        bytes: _otfBytes(20),
      ),
    );

    final picked = await repository.pick();
    expect(picked!.extension, 'otf');
    await repository.saveActive(picked);
    expect(
      root.listSync().whereType<File>().any(
            (file) => file.path.endsWith('.otf'),
          ),
      isTrue,
    );
  });

  test('invalid and collection font files fail closed', () async {
    for (final bytes in <Uint8List>[
      Uint8List.fromList(List<int>.filled(20, 7)),
      Uint8List.fromList(
        <int>[...'ttcf'.codeUnits, ...List<int>.filled(16, 0)],
      ),
    ]) {
      final repository = PlatformCustomFontAssetRepository(
        directoryProvider: () async => root,
        picker: () async => CustomFontSelection(
          fileName: 'unsafe.ttf',
          bytes: bytes,
        ),
      );
      await expectLater(
        repository.pick(),
        throwsA(isA<CustomFontAssetException>()),
      );
    }
  });

  test('corrupt persisted bytes are not loaded', () async {
    final repository = PlatformCustomFontAssetRepository(
      directoryProvider: () async => root,
      picker: () async => CustomFontSelection(
        fileName: 'reader.ttf',
        bytes: _ttfBytes(32),
      ),
    );
    final asset = (await repository.pick())!;
    await repository.saveActive(asset);
    final font = root
        .listSync()
        .whereType<File>()
        .singleWhere((file) => file.path.endsWith('.ttf'));
    await font.writeAsBytes(_ttfBytes(31), flush: true);

    await expectLater(
      repository.loadActive(),
      throwsA(isA<CustomFontAssetException>()),
    );
  });

  test('clear removes managed assets without touching unrelated files',
      () async {
    final repository = PlatformCustomFontAssetRepository(
      directoryProvider: () async => root,
      picker: () async => CustomFontSelection(
        fileName: 'reader.ttf',
        bytes: _ttfBytes(24),
      ),
    );
    await repository.saveActive((await repository.pick())!);
    final unrelated = File('${root.path}${Platform.pathSeparator}keep.txt');
    await unrelated.writeAsString('keep');

    await repository.clearActive();

    expect(await repository.loadActive(), isNull);
    expect(await unrelated.readAsString(), 'keep');
  });
}

Uint8List _ttfBytes(int length) => Uint8List.fromList(<int>[
      0,
      1,
      0,
      0,
      ...List<int>.generate(length - 4, (index) => index % 251),
    ]);

Uint8List _otfBytes(int length) => Uint8List.fromList(<int>[
      ...'OTTO'.codeUnits,
      ...List<int>.generate(length - 4, (index) => (index + 3) % 251),
    ]);
