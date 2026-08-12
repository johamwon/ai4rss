import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_design_system/river_design_system.dart';
import 'package:river_platform/river_platform.dart';

import '../app/app_font_controller.dart';

final class FontSettingsPage extends StatefulWidget {
  const FontSettingsPage({required this.controller, super.key});

  final AppFontController controller;

  @override
  State<FontSettingsPage> createState() => _FontSettingsPageState();
}

final class _FontSettingsPageState extends State<FontSettingsPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.initialized) {
      unawaited(widget.controller.initialize());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('字体与排版')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final active = widget.controller.active;
          final platformFamilies = RiverTypography.sansSerifFamilies(
            Theme.of(context).platform,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              Text(
                '中文字体',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                active == null
                    ? '当前使用平台中文字体：${platformFamilies.first}'
                    : '当前使用自定义字体：${active.displayName}',
              ),
              const SizedBox(height: 16),
              _FontPreview(activeFamily: active?.family),
              const SizedBox(height: 20),
              if (widget.controller.startupFailure case final failure?) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      failure,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: widget.controller.busy ? null : _import,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('导入字体文件'),
              ),
              if (active != null || widget.controller.startupFailure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: widget.controller.busy ? null : _restoreDefault,
                    icon: const Icon(Icons.restore),
                    label: const Text('恢复平台中文字体'),
                  ),
                ),
              if (widget.controller.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 28),
              Text(
                '字体回退顺序',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(platformFamilies.join(' → ')),
              const SizedBox(height: 24),
              const _FontImportNotice(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _import() async {
    try {
      final outcome = await widget.controller.importFromFile();
      if (!mounted || outcome == CustomFontImportOutcome.cancelled) return;
      _showMessage('字体已导入，并应用到整个 River');
    } on CustomFontAssetException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('字体无法加载，文件可能损坏或不受系统支持');
    }
  }

  Future<void> _restoreDefault() async {
    try {
      await widget.controller.restoreDefault();
      if (mounted) _showMessage('已恢复平台中文字体');
    } on Object {
      if (mounted) _showMessage('暂时无法删除已保存的字体，请稍后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _FontPreview extends StatelessWidget {
  const _FontPreview({required this.activeFamily});

  final String? activeFamily;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '字体预览',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '山川湖海，清风明月。\n阅读让复杂世界变得清晰。\nRiver 2026 · 中文 English 123',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: activeFamily,
                  height: 1.7,
                ),
          ),
        ),
      ),
    );
  }
}

final class _FontImportNotice extends StatelessWidget {
  const _FontImportNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '导入说明',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '支持单个 TTF 或 OTF 文件，最大 32 MiB。字体只复制到本机应用目录，不会上传、同步或写入日志。'
              '请确认你拥有该字体的使用授权。TTC 字体集合暂不支持。',
            ),
            const SizedBox(height: 8),
            const Text(
              '自定义字体会应用到应用界面；文章阅读器选择“系统字体”时也会跟随。'
              '缺失的汉字、符号和 Emoji 会自动使用平台中文字体回退。',
            ),
          ],
        ),
      ),
    );
  }
}
