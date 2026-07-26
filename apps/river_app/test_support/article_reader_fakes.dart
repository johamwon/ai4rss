import 'dart:async';

import 'package:river_app/app/article_reader.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';

final class FakeArticleReaderRepository implements ArticleReaderRepository {
  FakeArticleReaderRepository(this.watch);

  final Stream<FeedArticleDetailRecord?> Function(String articleId) watch;
  final List<bool> readWrites = <bool>[];
  final List<bool> starredWrites = <bool>[];
  final List<bool> readLaterWrites = <bool>[];
  final List<double> progressWrites = <double>[];

  @override
  Stream<FeedArticleDetailRecord?> watchArticle(String articleId) =>
      watch(articleId);

  @override
  Future<void> setRead(
    String articleId, {
    required bool read,
    required DateTime updatedAt,
  }) async {
    readWrites.add(read);
  }

  @override
  Future<void> setStarred(
    String articleId, {
    required bool starred,
    required DateTime updatedAt,
  }) async {
    starredWrites.add(starred);
  }

  @override
  Future<void> setReadLater(
    String articleId, {
    required bool readLater,
    required DateTime updatedAt,
  }) async {
    readLaterWrites.add(readLater);
  }

  @override
  Future<void> saveReadingProgress(
    String articleId, {
    required double scrollDepth,
    required DateTime updatedAt,
  }) async {
    progressWrites.add(scrollDepth);
  }
}

final class FakeExtractor implements FullTextExtractor {
  const FakeExtractor(this.load);

  final Future<ExtractionResult> Function(ExtractionRequest request) load;

  @override
  Future<ExtractionResult> extract(ExtractionRequest request) => load(request);
}

final class FakeReaderSettingsRepository implements ReaderSettingsRepository {
  FakeReaderSettingsRepository({
    ReaderSettings initial = const ReaderSettings(),
  }) : _current = initial;

  ReaderSettings _current;
  final StreamController<ReaderSettings> _changes =
      StreamController<ReaderSettings>.broadcast();

  ReaderSettings get current => _current;

  @override
  Stream<ReaderSettings> watchSettings() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> saveSettings(
    ReaderSettings settings, {
    required DateTime updatedAt,
  }) async {
    _current = settings;
    _changes.add(settings);
  }

  Future<void> close() => _changes.close();
}

final class FakeShareGateway implements ShareGateway {
  ShareRequest? lastRequest;
  ShareOutcome outcome = ShareOutcome.completed;

  @override
  Future<ShareOutcome> share(ShareRequest request) async {
    lastRequest = request;
    return outcome;
  }
}

final class FakeExternalUriGateway implements ExternalUriGateway {
  Uri? lastUri;
  ExternalUriOpenOutcome outcome = ExternalUriOpenOutcome.opened;

  @override
  Future<ExternalUriOpenOutcome> open(Uri uri) async {
    lastUri = uri;
    return outcome;
  }
}

final class FixedReaderClock implements Clock {
  const FixedReaderClock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 19, 8);
}

ArticleReaderController buildReaderController({
  required String articleId,
  required Stream<FeedArticleDetailRecord?> Function(String articleId) watch,
  required Future<ExtractionResult> Function(ExtractionRequest request) extract,
  FakeArticleReaderRepository? repository,
  FakeReaderSettingsRepository? settings,
  FakeShareGateway? share,
  FakeExternalUriGateway? externalUri,
}) =>
    ArticleReaderController(
      articleId: articleId,
      repository: repository ?? FakeArticleReaderRepository(watch),
      extractor: FakeExtractor(extract),
      readerSettings: settings ?? FakeReaderSettingsRepository(),
      share: share ?? FakeShareGateway(),
      externalUri: externalUri ?? FakeExternalUriGateway(),
      clock: const FixedReaderClock(),
    );
