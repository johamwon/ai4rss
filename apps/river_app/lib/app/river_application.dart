import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_data/river_data.dart';
import 'package:river_design_system/river_design_system.dart';
import 'package:river_feed/river_feed.dart';

import 'app_dependencies.dart';
import 'article_list.dart';
import 'article_reader.dart';
import 'article_search.dart';
import 'automatic_feed_refresh_controller.dart';
import 'dependency_scope.dart';

final class RiverApp extends StatelessWidget {
  const RiverApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return RiverDependenciesScope(
      dependencies: dependencies,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        darkTheme: RiverTheme.dark(),
        home: const RiverHomeScreen(),
        theme: RiverTheme.light(),
        title: 'River',
      ),
    );
  }
}

final class RiverHomeScreen extends StatefulWidget {
  const RiverHomeScreen({super.key});

  @override
  State<RiverHomeScreen> createState() => _RiverHomeScreenState();
}

final class _RiverHomeScreenState extends State<RiverHomeScreen>
    with WidgetsBindingObserver {
  var _busy = false;
  AppDependencies? _dependencies;
  AutomaticFeedRefreshController? _automaticRefresh;
  StreamSubscription<FeedRefreshBatchState>? _refreshStates;
  FeedRefreshBatchState _refreshState = const FeedRefreshBatchState.idle();
  late Stream<List<FeedSubscriptionRecord>> _subscriptions;
  late Stream<List<FeedFolderRecord>> _folders;
  ArticleListController? _articleListController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = RiverDependenciesScope.of(context);
    if (!identical(dependencies, _dependencies)) {
      unawaited(_refreshStates?.cancel());
      _dependencies = dependencies;
      _refreshState = dependencies.feedRefreshCoordinator.state;
      _refreshStates = dependencies.feedRefreshCoordinator.states.listen(
        (state) {
          if (mounted) setState(() => _refreshState = state);
        },
      );
      _subscriptions = dependencies.feeds.watchSubscriptions();
      _folders = dependencies.subscriptionOrganizer.watchFolders();
      _articleListController?.dispose();
      _articleListController = ArticleListController(
        load: (query) => dependencies.feeds.watchArticles(query: query),
      );
      _automaticRefresh = AutomaticFeedRefreshController(
        clock: dependencies.clock,
        currentState: () => dependencies.feedRefreshCoordinator.state,
        resumePending: dependencies.feedRefreshCoordinator.resumePending,
        loadSubscriptions: () => dependencies.feeds.watchSubscriptions().first,
        start: dependencies.feedRefreshCoordinator.start,
      );
      if (dependencies.automaticRefreshEnabled) {
        unawaited(_runAutomaticRefresh());
      } else {
        unawaited(dependencies.feedRefreshCoordinator.resumePending());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final dependencies = _dependencies;
    if (state == AppLifecycleState.resumed && dependencies != null) {
      if (dependencies.automaticRefreshEnabled) {
        unawaited(_runAutomaticRefresh());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_refreshStates?.cancel());
    _articleListController?.dispose();
    super.dispose();
  }

  Future<void> _runAutomaticRefresh() async {
    try {
      await _automaticRefresh?.run();
    } catch (_) {
      // Automatic refresh is best-effort; the visible manual action remains
      // the recovery path and reports failures to the reader.
    }
  }

  Future<void> _addFeed() async {
    final uri = await showDialog<Uri>(
      context: context,
      builder: (context) => const _AddFeedDialog(),
    );
    if (uri == null || !mounted) {
      return;
    }
    await _run(
      () async {
        final discovery = RiverDependenciesScope.of(context).feedDiscovery;
        final candidates = await discovery.discover(uri);
        if (!mounted) {
          return null;
        }
        final selected = candidates.length == 1
            ? candidates.single
            : await showDialog<FeedDiscoveryCandidate>(
                context: context,
                builder: (context) => _FeedCandidateDialog(
                  candidates: candidates,
                ),
              );
        if (selected == null) {
          return null;
        }
        await discovery.subscribe(selected);
        return '订阅源已添加';
      },
    );
  }

  Future<void> _refreshAll(List<FeedSubscriptionRecord> feeds) async {
    try {
      final result = await RiverDependenciesScope.of(context)
          .feedRefreshCoordinator
          .start(feeds);
      if (!mounted) return;
      if (result.phase == FeedRefreshBatchPhase.cancelled) {
        _showMessage('刷新已取消：完成 ${result.succeeded}/${result.total}');
      } else if (result.failed > 0) {
        _showMessage(
          '刷新完成：成功 ${result.succeeded}，失败 ${result.failed}',
        );
      } else {
        _showMessage('刷新完成：${result.succeeded} 个来源');
      }
    } catch (error) {
      if (mounted) _showMessage('操作失败：$error');
    }
  }

  Future<void> _cancelRefresh() async {
    await RiverDependenciesScope.of(context).feedRefreshCoordinator.cancel();
  }

  Future<void> _openArticle(FeedArticleRecord article) async {
    final dependencies = RiverDependenciesScope.of(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ArticleReaderPage(
          articleId: article.id,
          repository: dependencies.feeds,
          extractor: dependencies.fullTextExtractor,
          readerSettings: dependencies.readerSettings,
          share: dependencies.share,
          clock: dependencies.clock,
        ),
      ),
    );
  }

  Future<void> _openSearch(
    List<FeedSubscriptionRecord> subscriptions,
    List<FeedFolderRecord> folders,
  ) async {
    final dependencies = RiverDependenciesScope.of(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ArticleSearchPage(
          load: dependencies.feeds.watchSearch,
          folders: folders,
          subscriptions: subscriptions,
          onOpenArticle: (article) => unawaited(_openArticle(article)),
        ),
      ),
    );
  }

  Future<void> _run(Future<String?> Function() operation) async {
    setState(() => _busy = true);
    try {
      final successMessage = await operation();
      if (successMessage != null && mounted) {
        _showMessage(successMessage);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('操作失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleFeedAction(
    FeedSubscriptionRecord feed,
    _FeedAction action,
    List<FeedFolderRecord> folders,
  ) async {
    final dependencies = RiverDependenciesScope.of(context);
    switch (action) {
      case _FeedAction.toggle:
        await _run(() async {
          await dependencies.feedRefresh.setEnabled(
            feed.id,
            enabled: !feed.enabled,
          );
          return feed.enabled ? '订阅源已暂停' : '订阅源已恢复';
        });
      case _FeedAction.move:
        final selection = await showDialog<_FolderSelection>(
          context: context,
          builder: (context) => _MoveFeedDialog(folders: folders),
        );
        if (selection == null || !mounted) {
          return;
        }
        await _run(() async {
          await dependencies.subscriptionOrganizer.moveFeed(
            feed.id,
            selection.folderId,
          );
          return '订阅源已移动';
        });
      case _FeedAction.delete:
        if (!await _confirm('删除订阅源', '确认删除“${feed.title}”及其文章吗？') || !mounted) {
          return;
        }
        await _run(() async {
          await dependencies.feedRefresh.delete(feed.id);
          return '订阅源已删除';
        });
    }
  }

  Future<void> _handleFolderAction(
    FeedFolderRecord folder,
    _FolderAction action,
  ) async {
    final organizer = RiverDependenciesScope.of(context).subscriptionOrganizer;
    switch (action) {
      case _FolderAction.rename:
        final name = await showDialog<String>(
          context: context,
          builder: (context) => _FolderNameDialog(initialName: folder.name),
        );
        if (name == null || !mounted) {
          return;
        }
        await _run(() async {
          await organizer.renameFolder(folder.id, name);
          return '文件夹已改名';
        });
      case _FolderAction.delete:
        if (!await _confirm(
              '删除文件夹',
              '确认删除“${folder.displayPath}”吗？其中的订阅会移到未分类。',
            ) ||
            !mounted) {
          return;
        }
        await _run(() async {
          await organizer.deleteFolder(folder.id);
          return '文件夹已删除，订阅已移到未分类';
        });
    }
  }

  Future<void> _handleSubscriptionAction(_SubscriptionAction action) async {
    final dependencies = RiverDependenciesScope.of(context);
    switch (action) {
      case _SubscriptionAction.createFolder:
        final name = await showDialog<String>(
          context: context,
          builder: (context) => const _FolderNameDialog(),
        );
        if (name == null || !mounted) {
          return;
        }
        await _run(() async {
          await dependencies.subscriptionOrganizer.createFolder(name);
          return '文件夹已创建';
        });
      case _SubscriptionAction.importOpml:
        final source = await dependencies.opmlFiles.pickImport();
        if (source == null || !mounted) {
          return;
        }
        await _run(() async {
          final report =
              await dependencies.subscriptionOrganizer.import(source);
          return '已导入 ${report.importedSubscriptions} 个来源，'
              '新建 ${report.createdFolders} 个文件夹，'
              '跳过 ${report.skippedDuplicates} 个重复项和 '
              '${report.skippedInvalid} 个无效项';
        });
      case _SubscriptionAction.exportOpml:
        await _run(() async {
          final contents = await dependencies.subscriptionOrganizer.export();
          final saved = await dependencies.opmlFiles.saveExport(contents);
          return saved ? 'OPML 已导出' : null;
        });
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FeedFolderRecord>>(
      stream: _folders,
      builder: (context, folderSnapshot) =>
          StreamBuilder<List<FeedSubscriptionRecord>>(
        stream: _subscriptions,
        builder: (context, subscriptionSnapshot) {
          final folders = folderSnapshot.data ?? const <FeedFolderRecord>[];
          final subscriptions =
              subscriptionSnapshot.data ?? const <FeedSubscriptionRecord>[];
          final refreshing = _refreshState.isActive;
          return Scaffold(
            appBar: AppBar(
              title: const Text('River'),
              actions: <Widget>[
                IconButton(
                  onPressed: () => unawaited(
                    _openSearch(subscriptions, folders),
                  ),
                  icon: const Icon(Icons.search),
                  tooltip: '搜索文章',
                ),
                IconButton(
                  onPressed: refreshing
                      ? _refreshState.phase == FeedRefreshBatchPhase.running
                          ? () => unawaited(_cancelRefresh())
                          : null
                      : _busy || subscriptions.isEmpty
                          ? null
                          : () => unawaited(_refreshAll(subscriptions)),
                  icon: Icon(
                    refreshing ? Icons.stop_circle_outlined : Icons.refresh,
                  ),
                  tooltip: refreshing
                      ? _refreshState.phase == FeedRefreshBatchPhase.cancelling
                          ? '正在取消刷新'
                          : '取消刷新'
                      : '刷新全部',
                ),
                IconButton(
                  onPressed: _busy ? null : () => unawaited(_addFeed()),
                  icon: const Icon(Icons.add),
                  tooltip: '添加订阅源',
                ),
                PopupMenuButton<_SubscriptionAction>(
                  enabled: !_busy,
                  onSelected: (action) =>
                      unawaited(_handleSubscriptionAction(action)),
                  itemBuilder: (context) =>
                      const <PopupMenuEntry<_SubscriptionAction>>[
                    PopupMenuItem<_SubscriptionAction>(
                      value: _SubscriptionAction.createFolder,
                      child: Text('新建文件夹'),
                    ),
                    PopupMenuItem<_SubscriptionAction>(
                      value: _SubscriptionAction.importOpml,
                      child: Text('导入 OPML'),
                    ),
                    PopupMenuItem<_SubscriptionAction>(
                      value: _SubscriptionAction.exportOpml,
                      child: Text('导出 OPML'),
                    ),
                  ],
                  tooltip: '订阅与 OPML',
                ),
              ],
            ),
            body: _busy && subscriptions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: <Widget>[
                      if (refreshing) _RefreshStatusBar(state: _refreshState),
                      Expanded(
                        child: _Inbox(
                          subscriptions: subscriptions,
                          folders: folders,
                          articleListController: _articleListController!,
                          onFeedAction: (feed, action) => unawaited(
                            _handleFeedAction(feed, action, folders),
                          ),
                          onFolderAction: (folder, action) =>
                              unawaited(_handleFolderAction(folder, action)),
                          onOpenArticle: (article) =>
                              unawaited(_openArticle(article)),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

enum _FeedAction { toggle, move, delete }

enum _FolderAction { rename, delete }

enum _SubscriptionAction { createFolder, importOpml, exportOpml }

final class _RefreshStatusBar extends StatelessWidget {
  const _RefreshStatusBar({required this.state});

  final FeedRefreshBatchState state;

  @override
  Widget build(BuildContext context) {
    final label = state.phase == FeedRefreshBatchPhase.cancelling
        ? '正在停止刷新，已开始的请求会安全结束'
        : '正在刷新 ${state.settled}/${state.total} 个来源';
    return Semantics(
      label: label,
      value: '${state.settled}/${state.total}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: state.progress),
          ],
        ),
      ),
    );
  }
}

final class _Inbox extends StatelessWidget {
  const _Inbox({
    required this.subscriptions,
    required this.folders,
    required this.articleListController,
    required this.onFeedAction,
    required this.onFolderAction,
    required this.onOpenArticle,
  });

  final List<FeedSubscriptionRecord> subscriptions;
  final List<FeedFolderRecord> folders;
  final ArticleListController articleListController;
  final void Function(FeedSubscriptionRecord, _FeedAction) onFeedAction;
  final void Function(FeedFolderRecord, _FolderAction) onFolderAction;
  final ValueChanged<FeedArticleRecord> onOpenArticle;

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty && folders.isEmpty) {
      return const _EmptyInbox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubscriptionPanel(
          subscriptions: subscriptions,
          folders: folders,
          onFeedAction: onFeedAction,
          onFolderAction: onFolderAction,
        ),
        const Divider(height: 1),
        Expanded(
          child: ArticleListPane(
            controller: articleListController,
            folders: folders,
            onOpenArticle: onOpenArticle,
          ),
        ),
      ],
    );
  }
}

final class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({
    required this.subscriptions,
    required this.folders,
    required this.onFeedAction,
    required this.onFolderAction,
  });

  final List<FeedSubscriptionRecord> subscriptions;
  final List<FeedFolderRecord> folders;
  final void Function(FeedSubscriptionRecord, _FeedAction) onFeedAction;
  final void Function(FeedFolderRecord, _FolderAction) onFolderAction;

  @override
  Widget build(BuildContext context) {
    final ungrouped = subscriptions
        .where((feed) => feed.folderId == null)
        .toList(growable: false);
    final groups = <_FeedGroup>[
      if (ungrouped.isNotEmpty) _FeedGroup(label: '未分类', feeds: ungrouped),
      ...folders.map(
        (folder) => _FeedGroup(
          label: folder.displayPath,
          folder: folder,
          feeds: subscriptions
              .where((feed) => feed.folderId == folder.id)
              .toList(growable: false),
        ),
      ),
    ];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.42;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight.clamp(160, 360)),
      child: ListView(
        shrinkWrap: true,
        children: groups
            .map(
              (group) => ExpansionTile(
                key: PageStorageKey<String>(group.folder?.id ?? 'ungrouped'),
                initiallyExpanded: true,
                leading: Icon(
                  group.folder == null ? Icons.inbox_outlined : Icons.folder,
                ),
                title: Row(
                  children: <Widget>[
                    Expanded(child: Text(group.label)),
                    Text('${group.feeds.length}'),
                    if (group.folder case final folder?)
                      PopupMenuButton<_FolderAction>(
                        onSelected: (action) => onFolderAction(folder, action),
                        itemBuilder: (context) =>
                            const <PopupMenuEntry<_FolderAction>>[
                          PopupMenuItem<_FolderAction>(
                            value: _FolderAction.rename,
                            child: Text('重命名'),
                          ),
                          PopupMenuItem<_FolderAction>(
                            value: _FolderAction.delete,
                            child: Text('删除文件夹'),
                          ),
                        ],
                        tooltip: '管理 ${folder.displayPath}',
                      ),
                  ],
                ),
                children: group.feeds.isEmpty
                    ? const <Widget>[
                        ListTile(
                          dense: true,
                          title: Text('文件夹为空'),
                        ),
                      ]
                    : group.feeds
                        .map(
                          (feed) => ListTile(
                            dense: true,
                            leading: Icon(
                              feed.enabled
                                  ? Icons.rss_feed
                                  : Icons.pause_circle_outline,
                            ),
                            title: Text(feed.title),
                            subtitle: Text(feed.canonicalUrl.host),
                            trailing: PopupMenuButton<_FeedAction>(
                              onSelected: (action) =>
                                  onFeedAction(feed, action),
                              itemBuilder: (context) =>
                                  <PopupMenuEntry<_FeedAction>>[
                                PopupMenuItem<_FeedAction>(
                                  value: _FeedAction.toggle,
                                  child: Text(feed.enabled ? '暂停' : '恢复'),
                                ),
                                const PopupMenuItem<_FeedAction>(
                                  value: _FeedAction.move,
                                  child: Text('移动到文件夹'),
                                ),
                                const PopupMenuItem<_FeedAction>(
                                  value: _FeedAction.delete,
                                  child: Text('删除订阅源'),
                                ),
                              ],
                              tooltip: '管理 ${feed.title}',
                            ),
                          ),
                        )
                        .toList(growable: false),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

final class _FeedGroup {
  const _FeedGroup({required this.label, required this.feeds, this.folder});

  final String label;
  final FeedFolderRecord? folder;
  final List<FeedSubscriptionRecord> feeds;
}

final class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        container: true,
        label: '还没有订阅源，请添加网站或 Feed 地址',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.rss_feed, size: 48),
            SizedBox(height: 16),
            Text('还没有订阅源'),
            SizedBox(height: 8),
            Text('点击右上角 +，粘贴网站或 Feed 地址'),
          ],
        ),
      ),
    );
  }
}

final class _FeedCandidateDialog extends StatelessWidget {
  const _FeedCandidateDialog({required this.candidates});

  final List<FeedDiscoveryCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('选择订阅源'),
      children: candidates
          .map(
            (candidate) => SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(candidate),
              child: Semantics(
                button: true,
                label: '订阅 ${candidate.title}，${_kindLabel(candidate.kind)}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      candidate.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_kindLabel(candidate.kind)} · ${candidate.uri.host}'
                      '${_latestLabel(candidate.latestUpdatedAt)}',
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

String _kindLabel(FeedDocumentKind kind) => switch (kind) {
      FeedDocumentKind.rss => 'RSS',
      FeedDocumentKind.atom => 'Atom',
      FeedDocumentKind.jsonFeed => 'JSON Feed',
      FeedDocumentKind.unknown => 'Feed',
    };

String _latestLabel(DateTime? date) {
  if (date == null) {
    return '';
  }
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return ' · 最近更新 ${local.year}-$month-$day';
}

final class _FolderSelection {
  const _FolderSelection(this.folderId);

  final String? folderId;
}

final class _MoveFeedDialog extends StatelessWidget {
  const _MoveFeedDialog({required this.folders});

  final List<FeedFolderRecord> folders;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('移动到文件夹'),
      children: <Widget>[
        SimpleDialogOption(
          onPressed: () =>
              Navigator.of(context).pop(const _FolderSelection(null)),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.inbox_outlined),
            title: Text('未分类'),
          ),
        ),
        ...folders.map(
          (folder) => SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_FolderSelection(folder.id)),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder),
              title: Text(folder.displayPath),
            ),
          ),
        ),
      ],
    );
  }
}

final class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({this.initialName});

  final String? initialName;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

final class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '文件夹名称不能为空');
      return;
    }
    if (name.length > 128) {
      setState(() => _error = '文件夹名称不能超过 128 个字符');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? '新建文件夹' : '重命名文件夹'),
      content: TextField(
        autofocus: true,
        controller: _controller,
        decoration: InputDecoration(errorText: _error, labelText: '文件夹名称'),
        maxLength: 128,
        onSubmitted: (value) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

final class _AddFeedDialog extends StatefulWidget {
  const _AddFeedDialog();

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

final class _AddFeedDialogState extends State<_AddFeedDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = Uri.tryParse(_controller.text.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _error = '请输入有效的 HTTP(S) 地址');
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加订阅源'),
      content: TextField(
        autofocus: true,
        controller: _controller,
        decoration: InputDecoration(
          errorText: _error,
          hintText: 'https://example.com/feed.xml',
          labelText: 'Feed 或网站地址',
        ),
        keyboardType: TextInputType.url,
        onSubmitted: (value) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}
