enum OfflineArticlePhase {
  notDownloaded,
  queued,
  downloading,
  available,
  failed,
}

final class OfflineArticleState {
  const OfflineArticleState({
    required this.articleId,
    required this.phase,
    this.failureCode,
  });

  const OfflineArticleState.notDownloaded(String articleId)
      : this(
          articleId: articleId,
          phase: OfflineArticlePhase.notDownloaded,
        );

  final String articleId;
  final OfflineArticlePhase phase;
  final String? failureCode;

  bool get isAvailable => phase == OfflineArticlePhase.available;
}

abstract interface class OfflineArticleManager {
  Stream<OfflineArticleState> watch(String articleId);

  Future<OfflineArticleState> status(String articleId);

  Future<void> enqueue(String articleId);

  Future<void> retry(String articleId);

  Future<void> resumePending();
}

final class UnavailableOfflineArticleManager implements OfflineArticleManager {
  const UnavailableOfflineArticleManager();

  @override
  Future<void> enqueue(String articleId) async {}

  @override
  Future<void> resumePending() async {}

  @override
  Future<void> retry(String articleId) async {}

  @override
  Future<OfflineArticleState> status(String articleId) async =>
      OfflineArticleState.notDownloaded(articleId);

  @override
  Stream<OfflineArticleState> watch(String articleId) =>
      Stream<OfflineArticleState>.value(
        OfflineArticleState.notDownloaded(articleId),
      );
}
