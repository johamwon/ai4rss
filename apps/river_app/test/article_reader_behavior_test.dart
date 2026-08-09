import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_preferences/river_preferences.dart';

import '../test_support/article_reader_fakes.dart';

void main() {
  test('reader persists a real session and one aggregate experiment outcome',
      () async {
    final clock = _MutableClock(DateTime.utc(2026, 8, 6, 12));
    final behavior = _BehaviorRepository();
    final experimentRepository = _ExperimentRepository()
      ..enrollment = RankingExperimentEnrollment(
        experimentId: rankingExperimentId,
        arm: RankingExperimentArm.personalized,
        assignedAt: clock.now(),
      );
    final controller = buildReaderController(
      articleId: 'article-1',
      watch: (_) => Stream<FeedArticleDetailRecord?>.value(_detail()),
      extract: (_) async => const ExtractionFailureResult(
        failure: ExtractionFailure(
          code: ExtractionFailureCode.network,
          message: 'offline',
        ),
        attempts: <ExtractionAttempt>[],
      ),
      ids: SequentialReaderIds(),
      clock: clock,
      readingBehavior: behavior,
      rankingExperiment: LocalRankingExperiment(
        repository: experimentRepository,
      ),
    );

    await Future<void>.delayed(Duration.zero);
    clock.value = clock.value.add(const Duration(seconds: 35));
    controller.reportProgress(0.95);
    await controller.closeReadingSession();
    controller.dispose();

    expect(
      behavior.events.map((event) => event.type),
      containsAllInOrder(<ReadingEventType>[
        ReadingEventType.open,
        ReadingEventType.activeRead,
        ReadingEventType.completed,
      ]),
    );
    final outcome = experimentRepository.outcomes.single;
    expect(outcome.activeSeconds, 35);
    expect(outcome.completed, isTrue);
    expect(outcome.quickExit, isFalse);
  });
}

FeedArticleDetailRecord _detail() => FeedArticleDetailRecord(
      id: 'article-1',
      feedId: 'feed-1',
      feedTitle: 'Example',
      canonicalUrl: Uri.parse('https://example.test/article-1'),
      title: 'Article',
      read: false,
      starred: false,
      readLater: false,
      scrollDepth: 0,
      activeReadSeconds: 0,
      feedContentHtml: '<p>Readable content</p>',
    );

final class _MutableClock implements Clock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _BehaviorRepository implements ReadingBehaviorRepository {
  final events = <ReadingEvent>[];

  @override
  Future<int> clearEvents() async => 0;

  @override
  Future<int> clearPreferenceProfile({required DateTime updatedAt}) async => 0;

  @override
  Future<String> exportJson({required DateTime exportedAt}) async => '{}';

  @override
  Future<bool> needsIntroduction() async => false;

  @override
  Future<int> purgeExpired({required DateTime now}) async => 0;

  @override
  Future<List<ReadingEvent>> readEvents() async => events;

  @override
  Future<ReadingBehaviorSettings> readSettings() async =>
      const ReadingBehaviorSettings(captureEnabled: true);

  @override
  Future<ReadingEventRecordResult> record(ReadingEvent event) async {
    events.add(event);
    return ReadingEventRecordResult.inserted;
  }

  @override
  Future<void> saveSettings(
    ReadingBehaviorSettings settings, {
    required DateTime updatedAt,
  }) async {}

  @override
  Stream<ReadingBehaviorSettings> watchSettings() =>
      Stream<ReadingBehaviorSettings>.value(
        const ReadingBehaviorSettings(captureEnabled: true),
      );
}

final class _ExperimentRepository implements RankingExperimentRepository {
  RankingExperimentEnrollment? enrollment;
  final outcomes = <RankingExperimentReadingOutcome>[];

  @override
  Future<int> clearMetrics({required String experimentId}) async => 0;

  @override
  Future<void> disable({required DateTime updatedAt}) async =>
      enrollment = null;

  @override
  Future<RankingExperimentEnrollment?> readEnrollment() async => enrollment;

  @override
  Future<List<RankingExperimentDailyMetrics>> readMetrics({
    required String experimentId,
    required String startDay,
    required String endDay,
  }) async =>
      const <RankingExperimentDailyMetrics>[];

  @override
  Future<void> recordExposure(RankingExperimentExposure exposure) async {}

  @override
  Future<void> recordReadingOutcome(
    RankingExperimentReadingOutcome outcome,
  ) async =>
      outcomes.add(outcome);

  @override
  Future<void> recordSummaryObservation(
    RankingExperimentSummaryObservation observation,
  ) async {}

  @override
  Future<void> saveEnrollment(RankingExperimentEnrollment value) async =>
      enrollment = value;

  @override
  Stream<RankingExperimentEnrollment?> watchEnrollment() =>
      Stream<RankingExperimentEnrollment?>.value(enrollment);
}
