import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';

import 'notion_workspace.dart';

final class KnowledgeLibraryPage extends StatefulWidget {
  const KnowledgeLibraryPage({
    required this.repository,
    required this.files,
    required this.externalUri,
    this.imaInterop,
    this.imageFetcher,
    this.exportManager,
    this.notionWorkspace,
    super.key,
  });

  final KnowledgeRepository repository;
  final KnowledgeMarkdownFileGateway files;
  final KnowledgeImageFetcher? imageFetcher;
  final ExternalUriGateway externalUri;
  final ImaPortableInterop? imaInterop;
  final KnowledgeExportManager? exportManager;
  final NotionWorkspaceExperience? notionWorkspace;

  @override
  State<KnowledgeLibraryPage> createState() => _KnowledgeLibraryPageState();
}

final class _KnowledgeLibraryPageState extends State<KnowledgeLibraryPage> {
  final _query = TextEditingController();
  String? _selectedId;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识'),
        actions: <Widget>[
          IconButton(
            onPressed: widget.notionWorkspace == null
                ? null
                : () => unawaited(_openNotion()),
            icon: const Icon(Icons.cloud_outlined),
            tooltip: widget.notionWorkspace == null
                ? '此构建未配置 Notion 服务'
                : 'Notion 连接与目标',
          ),
        ],
      ),
      body: StreamBuilder<List<KnowledgeItem>>(
        stream: widget.repository.watchItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _LibraryMessage(
              icon: Icons.error_outline,
              title: '知识库暂时无法读取',
              message: '本地内容没有丢失，请稍后重新打开。',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snapshot.data!;
          if (allItems.isEmpty) {
            return const _LibraryMessage(
              icon: Icons.auto_stories_outlined,
              title: '知识库还是空的',
              message: '在阅读文章时选择“保存到知识库”，高亮与笔记会一起保留。',
            );
          }
          final items = _filter(allItems, _query.text);
          final width = MediaQuery.sizeOf(context).width;
          if (width >= 900) {
            final selected = _selected(items);
            return Row(
              children: <Widget>[
                SizedBox(
                  width: 380,
                  child: _KnowledgeListPane(
                    items: items,
                    query: _query,
                    selectedId: selected?.id,
                    onQueryChanged: (_) => setState(() {}),
                    onSelected: (item) => setState(() => _selectedId = item.id),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? const _LibraryMessage(
                          icon: Icons.search_off_outlined,
                          title: '没有匹配内容',
                          message: '调整搜索词后再试。',
                        )
                      : KnowledgeDetailPane(
                          item: selected,
                          repository: widget.repository,
                          files: widget.files,
                          imageFetcher: widget.imageFetcher,
                          externalUri: widget.externalUri,
                          imaInterop: widget.imaInterop,
                          exportManager: widget.exportManager,
                          notionWorkspace: widget.notionWorkspace,
                          onConfigureNotion: _openNotion,
                        ),
                ),
              ],
            );
          }
          return _KnowledgeListPane(
            items: items,
            query: _query,
            onQueryChanged: (_) => setState(() {}),
            onSelected: (item) => unawaited(_openDetail(item)),
          );
        },
      ),
    );
  }

  KnowledgeItem? _selected(List<KnowledgeItem> items) {
    if (items.isEmpty) return null;
    final selectedId = _selectedId;
    if (selectedId != null) {
      for (final item in items) {
        if (item.id == selectedId) return item;
      }
    }
    return items.first;
  }

  Future<void> _openDetail(KnowledgeItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('知识详情')),
          body: KnowledgeDetailPane(
            item: item,
            repository: widget.repository,
            files: widget.files,
            imageFetcher: widget.imageFetcher,
            externalUri: widget.externalUri,
            imaInterop: widget.imaInterop,
            exportManager: widget.exportManager,
            notionWorkspace: widget.notionWorkspace,
            onConfigureNotion: _openNotion,
          ),
        ),
      ),
    );
  }

  Future<void> _openNotion() async {
    final workspace = widget.notionWorkspace;
    if (workspace == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => NotionWorkspacePage(experience: workspace),
      ),
    );
  }
}

final class _KnowledgeListPane extends StatelessWidget {
  const _KnowledgeListPane({
    required this.items,
    required this.query,
    required this.onQueryChanged,
    required this.onSelected,
    this.selectedId,
  });

  final List<KnowledgeItem> items;
  final TextEditingController query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<KnowledgeItem> onSelected;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchBar(
            controller: query,
            leading: const Icon(Icons.search),
            hintText: '搜索标题、来源、标签与笔记',
            onChanged: onQueryChanged,
            trailing: <Widget>[
              if (query.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    query.clear();
                    onQueryChanged('');
                  },
                  icon: const Icon(Icons.clear),
                  tooltip: '清空搜索',
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const _LibraryMessage(
                  icon: Icons.search_off_outlined,
                  title: '没有匹配内容',
                  message: '尝试搜索标题、来源或笔记中的其他词。',
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = selectedId == item.id;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: '${item.title}，来源 ${item.source.sourceTitle}，'
                          '${item.excerpts.length} 条高亮，${item.notes.length} 条笔记',
                      child: ListTile(
                        selected: selected,
                        leading: const Icon(Icons.article_outlined),
                        title: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _listSubtitle(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onSelected(item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

final class KnowledgeDetailPane extends StatelessWidget {
  const KnowledgeDetailPane({
    required this.item,
    required this.repository,
    required this.files,
    required this.externalUri,
    this.imaInterop,
    this.imageFetcher,
    this.exportManager,
    this.notionWorkspace,
    this.onConfigureNotion,
    super.key,
  });

  final KnowledgeItem item;
  final KnowledgeRepository repository;
  final KnowledgeMarkdownFileGateway files;
  final KnowledgeImageFetcher? imageFetcher;
  final ExternalUriGateway externalUri;
  final ImaPortableInterop? imaInterop;
  final KnowledgeExportManager? exportManager;
  final NotionWorkspaceExperience? notionWorkspace;
  final Future<void> Function()? onConfigureNotion;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<KnowledgeItem?>(
      stream: repository.watchItem(item.id),
      initialData: item,
      builder: (context, snapshot) {
        final current = snapshot.data;
        if (current == null) {
          return const _LibraryMessage(
            icon: Icons.delete_outline,
            title: '这条知识已被删除',
            message: '返回列表继续浏览其他内容。',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: <Widget>[
            SelectableText(
              current.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${current.source.sourceTitle}'
              '${current.source.author == null ? '' : ' · ${current.source.author}'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(_openOriginal(context, current)),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开原文'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(_exportMarkdown(context, current)),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出 Markdown'),
                ),
                if (imaInterop != null)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        unawaited(_showImaActions(context, current)),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('发送到 ima'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _NotionExportCard(
              item: current,
              manager: exportManager,
              workspace: notionWorkspace,
              externalUri: externalUri,
              onConfigure: onConfigureNotion,
            ),
            if (current.summary case final summary?) ...<Widget>[
              const SizedBox(height: 24),
              _Section(
                title: '摘要',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SelectableText(summary.oneLine),
                    if (summary.keyPoints.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      for (final point in summary.keyPoints)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('• $point'),
                        ),
                    ],
                  ],
                ),
              ),
            ],
            if (current.tags.isNotEmpty ||
                current.topics.isNotEmpty ||
                current.entities.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              _Section(
                title: '标签与主题',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final value in <String>{
                      ...current.tags,
                      ...current.topics,
                      ...current.entities,
                    })
                      Chip(label: Text(value)),
                  ],
                ),
              ),
            ],
            if (current.excerpts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              _Section(
                title: '高亮',
                child: Column(
                  children: <Widget>[
                    for (final excerpt in current.excerpts)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SelectableText('“${excerpt.quote}”'),
                              if (excerpt.note?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(excerpt.note!),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (current.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              _Section(
                title: '笔记',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final note in current.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(note),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _Section(
              title: '正文',
              child: SelectableText(current.markdown),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openOriginal(
    BuildContext context,
    KnowledgeItem current,
  ) async {
    final result = await externalUri.open(current.source.originalUrl);
    if (context.mounted && result != ExternalUriOpenOutcome.opened) {
      _message(context, '无法打开原文，请检查系统浏览器设置');
    }
  }

  Future<void> _exportMarkdown(
    BuildContext context,
    KnowledgeItem current,
  ) async {
    try {
      final bundle = await KnowledgeMarkdownExportBuilder(
        imageFetcher: imageFetcher,
      ).build(<KnowledgeItem>[current]);
      final saved = await files.save(bundle);
      if (context.mounted) {
        _message(context, saved ? 'Markdown 已导出' : '已取消导出');
      }
    } on Object {
      if (context.mounted) _message(context, '导出失败，本地知识内容未受影响');
    }
  }

  Future<void> _showImaActions(
    BuildContext context,
    KnowledgeItem current,
  ) async {
    final interop = imaInterop;
    if (interop == null) return;
    final action = await showModalBottomSheet<_ImaAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ListTile(
              title: Text('发送到 ima'),
              subtitle: Text('仅使用系统分享、标准文件和 ima 公共入口'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('通过系统分享发送文件'),
              subtitle: const Text('选择系统分享面板中的 ima'),
              onTap: () => Navigator.pop(context, _ImaAction.share),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('打开 ima'),
              subtitle: const Text('打开公开入口后手动导入 Markdown/ZIP'),
              onTap: () => Navigator.pop(context, _ImaAction.openPublicEntry),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final result = switch (action) {
      _ImaAction.share => await interop.share(<KnowledgeItem>[current]),
      _ImaAction.openPublicEntry => await interop.openPublicEntry(),
    };
    if (!context.mounted) return;
    final message = switch ((action, result.outcome)) {
      (_, ImaPortableOutcome.dismissed) => '已取消，River 本地知识未受影响',
      (_ImaAction.share, ImaPortableOutcome.completed) =>
        '文件已交给系统分享，请在目标中选择 ima',
      (_ImaAction.openPublicEntry, ImaPortableOutcome.completed) =>
        '已打开 ima，可手动导入 River 文件',
      (_, ImaPortableOutcome.unavailable) => '当前无法使用，请先导出 Markdown 再到 ima 手动导入',
    };
    _message(context, message);
  }
}

enum _ImaAction { share, openPublicEntry }

final class _NotionExportCard extends StatelessWidget {
  const _NotionExportCard({
    required this.item,
    required this.manager,
    required this.workspace,
    required this.externalUri,
    required this.onConfigure,
  });

  final KnowledgeItem item;
  final KnowledgeExportManager? manager;
  final NotionWorkspaceExperience? workspace;
  final ExternalUriGateway externalUri;
  final Future<void> Function()? onConfigure;

  @override
  Widget build(BuildContext context) {
    final experience = workspace;
    if (experience == null || manager == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Notion 自动同步未配置'),
          subtitle: Text('仍可随时导出标准 Markdown，知识内容只保存在本地。'),
        ),
      );
    }
    return StreamBuilder<NotionWorkspaceState>(
      stream: experience.states,
      initialData: experience.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? experience.state;
        final target = state.selectedTarget;
        if (!state.isConnected || target == null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.add_link),
              title: Text(
                state.isConnected ? '请选择 Notion 目标' : '连接 Notion',
              ),
              subtitle: const Text('选择页面或数据源后，可幂等创建并更新同一条知识。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onConfigure,
            ),
          );
        }
        final exportTarget = KnowledgeExportTarget(
          knowledgeItemId: item.id,
          connectorId: 'notion',
          destinationId: target.destinationId,
        );
        return StreamBuilder<KnowledgeExportState>(
          stream: manager!.watch(
            exportTarget,
            KnowledgeExportOperation.upsert,
          ),
          builder: (context, exportSnapshot) {
            final export = exportSnapshot.data;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_exportIcon(export?.phase)),
                      title: Text('Notion · ${target.title}'),
                      subtitle: Text(_exportLabel(export)),
                      trailing: IconButton(
                        onPressed: onConfigure,
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: '更改 Notion 连接或目标',
                      ),
                    ),
                    if (export?.failureCode case final failure?)
                      Text(
                        _failureLabel(failure),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: export?.phase ==
                                      KnowledgeExportPhase.queued ||
                                  export?.phase == KnowledgeExportPhase.running
                              ? null
                              : () => unawaited(
                                    manager!.enqueueUpsert(exportTarget),
                                  ),
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            export?.phase == KnowledgeExportPhase.succeeded
                                ? '更新 Notion'
                                : '保存到 Notion',
                          ),
                        ),
                        if (export?.phase == KnowledgeExportPhase.failed)
                          OutlinedButton.icon(
                            onPressed: () => unawaited(
                              manager!.retry(
                                exportTarget,
                                KnowledgeExportOperation.upsert,
                              ),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                        if (export?.externalUrl case final url?)
                          TextButton.icon(
                            onPressed: () => unawaited(externalUri.open(url)),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('打开 Notion 页面'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

final class NotionWorkspacePage extends StatefulWidget {
  const NotionWorkspacePage({required this.experience, super.key});

  final NotionWorkspaceExperience experience;

  @override
  State<NotionWorkspacePage> createState() => _NotionWorkspacePageState();
}

final class _NotionWorkspacePageState extends State<NotionWorkspacePage> {
  final _completion = TextEditingController();
  final _query = TextEditingController();
  StreamSubscription<NotionWorkspaceState>? _subscription;
  late NotionWorkspaceState _state;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _state = widget.experience.state;
    _listen();
    unawaited(widget.experience.load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _completion.dispose();
    _query.dispose();
    super.dispose();
  }

  void _listen() {
    _subscription = widget.experience.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notion 连接')),
      body: switch (_state.phase) {
        NotionWorkspacePhase.loading =>
          const Center(child: CircularProgressIndicator()),
        NotionWorkspacePhase.disconnected => _disconnected(),
        NotionWorkspacePhase.authorizing => _authorizing(),
        NotionWorkspacePhase.connected => _connected(),
        NotionWorkspacePhase.unavailable => _unavailable(),
      },
    );
  }

  Widget _disconnected() => _CenteredCard(
        icon: Icons.hub_outlined,
        title: '连接你的 Notion 工作区',
        message: 'River 只会访问你授权给集成的页面；OAuth Token 保存在系统安全存储中。',
        action: FilledButton.icon(
          onPressed: _busy ? null : () => unawaited(_begin()),
          icon: const Icon(Icons.open_in_browser),
          label: const Text('开始安全授权'),
        ),
      );

  Widget _authorizing() => ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const ListTile(
            leading: Icon(Icons.open_in_browser),
            title: Text('请在浏览器完成 Notion 授权'),
            subtitle: Text('授权完成后返回 River。若系统未自动唤回，可粘贴完成码或完整回调地址。'),
          ),
          TextField(
            controller: _completion,
            maxLength: 8192,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '完成码或 river:// 回调地址',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _completion.text.trim().isEmpty
                ? null
                : () => unawaited(_complete()),
            child: Text(_busy ? '正在连接' : '完成连接'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => unawaited(_begin()),
            child: const Text('重新开始授权'),
          ),
        ],
      );

  Widget _connected() {
    final authorization = _state.authorization!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(authorization.workspaceName),
          subtitle: const Text('Notion 已连接'),
        ),
        const Divider(),
        Text('保存目标', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SearchBar(
          controller: _query,
          leading: const Icon(Icons.search),
          hintText: '搜索页面或数据源',
          onSubmitted: (value) => unawaited(_refreshTargets(value)),
          trailing: <Widget>[
            IconButton(
              onPressed:
                  _busy ? null : () => unawaited(_refreshTargets(_query.text)),
              icon: const Icon(Icons.refresh),
              tooltip: '刷新目标',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_state.targets.isEmpty)
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('没有可用目标'),
            subtitle: Text('请在 Notion 中把页面或数据源共享给 River 集成，然后刷新。'),
          )
        else
          RadioGroup<String>(
            groupValue: _state.selectedTarget?.destinationId,
            onChanged: _busy
                ? (_) {}
                : (destinationId) {
                    for (final target in _state.targets) {
                      if (target.destinationId == destinationId) {
                        unawaited(widget.experience.selectTarget(target));
                        return;
                      }
                    }
                  },
            child: Column(
              children: <Widget>[
                for (final target in _state.targets)
                  RadioListTile<String>(
                    value: target.destinationId,
                    title: Text(target.title),
                    subtitle: Text(
                      target.kind == NotionTargetKind.page ? '页面' : '数据源',
                    ),
                    secondary: Icon(
                      target.kind == NotionTargetKind.page
                          ? Icons.description_outlined
                          : Icons.table_chart_outlined,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _busy ? null : () => unawaited(_disconnect()),
          child: const Text('断开 Notion（保留本地知识）'),
        ),
      ],
    );
  }

  Widget _unavailable() => _CenteredCard(
        icon: Icons.cloud_off_outlined,
        title: '暂时无法访问 Notion',
        message: '${_failureLabel(_state.failureCode ?? 'unavailable')}。'
            '本地知识不受影响，可以稍后重试。',
        action: FilledButton.icon(
          onPressed: _busy ? null : () => unawaited(_reload()),
          icon: const Icon(Icons.refresh),
          label: const Text('重新检查'),
        ),
        secondary: _state.pendingFlow == null
            ? null
            : TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(
                          () => _state = NotionWorkspaceState(
                            phase: NotionWorkspacePhase.authorizing,
                            pendingFlow: _state.pendingFlow,
                          ),
                        ),
                child: const Text('输入授权完成码'),
              ),
      );

  Future<void> _begin() => _run(widget.experience.beginAuthorization);

  Future<void> _complete() => _run(
        () => widget.experience.completeAuthorization(_completion.text),
      );

  Future<void> _refreshTargets(String query) => _run(
        () => widget.experience.refreshTargets(query: query),
      );

  Future<void> _reload() => _run(widget.experience.load);

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('断开 Notion？'),
            content: const Text('只会撤销连接并清除本机 Token；本地知识和已创建的 Notion 页面不会删除。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('断开连接'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _run(widget.experience.disconnect);
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } on Object {
      if (mounted) _message(context, '操作失败，请检查网络或重新授权');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 10),
          child,
        ],
      );
}

final class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 52),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

final class _CenteredCard extends StatelessWidget {
  const _CenteredCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.secondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 52),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  action,
                  if (secondary case final secondary?) ...<Widget>[
                    const SizedBox(height: 8),
                    secondary,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

List<KnowledgeItem> _filter(List<KnowledgeItem> items, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return items;
  return items.where((item) {
    final haystack = <String>[
      item.title,
      item.source.sourceTitle,
      item.source.author ?? '',
      ...item.tags,
      ...item.topics,
      ...item.entities,
      ...item.notes,
      ...item.excerpts.expand(
        (excerpt) => <String>[excerpt.quote, excerpt.note ?? ''],
      ),
    ].join('\n').toLowerCase();
    return haystack.contains(normalized);
  }).toList(growable: false);
}

String _listSubtitle(KnowledgeItem item) {
  final parts = <String>[
    item.source.sourceTitle,
    if (item.excerpts.isNotEmpty) '${item.excerpts.length} 条高亮',
    if (item.notes.isNotEmpty) '${item.notes.length} 条笔记',
  ];
  return parts.join(' · ');
}

IconData _exportIcon(KnowledgeExportPhase? phase) => switch (phase) {
      KnowledgeExportPhase.queued => Icons.schedule,
      KnowledgeExportPhase.running => Icons.sync,
      KnowledgeExportPhase.succeeded => Icons.cloud_done_outlined,
      KnowledgeExportPhase.failed => Icons.sync_problem_outlined,
      KnowledgeExportPhase.cancelled => Icons.cancel_outlined,
      _ => Icons.cloud_upload_outlined,
    };

String _exportLabel(KnowledgeExportState? state) => switch (state?.phase) {
      KnowledgeExportPhase.queued => '已加入同步队列',
      KnowledgeExportPhase.running => '正在同步',
      KnowledgeExportPhase.succeeded => '已同步，可安全重复更新',
      KnowledgeExportPhase.failed => '同步失败，本地知识不受影响',
      KnowledgeExportPhase.cancelled => '同步已取消',
      _ => '尚未同步',
    };

String _failureLabel(String code) => switch (code) {
      'offline' => '当前离线',
      'timeout' => '请求超时',
      'rateLimited' => 'Notion 请求过多',
      'authenticationRequired' || 'authentication_required' => '需要重新授权',
      'forbidden' => 'Notion 没有访问该目标的权限',
      'notFound' => '目标已不存在',
      'quotaExceeded' => 'Notion 工作区已达到限制',
      'browser_unavailable' => '无法打开系统浏览器',
      'authorization_unavailable' => '安全授权信息不可用',
      _ => 'Notion 服务暂时不可用',
    };

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
