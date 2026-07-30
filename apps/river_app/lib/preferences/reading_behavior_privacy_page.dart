import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river_domain/river_domain.dart';

const String readingBehaviorLocalOnlyExplanation =
    'River 只在这台设备上记录文章展示、打开、有效阅读时长、阅读进度、完成、'
    '收藏、保存到知识库和不喜欢等操作，用来逐步理解你的阅读偏好。';

const String readingBehaviorExcludedDataExplanation =
    '这些记录不会自动上传，也不包含文章正文、标题、网址、笔记或 AI 内容。';

final class ReadingBehaviorIntroductionDialog extends StatelessWidget {
  const ReadingBehaviorIntroductionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('是否启用本地阅读偏好？'),
      content: const SingleChildScrollView(
        child: _ReadingBehaviorExplanation(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('暂不开启'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('仅在本机启用'),
        ),
      ],
    );
  }
}

final class ReadingBehaviorPrivacyPage extends StatefulWidget {
  const ReadingBehaviorPrivacyPage({
    required this.repository,
    required this.clock,
    this.copyExport,
    super.key,
  });

  final ReadingBehaviorRepository repository;
  final Clock clock;
  final Future<void> Function(String contents)? copyExport;

  @override
  State<ReadingBehaviorPrivacyPage> createState() =>
      _ReadingBehaviorPrivacyPageState();
}

final class _ReadingBehaviorPrivacyPageState
    extends State<ReadingBehaviorPrivacyPage> {
  ReadingBehaviorSettings _settings = const ReadingBehaviorSettings();
  var _busy = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await widget.repository.readSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loaded = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loaded = true);
      _message('阅读偏好设置暂不可用');
    }
  }

  Future<void> _setCaptureEnabled(bool enabled) async {
    if (_busy || enabled == _settings.captureEnabled) return;
    if (enabled && await widget.repository.needsIntroduction()) {
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ReadingBehaviorIntroductionDialog(),
      );
      if (accepted != true || !mounted) return;
    }
    await _save(_settings.copyWith(captureEnabled: enabled));
  }

  Future<void> _setRetentionDays(int? days) async {
    if (days == null || days == _settings.retentionDays) return;
    await _save(_settings.copyWith(retentionDays: days));
  }

  Future<void> _save(ReadingBehaviorSettings settings) async {
    setState(() => _busy = true);
    try {
      await widget.repository.saveSettings(
        settings,
        updatedAt: widget.clock.now(),
      );
      if (mounted) {
        setState(() => _settings = settings);
        _message('设置已保存在本机');
      }
    } on Object {
      if (mounted) _message('设置保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyExport() async {
    setState(() => _busy = true);
    try {
      final export = await widget.repository.exportJson(
        exportedAt: widget.clock.now(),
      );
      final copyExport = widget.copyExport;
      if (copyExport == null) {
        await Clipboard.setData(ClipboardData(text: export));
      } else {
        await copyExport(export);
      }
      if (mounted) _message('行为数据已复制到剪贴板');
    } on Object {
      if (mounted) _message('行为数据导出失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearEvents() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空本地行为记录？'),
            content: const Text(
              '这只会删除本机上的阅读行为记录，不会删除订阅、文章、收藏、笔记或知识库内容。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('清空记录'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final deleted = await widget.repository.clearEvents();
      if (mounted) _message('已清空 $deleted 条本地行为记录');
    } on Object {
      if (mounted) _message('清空失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final retentionOptions = <int>{
      30,
      90,
      365,
      _settings.retentionDays,
    }.toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('阅读偏好与隐私')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                const _ReadingBehaviorExplanation(),
                const SizedBox(height: 16),
                Semantics(
                  toggled: _settings.captureEnabled,
                  label: '本地阅读偏好记录',
                  value: _settings.captureEnabled ? '已开启' : '已关闭',
                  child: ExcludeSemantics(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('记录本地阅读偏好'),
                      subtitle: Text(
                        _settings.captureEnabled
                            ? '已开启，只写入这台设备'
                            : '已关闭，不会新增行为记录',
                      ),
                      value: _settings.captureEnabled,
                      onChanged: _busy
                          ? null
                          : (enabled) => unawaited(
                                _setCaptureEnabled(enabled),
                              ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('保留时间'),
                  subtitle: const Text('过期记录会从本机清理'),
                  trailing: DropdownButton<int>(
                    value: _settings.retentionDays,
                    onChanged: _busy
                        ? null
                        : (days) => unawaited(_setRetentionDays(days)),
                    items: retentionOptions
                        .map(
                          (days) => DropdownMenuItem<int>(
                            value: days,
                            child: Text(_retentionLabel(days)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('复制行为数据'),
                  subtitle: const Text('导出有版本号的 JSON，便于查看或迁移'),
                  enabled: !_busy,
                  onTap: _busy ? null : () => unawaited(_copyExport()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('清空本地行为记录'),
                  subtitle: const Text('不会删除文章、收藏、笔记或知识库内容'),
                  enabled: !_busy,
                  onTap: _busy ? null : () => unawaited(_clearEvents()),
                ),
              ],
            ),
    );
  }
}

final class _ReadingBehaviorExplanation extends StatelessWidget {
  const _ReadingBehaviorExplanation();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '$readingBehaviorLocalOnlyExplanation $readingBehaviorExcludedDataExplanation',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '你的数据由你控制',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(readingBehaviorLocalOnlyExplanation),
            const SizedBox(height: 8),
            const Text(readingBehaviorExcludedDataExplanation),
          ],
        ),
      ),
    );
  }
}

String _retentionLabel(int days) {
  if (days == 365) return '1 年';
  return '$days 天';
}
