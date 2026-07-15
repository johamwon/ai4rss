import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_design_system/river_design_system.dart';
import 'package:river_feed/river_feed.dart';

import 'app_dependencies.dart';
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

final class _RiverHomeScreenState extends State<RiverHomeScreen> {
  var _busy = false;
  AppDependencies? _dependencies;
  late Stream<List<FeedSubscriptionRecord>> _subscriptions;
  late Stream<List<FeedArticleRecord>> _articles;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = RiverDependenciesScope.of(context);
    if (!identical(dependencies, _dependencies)) {
      _dependencies = dependencies;
      _subscriptions = dependencies.feeds.watchSubscriptions();
      _articles = dependencies.feeds.watchArticles();
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
        await RiverDependenciesScope.of(
          context,
        ).feedRefresh.subscribeOrRefresh(uri);
      },
      successMessage: '订阅源已添加',
    );
  }

  Future<void> _refreshAll(List<FeedSubscriptionRecord> feeds) async {
    await _run(
      () async {
        final service = RiverDependenciesScope.of(context).feedRefresh;
        for (final feed in feeds.where((item) => item.enabled)) {
          await service.subscribeOrRefresh(feed.canonicalUrl);
        }
      },
      successMessage: '刷新完成',
    );
  }

  Future<void> _run(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await operation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleFeedAction(
    FeedSubscriptionRecord feed,
    _FeedAction action,
  ) async {
    final service = RiverDependenciesScope.of(context).feedRefresh;
    switch (action) {
      case _FeedAction.toggle:
        await service.setEnabled(feed.id, enabled: !feed.enabled);
      case _FeedAction.delete:
        await service.delete(feed.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FeedSubscriptionRecord>>(
      stream: _subscriptions,
      builder: (context, subscriptionSnapshot) {
        final subscriptions =
            subscriptionSnapshot.data ?? const <FeedSubscriptionRecord>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('River'),
            actions: <Widget>[
              IconButton(
                onPressed: _busy || subscriptions.isEmpty
                    ? null
                    : () => unawaited(_refreshAll(subscriptions)),
                icon: const Icon(Icons.refresh),
                tooltip: '刷新全部',
              ),
              IconButton(
                onPressed: _busy ? null : () => unawaited(_addFeed()),
                icon: const Icon(Icons.add),
                tooltip: '添加订阅源',
              ),
            ],
          ),
          body: _busy && subscriptions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _Inbox(
                  subscriptions: subscriptions,
                  articles: _articles,
                  onFeedAction: (feed, action) =>
                      unawaited(_handleFeedAction(feed, action)),
                ),
        );
      },
    );
  }
}

enum _FeedAction { toggle, delete }

final class _Inbox extends StatelessWidget {
  const _Inbox({
    required this.subscriptions,
    required this.articles,
    required this.onFeedAction,
  });

  final List<FeedSubscriptionRecord> subscriptions;
  final Stream<List<FeedArticleRecord>> articles;
  final void Function(FeedSubscriptionRecord, _FeedAction) onFeedAction;

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return const _EmptyInbox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 80,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final feed = subscriptions[index];
              return InputChip(
                avatar: Icon(
                  feed.enabled ? Icons.rss_feed : Icons.pause_circle_outline,
                  size: 18,
                ),
                label: Text(feed.title),
                onPressed: () => onFeedAction(feed, _FeedAction.toggle),
                onDeleted: () => onFeedAction(feed, _FeedAction.delete),
                deleteButtonTooltipMessage: '删除 ${feed.title}',
                tooltip: feed.enabled ? '暂停 ${feed.title}' : '恢复 ${feed.title}',
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: subscriptions.length,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<FeedArticleRecord>>(
            stream: articles,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <FeedArticleRecord>[];
              if (items.isEmpty) {
                return const Center(child: Text('订阅源中还没有文章'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) => _ArticleTile(items[index]),
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 72),
                itemCount: items.length,
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _ArticleTile extends StatelessWidget {
  const _ArticleTile(this.article);

  final FeedArticleRecord article;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(article.read ? Icons.done : Icons.article_outlined),
      ),
      title: Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: article.summary == null
          ? null
          : Text(
              article.summary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: article.starred ? const Icon(Icons.star) : null,
    );
  }
}

final class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        container: true,
        label: '还没有订阅源，请添加一个 RSS 地址',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.rss_feed, size: 48),
            SizedBox(height: 16),
            Text('还没有订阅源'),
            SizedBox(height: 8),
            Text('点击右上角 +，粘贴 RSS、Atom 或 JSON Feed 地址'),
          ],
        ),
      ),
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
