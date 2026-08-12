import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/app_font_controller.dart';
import 'package:river_app/settings/font_settings_page.dart';
import 'package:river_design_system/river_design_system.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  testWidgets('imports, previews and restores a custom font', (tester) async {
    final repository = _MemoryFontRepository(_fontAsset());
    final loader = _RecordingFontLoader();
    final controller = AppFontController(
      repository: repository,
      loader: loader,
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: RiverTheme.light(platform: TargetPlatform.windows),
        home: FontSettingsPage(controller: controller),
      ),
    );

    expect(find.textContaining('Microsoft YaHei UI'), findsWidgets);
    await tester.tap(find.text('导入字体文件'));
    await tester.pumpAndSettle();

    expect(find.textContaining('reader.ttf'), findsOneWidget);
    expect(controller.activeFamily, 'RiverCustomFont_test');
    expect(loader.loaded, <String>['RiverCustomFont_test']);
    expect(repository.saved, isNotNull);

    final preview = tester.widget<Text>(find.textContaining('山川湖海'));
    expect(preview.style!.fontFamily, 'RiverCustomFont_test');

    await tester.tap(find.text('恢复平台中文字体'));
    await tester.pumpAndSettle();
    expect(controller.active, isNull);
    expect(repository.cleared, isTrue);
  });

  testWidgets('shows an actionable startup recovery state', (tester) async {
    final controller = AppFontController(
      repository: _FailingFontRepository(),
      loader: _RecordingFontLoader(),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: FontSettingsPage(controller: controller)),
    );

    expect(find.textContaining('已保存的自定义字体无法加载'), findsOneWidget);
    expect(find.text('恢复平台中文字体'), findsOneWidget);
  });

  testWidgets('rebuilds the app-wide theme after a custom font is loaded',
      (tester) async {
    final controller = AppFontController(
      repository: _MemoryFontRepository(_fontAsset()),
      loader: _RecordingFontLoader(),
    );
    await controller.initialize();
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: controller,
        builder: (context, child) => MaterialApp(
          theme: RiverTheme.light(
            fontFamily: controller.activeFamily,
            platform: TargetPlatform.windows,
          ),
          home: Builder(
            builder: (context) => Text(
              '中文主题',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );

    var themedText = tester.widget<Text>(find.text('中文主题'));
    expect(themedText.style!.fontFamily, 'Microsoft YaHei UI');

    await controller.importFromFile();
    await tester.pumpAndSettle();

    themedText = tester.widget<Text>(find.text('中文主题'));
    expect(themedText.style!.fontFamily, 'RiverCustomFont_test');
  });
}

final class _MemoryFontRepository implements CustomFontAssetRepository {
  _MemoryFontRepository(this.next);

  final CustomFontAsset next;
  CustomFontAsset? saved;
  bool cleared = false;

  @override
  Future<void> clearActive() async {
    cleared = true;
    saved = null;
  }

  @override
  Future<CustomFontAsset?> loadActive() async => saved;

  @override
  Future<CustomFontAsset?> pick() async => next;

  @override
  Future<void> saveActive(CustomFontAsset asset) async {
    saved = asset;
  }
}

final class _FailingFontRepository implements CustomFontAssetRepository {
  @override
  Future<void> clearActive() async {}

  @override
  Future<CustomFontAsset?> loadActive() {
    throw const CustomFontAssetException('corrupt');
  }

  @override
  Future<CustomFontAsset?> pick() async => null;

  @override
  Future<void> saveActive(CustomFontAsset asset) async {}
}

final class _RecordingFontLoader implements RuntimeFontLoader {
  final List<String> loaded = <String>[];

  @override
  Future<void> load(CustomFontAsset asset) async {
    loaded.add(asset.family);
  }
}

CustomFontAsset _fontAsset() => CustomFontAsset(
      displayName: 'reader.ttf',
      extension: 'ttf',
      family: 'RiverCustomFont_test',
      sha256Hex: List<String>.filled(64, 'a').join(),
      bytes: Uint8List.fromList(<int>[0, 1, 0, 0, ...List<int>.filled(8, 0)]),
    );
