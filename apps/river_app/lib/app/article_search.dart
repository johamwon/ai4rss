import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_feed/river_feed.dart';

typedef ArticleSearchLoader = Stream<List<ArticleSearchResult>> Function(
  ArticleSearchQuery query,
);

final class ArticleSearchPage extends StatefulWidget {
  const ArticleSearchPage({
    required this.load,
    required this.folders,
    required this.subscriptions,
    required this.onOpenArticle,
    this.debounce = const Duration(milliseconds: 300),
    super.key,
  });

  final ArticleSearchLoader load;
  final List<FeedFolderRecord> folders;
  final List<FeedSubscriptionRecord> subscriptions;
  final ValueChanged<FeedArticleRecord> onOpenArticle;
  final Duration debounce;

  @override
  State<ArticleSearchPage> createState() => _ArticleSearchPageState();
}

final class _ArticleSearchPageState extends State<ArticleSearchPage> {
  final _textController = TextEditingController();
  ArticleSearchQuery _query = const ArticleSearchQuery(text: '');
  Timer? _debounce;
  var _retryGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () {
      if (mounted) setState(() => _query = _query.copyWith(text: text));
    });
  }

  void _clear() {
    _debounce?.cancel();
    _textController.clear();
    setState(() => _query = _query.copyWith(text: ''));
  }

  void _show(FeedArticleView view) {
    setState(() {
      _query = ArticleSearchQuery(
        text: _query.text,
        view: view,
        sort: _query.sort,
        feedId: _query.feedId,
      );
    });
  }

  void _showFolder(String folderId) {
    setState(() {
      _query = ArticleSearchQuery(
        text: _query.text,
        view: FeedArticleView.folder,
        sort: _query.sort,
        feedId: _query.feedId,
        folderId: folderId,
      );
    });
  }

  void _setFeed(String? feedId) {
    setState(() {
      _query = _query.copyWith(
        feedId: feedId,
        clearFeedId: feedId == null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Semantics(
          textField: true,
          label: '搜索标题、作者、来源、正文、摘要、标签和笔记',
          child: TextField(
            autofocus: true,
            controller: _textController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '搜索文章与知识库内容',
            ),
            onChanged: _scheduleSearch,
            onSubmitted: (text) {
              _debounce?.cancel();
              setState(() => _query = _query.copyWith(text: text));
            },
            textInputAction: TextInputAction.search,
          ),
        ),
        actions: <Widget>[
          if (_textController.text.isNotEmpty)
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.clear),
              tooltip: '清除搜索',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SearchFilters(
            query: _query,
            folders: widget.folders,
            subscriptions: widget.subscriptions,
            onViewChanged: _show,
            onFolderChanged: _showFolder,
            onFeedChanged: _setFeed,
            onSortChanged: (sort) {
              setState(() => _query = _query.copyWith(sort: sort));
            },
          ),
          const Divider(height: 1),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_query.normalizedText.isEmpty) {
      return const _SearchPrompt();
    }
    return StreamBuilder<List<ArticleSearchResult>>(
      key: ValueKey<String>(
        '${_query.text}:${_query.view.name}:${_query.folderId}:'
        '${_query.feedId}:${_query.sort.name}:$_retryGeneration',
      ),
      stream: widget.load(_query),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SearchError(
            onRetry: () => setState(() => _retryGeneration += 1),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? const <ArticleSearchResult>[];
        if (results.isEmpty) {
          return const _SearchEmpty();
        }
        return Scrollbar(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) => _SearchResultTile(
              key: ValueKey<String>(results[index].article.id),
              result: results[index],
              query: _query.normalizedText,
              onOpen: () => widget.onOpenArticle(results[index].article),
            ),
          ),
        );
      },
    );
  }
}

final class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.query,
    required this.folders,
    required this.subscriptions,
    required this.onViewChanged,
    required this.onFolderChanged,
    required this.onFeedChanged,
    required this.onSortChanged,
  });

  final ArticleSearchQuery query;
  final List<FeedFolderRecord> folders;
  final List<FeedSubscriptionRecord> subscriptions;
  final ValueChanged<FeedArticleView> onViewChanged;
  final ValueChanged<String> onFolderChanged;
  final ValueChanged<String?> onFeedChanged;
  final ValueChanged<ArticleSearchSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final selectedFolder = query.view == FeedArticleView.folder
        ? folders.where((folder) => folder.id == query.folderId).firstOrNull
        : null;
    final selectedFeed =
        subscriptions.where((feed) => feed.id == query.feedId).firstOrNull;
    return Semantics(
      container: true,
      label: '搜索筛选和排序',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: <Widget>[
            _FilterChip(
              label: '全部',
              selected: query.view == FeedArticleView.inbox,
              onSelected: () => onViewChanged(FeedArticleView.inbox),
            ),
            _FilterChip(
              label: '未读',
              selected: query.view == FeedArticleView.unread,
              onSelected: () => onViewChanged(FeedArticleView.unread),
            ),
            _FilterChip(
              label: '收藏',
              selected: query.view == FeedArticleView.starred,
              onSelected: () => onViewChanged(FeedArticleView.starred),
            ),
            _FilterChip(
              label: '稍后读',
              selected: query.view == FeedArticleView.readLater,
              onSelected: () => onViewChanged(FeedArticleView.readLater),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              enabled: folders.isNotEmpty,
              onSelected: onFolderChanged,
              itemBuilder: (context) => folders
                  .map(
                    (folder) => PopupMenuItem<String>(
                      value: folder.id,
                      child: Text(folder.displayPath),
                    ),
                  )
                  .toList(growable: false),
              tooltip: folders.isEmpty ? '没有文件夹' : '按文件夹筛选',
              child: Chip(
                avatar: const Icon(Icons.folder_outlined, size: 18),
                label: Text(selectedFolder?.displayPath ?? '文件夹'),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  onFeedChanged(value.isEmpty ? null : value),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: '',
                  child: Text('全部来源'),
                ),
                ...subscriptions.map(
                  (feed) => PopupMenuItem<String>(
                    value: feed.id,
                    child: Text(feed.title),
                  ),
                ),
              ],
              tooltip: '按来源筛选',
              child: Chip(
                avatar: const Icon(Icons.rss_feed, size: 18),
                label: Text(selectedFeed?.title ?? '全部来源'),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<ArticleSearchSort>(
              onSelected: onSortChanged,
              itemBuilder: (context) =>
                  const <PopupMenuEntry<ArticleSearchSort>>[
                PopupMenuItem<ArticleSearchSort>(
                  value: ArticleSearchSort.relevance,
                  child: Text('相关性'),
                ),
                PopupMenuItem<ArticleSearchSort>(
                  value: ArticleSearchSort.newest,
                  child: Text('最新优先'),
                ),
                PopupMenuItem<ArticleSearchSort>(
                  value: ArticleSearchSort.oldest,
                  child: Text('最早优先'),
                ),
              ],
              tooltip: '搜索结果排序',
              child: Chip(
                avatar: const Icon(Icons.swap_vert, size: 18),
                label: Text(
                  switch (query.sort) {
                    ArticleSearchSort.relevance => '相关性',
                    ArticleSearchSort.newest => '最新优先',
                    ArticleSearchSort.oldest => '最早优先',
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

final class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.query,
    required this.onOpen,
    super.key,
  });

  final ArticleSearchResult result;
  final String query;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final article = result.article;
    final metadata = <String>[
      article.feedTitle,
      if (article.author case final author? when author.trim().isNotEmpty)
        author,
    ].join(' · ');
    return Semantics(
      button: true,
      label: '搜索结果，${article.title}，$metadata',
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          child: Icon(article.read ? Icons.done : Icons.article_outlined),
        ),
        title: _HighlightedText(
          text: article.title,
          query: query,
          maxLines: 2,
          style: article.read
              ? null
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(metadata, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (result.excerpt.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              _HighlightedText(
                text: result.excerpt,
                query: query,
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.maxLines,
    this.style,
  });

  final String text;
  final String query;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ranges = literalHighlightRanges(text, query);
    if (ranges.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = range.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

final class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: '输入关键词开始本地搜索',
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.manage_search, size: 48),
            SizedBox(height: 12),
            Text('输入关键词开始搜索'),
            SizedBox(height: 6),
            Text('标题、作者、来源、正文、摘要、标签与笔记均保存在本机检索'),
          ],
        ),
      ),
    );
  }
}

final class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: '没有匹配的文章',
        child: const Text('没有匹配的文章'),
      ),
    );
  }
}

final class _SearchError extends StatelessWidget {
  const _SearchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: '搜索失败，可以重试',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('无法完成搜索'),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
