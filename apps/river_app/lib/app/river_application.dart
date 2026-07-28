import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:river_data/river_data.dart';
import 'package:river_design_system/river_design_system.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

import '../podcast/podcast_library_page.dart';
import '../sync/sync_account_page.dart';
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
        highContrastDarkTheme: RiverTheme.highContrastDark(),
        highContrastTheme: RiverTheme.highContrastLight(),
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
  StreamSubscription<NetworkAvailability>? _networkStates;
  FeedRefreshBatchState _refreshState = const FeedRefreshBatchState.idle();
  NetworkAvailability _networkAvailability = NetworkAvailability.unknown;
  Uri? _pendingFeedUri;
  List<FeedSubscriptionRecord>? _pendingRefreshFeeds;
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
      unawaited(_networkStates?.cancel());
      _dependencies = dependencies;
      _refreshState = dependencies.feedRefreshCoordinator.state;
      _refreshStates = dependencies.feedRefreshCoordinator.states.listen(
        (state) {
          if (mounted) setState(() => _refreshState = state);
        },
      );
      _subscriptions = dependencies.feeds.watchSubscriptions();
      _folders = dependencies.subscriptionOrganizer.watchFolders();
      _networkStates = dependencies.network.changes.listen(
        _acceptNetworkAvailability,
        onError: (_) => _acceptNetworkAvailability(NetworkAvailability.unknown),
      );
      unawaited(_checkNetworkAvailability());
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
      unawaited(dependencies.offlineArticles.resumePending());
      unawaited(dependencies.podcastDownloads.start());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final dependencies = _dependencies;
    if (state == AppLifecycleState.resumed && dependencies != null) {
      unawaited(_checkNetworkAvailability());
      unawaited(dependencies.offlineArticles.resumePending());
      unawaited(dependencies.podcastDownloads.resumePending());
      if (dependencies.automaticRefreshEnabled) {
        unawaited(_runAutomaticRefresh());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_refreshStates?.cancel());
    unawaited(_networkStates?.cancel());
    _articleListController?.dispose();
    super.dispose();
  }

  Future<void> _runAutomaticRefresh() async {
    try {
      if (!await _mayAttemptNetwork()) return;
      await _automaticRefresh?.run();
    } catch (_) {
      // Automatic refresh is best-effort; the visible manual action remains
      // the recovery path and reports failures to the reader.
    }
  }

  Future<void> _checkNetworkAvailability() async {
    final dependencies = _dependencies;
    if (dependencies == null) return;
    final availability = await dependencies.network.check();
    if (mounted && identical(dependencies, _dependencies)) {
      _acceptNetworkAvailability(availability);
    }
  }

  void _acceptNetworkAvailability(NetworkAvailability availability) {
    if (!mounted || availability == _networkAvailability) return;
    final previous = _networkAvailability;
    setState(() => _networkAvailability = availability);
    if (availability.mayAttemptRequest) {
      unawaited(_dependencies?.offlineArticles.resumePending());
    }
    if (previous.isOffline && availability == NetworkAvailability.online) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _offerPendingNetworkRetry();
        final dependencies = _dependencies;
        if (_pendingRefreshFeeds == null &&
            dependencies?.automaticRefreshEnabled == true) {
          unawaited(_runAutomaticRefresh());
        }
      });
    }
  }

  Future<bool> _mayAttemptNetwork() async {
    final dependencies = _dependencies;
    if (dependencies == null) return false;
    final availability = await dependencies.network.check();
    if (mounted) _acceptNetworkAvailability(availability);
    return availability.mayAttemptRequest;
  }

  void _offerPendingNetworkRetry() {
    if (_pendingFeedUri != null) {
      _showMessage(
        '网络已恢复，可以继续添加订阅源',
        actionLabel: '重试添加',
        onAction: () => unawaited(_retryPendingFeed()),
      );
      return;
    }
    if (_pendingRefreshFeeds != null) {
      _showMessage(
        '网络已恢复，可以继续刷新订阅源',
        actionLabel: '重试刷新',
        onAction: () => unawaited(_retryPendingRefresh()),
      );
    }
  }

  Future<void> _retryPendingFeed() async {
    final uri = _pendingFeedUri;
    if (uri != null) await _addFeed(uri: uri);
  }

  Future<void> _retryPendingRefresh() async {
    final feeds = _pendingRefreshFeeds;
    if (feeds != null) await _refreshAll(feeds);
  }

  Future<void> _addFeed({Uri? uri}) async {
    uri ??= await showDialog<Uri>(
      context: context,
      builder: (context) => const _AddFeedDialog(),
    );
    if (uri == null || !mounted) {
      return;
    }
    if (!await _mayAttemptNetwork()) {
      setState(() => _pendingFeedUri = uri);
      if (mounted) {
        _showMessage('当前离线，地址已保留；联网后可以直接重试');
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final discovery = RiverDependenciesScope.of(context).feedDiscovery;
      final candidates = await discovery.discover(uri);
      if (!mounted) return;
      FeedDiscoveryCandidate? selected;
      if (candidates.length == 1) {
        selected = candidates.single;
      } else {
        setState(() => _busy = false);
        selected = await showDialog<FeedDiscoveryCandidate>(
          context: context,
          builder: (context) => _FeedCandidateDialog(
            candidates: candidates,
          ),
        );
        if (selected != null && mounted) setState(() => _busy = true);
      }
      if (selected == null) return;
      await discovery.subscribe(selected);
      _pendingFeedUri = null;
      if (mounted) _showMessage('订阅源已添加');
    } on FeedDiscoveryException catch (error) {
      if (!mounted) return;
      switch (error.failure) {
        case FeedDiscoveryFailure.invalidAddress:
        case FeedDiscoveryFailure.notFound:
          _showMessage(error.message);
          break;
        case FeedDiscoveryFailure.unavailable:
          setState(() => _pendingFeedUri = uri);
          _showMessage(
            '暂时无法连接，地址已保留',
            actionLabel: '重试',
            onAction: () => unawaited(_retryPendingFeed()),
          );
          break;
      }
    } on Object {
      if (mounted) {
        setState(() => _pendingFeedUri = uri);
        _showMessage(
          '添加订阅源失败，请稍后重试',
          actionLabel: '重试',
          onAction: () => unawaited(_retryPendingFeed()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshAll(List<FeedSubscriptionRecord> feeds) async {
    if (!await _mayAttemptNetwork()) {
      setState(
        () => _pendingRefreshFeeds =
            List<FeedSubscriptionRecord>.unmodifiable(feeds),
      );
      if (mounted) {
        _showMessage('当前离线，刷新任务已保留；联网后可以重试');
      }
      return;
    }
    try {
      _pendingRefreshFeeds = null;
      final result = await RiverDependenciesScope.of(context)
          .feedRefreshCoordinator
          .start(feeds);
      if (!mounted) return;
      if (result.phase == FeedRefreshBatchPhase.cancelled) {
        _showMessage('刷新已取消：完成 ${result.succeeded}/${result.total}');
      } else if (result.failed > 0) {
        _pendingRefreshFeeds = List<FeedSubscriptionRecord>.unmodifiable(feeds);
        _showMessage(
          '刷新完成：成功 ${result.succeeded}，失败 ${result.failed}',
          actionLabel: '重试',
          onAction: () => unawaited(_retryPendingRefresh()),
        );
      } else {
        _showMessage('刷新完成：${result.succeeded} 个来源');
      }
    } on Object {
      _pendingRefreshFeeds = List<FeedSubscriptionRecord>.unmodifiable(feeds);
      if (mounted) {
        _showMessage(
          '刷新失败，请稍后重试',
          actionLabel: '重试',
          onAction: () => unawaited(_retryPendingRefresh()),
        );
      }
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
          externalUri: dependencies.externalUri,
          offlineArticles: dependencies.offlineArticles,
          clock: dependencies.clock,
          audioController: dependencies.audioController,
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

  Future<void> _openSyncAccount() async {
    final experience = RiverDependenciesScope.of(context).syncAccount;
    if (experience == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SyncAccountPage(experience: experience),
      ),
    );
  }

  Future<void> _openPodcasts() async {
    final dependencies = RiverDependenciesScope.of(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PodcastLibraryPage(
          repository: dependencies.podcasts,
          refresh: dependencies.podcastRefresh,
          policies: dependencies.podcastPolicies,
          downloads: dependencies.podcastDownloads,
          audio: dependencies.audioController,
          clock: dependencies.clock,
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
    } on Object {
      if (mounted) {
        _showMessage('操作失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
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
          return FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(
                  LogicalKeyboardKey.keyF,
                  control: true,
                ): () => unawaited(_openSearch(subscriptions, folders)),
                const SingleActivator(
                  LogicalKeyboardKey.keyN,
                  control: true,
                ): () {
                  if (!_busy) unawaited(_addFeed());
                },
                const SingleActivator(
                  LogicalKeyboardKey.keyR,
                  control: true,
                ): () {
                  if (!_busy && !refreshing && subscriptions.isNotEmpty) {
                    unawaited(_refreshAll(subscriptions));
                  }
                },
              },
              child: Focus(
                autofocus: true,
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('River'),
                    actions: <Widget>[
                      IconButton(
                        onPressed: () => unawaited(_openPodcasts()),
                        icon: const Icon(Icons.podcasts_outlined),
                        tooltip: '播客',
                      ),
                      if (_dependencies?.syncAccount != null)
                        IconButton(
                          onPressed: () => unawaited(_openSyncAccount()),
                          icon: const Icon(Icons.cloud_sync_outlined),
                          tooltip: '同步与账号',
                        ),
                      IconButton(
                        onPressed: () => unawaited(
                          _openSearch(subscriptions, folders),
                        ),
                        icon: const Icon(Icons.search),
                        tooltip: '搜索文章',
                      ),
                      IconButton(
                        onPressed: refreshing
                            ? _refreshState.phase ==
                                    FeedRefreshBatchPhase.running
                                ? () => unawaited(_cancelRefresh())
                                : null
                            : _busy || subscriptions.isEmpty
                                ? null
                                : () => unawaited(_refreshAll(subscriptions)),
                        icon: Icon(
                          refreshing
                              ? Icons.stop_circle_outlined
                              : Icons.refresh,
                        ),
                        tooltip: refreshing
                            ? _refreshState.phase ==
                                    FeedRefreshBatchPhase.cancelling
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
                            if (_networkAvailability.isOffline)
                              _OfflineStatusBar(
                                hasPendingFeed: _pendingFeedUri != null,
                                hasPendingRefresh: _pendingRefreshFeeds != null,
                              ),
                            if (refreshing)
                              _RefreshStatusBar(state: _refreshState),
                            Expanded(
                              child: _Inbox(
                                subscriptions: subscriptions,
                                folders: folders,
                                articleListController: _articleListController!,
                                onFeedAction: (feed, action) => unawaited(
                                  _handleFeedAction(feed, action, folders),
                                ),
                                onFolderAction: (folder, action) => unawaited(
                                  _handleFolderAction(folder, action),
                                ),
                                onOpenArticle: (article) =>
                                    unawaited(_openArticle(article)),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
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

final class _OfflineStatusBar extends StatelessWidget {
  const _OfflineStatusBar({
    required this.hasPendingFeed,
    required this.hasPendingRefresh,
  });

  final bool hasPendingFeed;
  final bool hasPendingRefresh;

  @override
  Widget build(BuildContext context) {
    final pending = switch ((hasPendingFeed, hasPendingRefresh)) {
      (true, true) => '；添加与刷新操作已保留',
      (true, false) => '；添加地址已保留',
      (false, true) => '；刷新任务已保留',
      (false, false) => '',
    };
    final label = '当前离线，仍可阅读已保存内容$pending';
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
