import 'package:flutter/material.dart';
import 'package:river_feed/river_feed.dart';

typedef ArticleListLoader = Stream<List<FeedArticleRecord>> Function(
  FeedArticleQuery query,
);

final class ArticleListController extends ChangeNotifier {
  ArticleListController({
    required ArticleListLoader load,
    FeedArticleQuery initialQuery = const FeedArticleQuery(),
  })  : _load = load,
        _query = initialQuery;

  final ArticleListLoader _load;
  FeedArticleQuery _query;

  FeedArticleQuery get query => _query;

  Stream<List<FeedArticleRecord>> get articles => _load(_query);

  void show(FeedArticleView view) {
    assert(view != FeedArticleView.folder, 'Use showFolder for folder views.');
    _replace(
      FeedArticleQuery(
        view: view,
        sort: _query.sort,
        feedId: _query.feedId,
      ),
    );
  }

  void showFolder(String folderId) {
    _replace(
      FeedArticleQuery(
        view: FeedArticleView.folder,
        sort: _query.sort,
        feedId: _query.feedId,
        folderId: folderId,
      ),
    );
  }

  void sortBy(FeedArticleSort sort) {
    _replace(_query.copyWith(sort: sort));
  }

  void _replace(FeedArticleQuery value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }
}

final class ArticleListPane extends StatefulWidget {
  const ArticleListPane({
    required this.controller,
    required this.folders,
    required this.onOpenArticle,
    super.key,
  });

  final ArticleListController controller;
  final List<FeedFolderRecord> folders;
  final ValueChanged<FeedArticleRecord> onOpenArticle;

  @override
  State<ArticleListPane> createState() => _ArticleListPaneState();
}

final class _ArticleListPaneState extends State<ArticleListPane> {
  var _retryGeneration = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final query = widget.controller.query;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ArticleListToolbar(
              controller: widget.controller,
              folders: widget.folders,
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<FeedArticleRecord>>(
                key: ValueKey<String>(
                  '${query.view.name}:${query.folderId}:'
                  '${query.sort.name}:$_retryGeneration',
                ),
                stream: widget.controller.articles,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ArticleListError(
                      onRetry: () => setState(() => _retryGeneration += 1),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _ArticleListLoading();
                  }
                  final articles = snapshot.data ?? const <FeedArticleRecord>[];
                  if (articles.isEmpty) {
                    return _ArticleListEmpty(query: query);
                  }
                  return Scrollbar(
                    child: ListView.separated(
                      key: PageStorageKey<String>(
                        'article-list-${query.view.name}-'
                        '${query.folderId}-${query.sort.name}',
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) => ArticleListTile(
                        key: ValueKey<String>(articles[index].id),
                        article: articles[index],
                        onOpen: () => widget.onOpenArticle(articles[index]),
                      ),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 72),
                      itemCount: articles.length,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _ArticleListToolbar extends StatelessWidget {
  const _ArticleListToolbar({
    required this.controller,
    required this.folders,
  });

  final ArticleListController controller;
  final List<FeedFolderRecord> folders;

  @override
  Widget build(BuildContext context) {
    final query = controller.query;
    final selectedFolder = query.view == FeedArticleView.folder
        ? folders.where((folder) => folder.id == query.folderId).firstOrNull
        : null;
    return Semantics(
      container: true,
      label: '文章筛选和排序',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: <Widget>[
            _ViewChip(
              label: '收件箱',
              selected: query.view == FeedArticleView.inbox,
              onSelected: () => controller.show(FeedArticleView.inbox),
            ),
            const SizedBox(width: 8),
            _ViewChip(
              label: '未读',
              selected: query.view == FeedArticleView.unread,
              onSelected: () => controller.show(FeedArticleView.unread),
            ),
            const SizedBox(width: 8),
            _ViewChip(
              label: '收藏',
              selected: query.view == FeedArticleView.starred,
              onSelected: () => controller.show(FeedArticleView.starred),
            ),
            const SizedBox(width: 8),
            _ViewChip(
              label: '稍后读',
              selected: query.view == FeedArticleView.readLater,
              onSelected: () => controller.show(FeedArticleView.readLater),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              enabled: folders.isNotEmpty,
              onSelected: controller.showFolder,
              itemBuilder: (context) => folders
                  .map(
                    (folder) => PopupMenuItem<String>(
                      value: folder.id,
                      child: Text(folder.displayPath),
                    ),
                  )
                  .toList(growable: false),
              tooltip: folders.isEmpty ? '没有文件夹' : '选择文件夹',
              child: Chip(
                avatar: const Icon(Icons.folder_outlined, size: 18),
                backgroundColor: selectedFolder == null
                    ? null
                    : Theme.of(context).colorScheme.secondaryContainer,
                label: Text(selectedFolder?.displayPath ?? '文件夹'),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<FeedArticleSort>(
              onSelected: controller.sortBy,
              itemBuilder: (context) => const <PopupMenuEntry<FeedArticleSort>>[
                PopupMenuItem<FeedArticleSort>(
                  value: FeedArticleSort.newest,
                  child: Text('最新优先'),
                ),
                PopupMenuItem<FeedArticleSort>(
                  value: FeedArticleSort.oldest,
                  child: Text('最早优先'),
                ),
              ],
              tooltip:
                  query.sort == FeedArticleSort.newest ? '排序：最新优先' : '排序：最早优先',
              child: Chip(
                avatar: const Icon(Icons.swap_vert, size: 18),
                label: Text(
                  query.sort == FeedArticleSort.newest ? '最新优先' : '最早优先',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => onSelected(),
    );
  }
}

final class ArticleListTile extends StatelessWidget {
  const ArticleListTile({
    required this.article,
    required this.onOpen,
    super.key,
  });

  final FeedArticleRecord article;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      article.feedTitle,
      if (article.publishedAt case final publishedAt?) _dateLabel(publishedAt),
      if (article.estimatedReadingMinutes case final minutes?) '$minutes 分钟',
    ].join(' · ');
    final states = <String>[
      article.read ? '已读' : '未读',
      if (article.starred) '已收藏',
      if (article.readLater) '稍后读',
    ];
    final summary = article.summary?.trim();
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${article.title}，$metadata，${states.join('，')}',
      onTap: onOpen,
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          child: Icon(
            article.read ? Icons.done : Icons.article_outlined,
            semanticLabel: article.read ? '已读' : '未读',
          ),
        ),
        title: Text(
          article.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: article.read
              ? null
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(metadata, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (summary != null && summary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (article.starred)
              const Tooltip(message: '已收藏', child: Icon(Icons.star)),
            if (article.readLater)
              const Tooltip(
                message: '稍后读',
                child: Icon(Icons.bookmark_outline),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ArticleListLoading extends StatelessWidget {
  const _ArticleListLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: '正在加载文章',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

final class _ArticleListError extends StatelessWidget {
  const _ArticleListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: '文章加载失败，可以重试',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('无法加载文章'),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

final class _ArticleListEmpty extends StatelessWidget {
  const _ArticleListEmpty({required this.query});

  final FeedArticleQuery query;

  @override
  Widget build(BuildContext context) {
    final message = switch (query.view) {
      FeedArticleView.inbox => '订阅源中还没有文章',
      FeedArticleView.unread => '没有未读文章',
      FeedArticleView.starred => '还没有收藏文章',
      FeedArticleView.readLater => '稍后读列表为空',
      FeedArticleView.folder => '这个文件夹中还没有文章',
    };
    return Center(
      child: Semantics(
        container: true,
        label: message,
        child: Text(message),
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
