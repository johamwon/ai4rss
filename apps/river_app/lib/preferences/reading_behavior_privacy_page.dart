import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river_domain/river_domain.dart';

import 'personalized_articles.dart';

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
    this.personalization,
    super.key,
  });

  final ReadingBehaviorRepository repository;
  final Clock clock;
  final Future<void> Function(String contents)? copyExport;
  final PreferenceProfileExperience? personalization;

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
                if (widget.personalization case final personalization?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune),
                    title: const Text('查看和编辑偏好画像'),
                    subtitle: const Text('查看来源与主题偏好、推荐开关和屏蔽项'),
                    enabled: !_busy,
                    onTap: _busy
                        ? null
                        : () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (context) => PreferenceProfilePage(
                                  experience: personalization,
                                ),
                              ),
                            ),
                  ),
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

final class PreferenceProfilePage extends StatefulWidget {
  const PreferenceProfilePage({required this.experience, super.key});

  final PreferenceProfileExperience experience;

  @override
  State<PreferenceProfilePage> createState() => _PreferenceProfilePageState();
}

final class _PreferenceProfilePageState extends State<PreferenceProfilePage> {
  PreferenceProfileSnapshot? _snapshot;
  var _busy = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final snapshot = await widget.experience.loadProfile();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      await _reload();
      if (mounted) _message('偏好画像已在本机更新');
    } on Object {
      if (mounted) _message('偏好画像更新失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (!enabled) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('关闭个性化排序？'),
              content: const Text(
                '关闭后会停止新增阅读行为，并立即回到最新时间排序。已有画像仍保留，之后可以重新开启。',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('关闭并回到时间排序'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }
    await _run(() => widget.experience.setEnabled(enabled));
  }

  Future<void> _addBlockedTopic() async {
    final controller = TextEditingController();
    final topic = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('屏蔽主题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: '主题名称',
            hintText: '例如：剧透',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('屏蔽'),
          ),
        ],
      ),
    );
    controller.dispose();
    final normalized = topic?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty || !mounted) return;
    await _run(() => widget.experience.setTopicBlocked(normalized, true));
  }

  Future<void> _clearProfile() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空偏好画像？'),
            content: const Text(
              '这会删除本机阅读行为、来源/主题调整和屏蔽项。不会删除订阅、文章、收藏、笔记或知识库内容。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('清空画像'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _run(() async {
      await widget.experience.clearProfile();
    });
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('偏好画像')),
      body: switch ((snapshot, _loadError)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (null, _) => _ProfileLoadError(onRetry: _reload),
        (final data?, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              Text(
                '画像只保存在本机，由 ${data.evidenceCount} 条版本化行为证据生成。'
                '编辑只改变排序，不修改文章内容。',
              ),
              const SizedBox(height: 12),
              Semantics(
                toggled: data.settings.captureEnabled,
                label: '个性化排序与本地行为学习',
                value: data.settings.captureEnabled ? '已开启' : '已关闭',
                child: ExcludeSemantics(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('个性化排序'),
                    subtitle: Text(
                      data.settings.captureEnabled
                          ? '已开启，可在文章列表选择智能排序'
                          : '已关闭，文章列表使用时间排序且不新增行为',
                    ),
                    value: data.settings.captureEnabled,
                    onChanged: _busy ? null : (value) => _setEnabled(value),
                  ),
                ),
              ),
              const Divider(),
              _ProfileSection(
                title: '来源偏好',
                emptyLabel: '还没有足够的来源偏好证据',
                dimensions: data.sources,
                busy: _busy,
                onAdjustment: (id, value) => _run(
                  () => widget.experience.setSourceAdjustment(id, value),
                ),
                onBlocked: (id, value) => _run(
                  () => widget.experience.setSourceBlocked(id, value),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '主题偏好',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _addBlockedTopic,
                    icon: const Icon(Icons.block),
                    label: const Text('屏蔽主题'),
                  ),
                ],
              ),
              _ProfileSection(
                emptyLabel: '还没有主题证据或屏蔽项',
                dimensions: data.topics,
                busy: _busy,
                onAdjustment: (id, value) => _run(
                  () => widget.experience.setTopicAdjustment(id, value),
                ),
                onBlocked: (id, value) => _run(
                  () => widget.experience.setTopicBlocked(id, value),
                ),
              ),
              const Divider(height: 32),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _clearProfile,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('清空偏好画像'),
              ),
            ],
          ),
      },
    );
  }
}

final class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    this.title,
    required this.emptyLabel,
    required this.dimensions,
    required this.busy,
    required this.onAdjustment,
    required this.onBlocked,
  });

  final String? title;
  final String emptyLabel;
  final List<PreferenceProfileDimension> dimensions;
  final bool busy;
  final void Function(String id, double adjustment) onAdjustment;
  final void Function(String id, bool blocked) onBlocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title case final value?) ...<Widget>[
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        if (dimensions.isEmpty)
          Text(emptyLabel)
        else
          for (final dimension in dimensions)
            Card.outlined(
              child: Column(
                children: <Widget>[
                  ListTile(
                    title: Text(dimension.label),
                    subtitle: Text(
                      '画像分数 ${dimension.score.toStringAsFixed(2)}'
                      '${dimension.adjustment == 0 ? '' : '（含手动调整 ${dimension.adjustment.toStringAsFixed(0)}）'}',
                    ),
                    trailing: PopupMenuButton<double>(
                      enabled: !busy && !dimension.blocked,
                      tooltip: '调整${dimension.label}的偏好',
                      initialValue: dimension.adjustment,
                      onSelected: (value) => onAdjustment(dimension.id, value),
                      itemBuilder: (context) => const <PopupMenuEntry<double>>[
                        PopupMenuItem<double>(value: 2, child: Text('增加此类内容')),
                        PopupMenuItem<double>(value: 0, child: Text('不手动调整')),
                        PopupMenuItem<double>(value: -2, child: Text('减少此类内容')),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('屏蔽'),
                    subtitle: Text(
                      dimension.blocked ? '不会出现在智能排序结果中' : '保留在智能排序候选中',
                    ),
                    value: dimension.blocked,
                    onChanged:
                        busy ? null : (value) => onBlocked(dimension.id, value),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

final class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('偏好画像暂时无法加载'),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
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
