import 'dart:async';

import 'package:flutter/material.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';

typedef ArticleDetailLoader = Stream<FeedArticleDetailRecord?> Function(
  String articleId,
);
typedef ArticleExtractionLoader = Future<ExtractionResult> Function(
  ExtractionRequest request,
);

enum ArticleReaderLoadPhase { loading, ready, missing, failed }

enum ArticleEnhancementPhase { idle, enhancing, ready, failed }

enum ArticleReaderContentSource { feed, cache, extracted }

final class ArticleReaderContent {
  const ArticleReaderContent({
    required this.text,
    required this.source,
    required this.revision,
  });

  final String text;
  final ArticleReaderContentSource source;
  final String revision;

  int get priority => switch (source) {
        ArticleReaderContentSource.feed => 0,
        ArticleReaderContentSource.cache => 1,
        ArticleReaderContentSource.extracted => 2,
      };
}

final class ArticleReaderState {
  const ArticleReaderState({
    required this.loadPhase,
    this.enhancementPhase = ArticleEnhancementPhase.idle,
    this.detail,
    this.content,
  });

  const ArticleReaderState.loading()
      : this(loadPhase: ArticleReaderLoadPhase.loading);

  final ArticleReaderLoadPhase loadPhase;
  final ArticleEnhancementPhase enhancementPhase;
  final FeedArticleDetailRecord? detail;
  final ArticleReaderContent? content;

  ArticleReaderState copyWith({
    ArticleReaderLoadPhase? loadPhase,
    ArticleEnhancementPhase? enhancementPhase,
    FeedArticleDetailRecord? detail,
    ArticleReaderContent? content,
  }) =>
      ArticleReaderState(
        loadPhase: loadPhase ?? this.loadPhase,
        enhancementPhase: enhancementPhase ?? this.enhancementPhase,
        detail: detail ?? this.detail,
        content: content ?? this.content,
      );
}

final class ArticleReaderController extends ChangeNotifier {
  ArticleReaderController({
    required this.articleId,
    required ArticleDetailLoader watch,
    required ArticleExtractionLoader extract,
  })  : _watch = watch,
        _extract = extract {
    _subscribe();
  }

  final String articleId;
  final ArticleDetailLoader _watch;
  final ArticleExtractionLoader _extract;
  StreamSubscription<FeedArticleDetailRecord?>? _subscription;
  ArticleReaderState _state = const ArticleReaderState.loading();
  var _extractionStarted = false;
  var _subscriptionGeneration = 0;
  var _extractionGeneration = 0;
  var _disposed = false;

  ArticleReaderState get state => _state;

  void retry() {
    _extractionStarted = false;
    _extractionGeneration += 1;
    _setState(const ArticleReaderState.loading());
    _subscribe();
  }

  void _subscribe() {
    final generation = ++_subscriptionGeneration;
    unawaited(_subscription?.cancel());
    _subscription = _watch(articleId).listen(
      (detail) {
        if (generation == _subscriptionGeneration) _acceptDetail(detail);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _subscriptionGeneration) return;
        _setState(
          const ArticleReaderState(loadPhase: ArticleReaderLoadPhase.failed),
        );
      },
    );
  }

  void _acceptDetail(FeedArticleDetailRecord? detail) {
    if (detail == null) {
      _setState(
        const ArticleReaderState(loadPhase: ArticleReaderLoadPhase.missing),
      );
      return;
    }
    final candidate = _availableContent(detail);
    final current = _state.content;
    final nextContent = candidate == null ||
            (current != null && candidate.priority < current.priority)
        ? current
        : candidate;
    _setState(
      ArticleReaderState(
        loadPhase: ArticleReaderLoadPhase.ready,
        enhancementPhase: _state.enhancementPhase,
        detail: detail,
        content: nextContent,
      ),
    );
    if (!_extractionStarted) {
      _extractionStarted = true;
      unawaited(_enhance(detail));
    }
  }

  Future<void> _enhance(FeedArticleDetailRecord detail) async {
    final generation = ++_extractionGeneration;
    _setState(
      _state.copyWith(enhancementPhase: ArticleEnhancementPhase.enhancing),
    );
    ExtractionResult result;
    try {
      result = await _extract(
        ExtractionRequest(
          sourceUri: detail.canonicalUrl,
          articleId: detail.id,
          feedContentHtml: detail.feedContentHtml,
          feedSummary: detail.summary,
          title: detail.title,
          author: detail.author,
          publishedAt: detail.publishedAt,
        ),
      );
    } on Object {
      if (_disposed || generation != _extractionGeneration) return;
      _setState(
        _state.copyWith(enhancementPhase: ArticleEnhancementPhase.failed),
      );
      return;
    }
    if (_disposed || generation != _extractionGeneration) return;
    switch (result) {
      case ExtractionSuccess(:final article, :final attempts):
        final fromCache = attempts.any(
          (attempt) =>
              attempt.extractor == CachedFullTextExtractor.cacheExtractor,
        );
        final content = ArticleReaderContent(
          text: article.plainText.trim(),
          source: fromCache
              ? ArticleReaderContentSource.cache
              : ArticleReaderContentSource.extracted,
          revision:
              '${article.extractor}@${article.extractorVersion}:${article.html.hashCode}',
        );
        _setState(
          _state.copyWith(
            enhancementPhase: ArticleEnhancementPhase.ready,
            content: content.text.isEmpty ? _state.content : content,
          ),
        );
      case ExtractionFailureResult():
        _setState(
          _state.copyWith(enhancementPhase: ArticleEnhancementPhase.failed),
        );
    }
  }

  ArticleReaderContent? _availableContent(FeedArticleDetailRecord detail) {
    final cached = detail.content;
    if (cached != null && cached.isReadable) {
      return ArticleReaderContent(
        text: cached.plainText.trim(),
        source: ArticleReaderContentSource.cache,
        revision: cached.contentHash ??
            '${cached.extractorName}@${cached.extractorVersion}:'
                '${cached.extractedAt.microsecondsSinceEpoch}',
      );
    }
    final assessed = const FeedContentAssessor().assess(
      contentHtml: detail.feedContentHtml,
      summary: detail.summary,
      sourceUri: detail.canonicalUrl,
    );
    final preview = assessed.content.plainText.trim();
    if (preview.isEmpty) return null;
    return ArticleReaderContent(
      text: preview,
      source: ArticleReaderContentSource.feed,
      revision: 'feed:${preview.hashCode}',
    );
  }

  void _setState(ArticleReaderState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscriptionGeneration += 1;
    _extractionGeneration += 1;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final class ArticleReaderPage extends StatefulWidget {
  const ArticleReaderPage({
    required this.articleId,
    required this.watch,
    required this.extract,
    super.key,
  });

  final String articleId;
  final ArticleDetailLoader watch;
  final ArticleExtractionLoader extract;

  @override
  State<ArticleReaderPage> createState() => _ArticleReaderPageState();
}

final class _ArticleReaderPageState extends State<ArticleReaderPage> {
  late final ArticleReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ArticleReaderController(
      articleId: widget.articleId,
      watch: widget.watch,
      extract: widget.extract,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ArticleReaderScreen(controller: _controller);
}

final class ArticleReaderScreen extends StatelessWidget {
  const ArticleReaderScreen({required this.controller, super.key});

  final ArticleReaderController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final state = controller.state;
        return Scaffold(
          appBar: AppBar(title: Text(state.detail?.feedTitle ?? '阅读文章')),
          body: switch (state.loadPhase) {
            ArticleReaderLoadPhase.loading => const _ReaderLoading(),
            ArticleReaderLoadPhase.missing => const _ReaderMissing(),
            ArticleReaderLoadPhase.failed => _ReaderFailure(
                onRetry: controller.retry,
              ),
            ArticleReaderLoadPhase.ready => _ReaderReady(state: state),
          },
        );
      },
    );
  }
}

final class _ReaderReady extends StatelessWidget {
  const _ReaderReady({required this.state});

  final ArticleReaderState state;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail!;
    final content = state.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ReaderHeader(detail: detail, enhancement: state.enhancementPhase),
        const Divider(height: 1),
        Expanded(
          child: content == null
              ? const _ReaderContentPending()
              : ArticleDocumentView(content: content),
        ),
      ],
    );
  }
}

final class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({required this.detail, required this.enhancement});

  final FeedArticleDetailRecord detail;
  final ArticleEnhancementPhase enhancement;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      detail.feedTitle,
      if (detail.author?.trim() case final author? when author.isNotEmpty)
        author,
      if (detail.publishedAt case final date?) _dateLabel(date),
    ].join(' · ');
    final (status, icon) = switch (enhancement) {
      ArticleEnhancementPhase.idle => ('正在准备正文', Icons.hourglass_empty),
      ArticleEnhancementPhase.enhancing => (
          '已显示可用内容，正在获取完整正文',
          Icons.downloading_outlined
        ),
      ArticleEnhancementPhase.ready => ('完整正文已就绪', Icons.check_circle_outline),
      ArticleEnhancementPhase.failed => (
          '完整正文暂不可用，当前内容仍可阅读',
          Icons.info_outline
        ),
    };
    return Semantics(
      container: true,
      label: '${detail.title}，$metadata，$status',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              detail.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(metadata, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              label: status,
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class ArticleDocumentView extends StatefulWidget {
  const ArticleDocumentView({required this.content, super.key});

  final ArticleReaderContent content;

  @override
  State<ArticleDocumentView> createState() => ArticleDocumentViewState();
}

final class ArticleDocumentViewState extends State<ArticleDocumentView> {
  late final ScrollController _scrollController;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  String? _pendingText;
  var _updatingText = false;

  TextSelection get selection => _textController.selection;
  String get documentText => _textController.text;
  double get scrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0;
  String get selectedText {
    final current = selection;
    if (!current.isValid || current.isCollapsed) return '';
    return _textController.text.substring(current.start, current.end);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _textController = TextEditingController(text: widget.content.text)
      ..addListener(_handleSelectionChange);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(ArticleDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content.text != oldWidget.content.text) {
      _replacePreservingAnchors(widget.content.text);
    }
  }

  void selectRange(int start, int end) {
    _textController.selection =
        TextSelection(baseOffset: start, extentOffset: end);
    _focusNode.requestFocus();
  }

  void scrollToFraction(double fraction) {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(
      _scrollController.position.maxScrollExtent * fraction.clamp(0, 1),
    );
  }

  void _handleSelectionChange() {
    if (_updatingText || _pendingText == null || !selection.isCollapsed) return;
    final pending = _pendingText!;
    _pendingText = null;
    _replacePreservingAnchors(pending);
  }

  void _replacePreservingAnchors(String nextText) {
    final previousText = _textController.text;
    if (previousText == nextText) return;
    final previousSelection = _textController.selection;
    final mappedSelection = _mapSelection(
      previousText,
      nextText,
      previousSelection,
    );
    if (!previousSelection.isCollapsed && mappedSelection == null) {
      _pendingText = nextText;
      return;
    }

    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = scrollOffset;
    final oldAnchor = previousText.isEmpty || oldExtent <= 0
        ? 0
        : (previousText.length * (oldOffset / oldExtent))
            .round()
            .clamp(0, previousText.length);
    final mappedAnchor = _mapOffset(previousText, nextText, oldAnchor);
    _updatingText = true;
    _textController.value = TextEditingValue(
      text: nextText,
      selection: mappedSelection ??
          TextSelection.collapsed(
            offset: _mapOffset(
              previousText,
              nextText,
              previousSelection.extentOffset.clamp(0, previousText.length),
            ),
          ),
    );
    _updatingText = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || nextText.isEmpty) return;
      final extent = _scrollController.position.maxScrollExtent;
      final target = extent * (mappedAnchor / nextText.length);
      _scrollController.jumpTo(target.clamp(0, extent));
    });
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleSelectionChange)
      ..dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Semantics(
              container: true,
              label: '文章正文',
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                readOnly: true,
                maxLines: null,
                scrollPhysics: const NeverScrollableScrollPhysics(),
                decoration: const InputDecoration.collapsed(hintText: ''),
                style: textTheme.bodyLarge?.copyWith(height: 1.75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextSelection? _mapSelection(
  String previous,
  String next,
  TextSelection selection,
) {
  if (!selection.isValid) return const TextSelection.collapsed(offset: 0);
  final start = selection.start.clamp(0, previous.length);
  final end = selection.end.clamp(start, previous.length);
  if (start == end) {
    return TextSelection.collapsed(offset: _mapOffset(previous, next, start));
  }
  final selected = previous.substring(start, end);
  final matches = <int>[];
  var from = 0;
  while (from <= next.length - selected.length) {
    final match = next.indexOf(selected, from);
    if (match < 0) break;
    matches.add(match);
    from = match + selected.length.clamp(1, selected.length);
  }
  if (matches.isEmpty) return null;
  final expected =
      previous.isEmpty ? 0 : (next.length * (start / previous.length)).round();
  matches.sort(
    (left, right) =>
        (left - expected).abs().compareTo((right - expected).abs()),
  );
  final mappedStart = matches.first;
  return TextSelection(
    baseOffset: mappedStart,
    extentOffset: mappedStart + selected.length,
  );
}

int _mapOffset(String previous, String next, int offset) {
  if (next.isEmpty || previous.isEmpty) return 0;
  final safeOffset = offset.clamp(0, previous.length);
  final contextStart = (safeOffset - 24).clamp(0, previous.length);
  final contextEnd = (safeOffset + 24).clamp(contextStart, previous.length);
  final context = previous.substring(contextStart, contextEnd);
  if (context.isNotEmpty) {
    final match = next.indexOf(context);
    if (match >= 0) {
      return (match + safeOffset - contextStart).clamp(0, next.length);
    }
  }
  return (next.length * (safeOffset / previous.length))
      .round()
      .clamp(0, next.length);
}

final class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: '正在打开文章',
          child: const CircularProgressIndicator(),
        ),
      );
}

final class _ReaderContentPending extends StatelessWidget {
  const _ReaderContentPending();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: 'Feed 没有提供正文，正在获取完整内容',
          child: const Text('Feed 没有提供正文，正在获取完整内容…'),
        ),
      );
}

final class _ReaderMissing extends StatelessWidget {
  const _ReaderMissing();

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          container: true,
          label: '文章不存在或已被删除',
          child: const Text('文章不存在或已被删除'),
        ),
      );
}

final class _ReaderFailure extends StatelessWidget {
  const _ReaderFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '文章打开失败，可以重试',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text('无法打开文章'),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      );
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
