import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftAutomaticSummaryRepository repository;

  setUp(() {
    database = RiverDatabase(NativeDatabase.memory());
    repository = DriftAutomaticSummaryRepository(database);
  });

  tearDown(() => database.close());

  test('settings default closed and persist bounded local policy', () async {
    expect(await repository.readSettings(), const AutomaticSummarySettings());
    const settings = AutomaticSummarySettings(
      enabled: true,
      wifiOnly: false,
      dailyLimit: 5,
      minimumRankingScore: 0.8,
    );
    await repository.saveSettings(
      settings,
      updatedAt: DateTime.utc(2026, 8, 5),
    );

    expect(await repository.readSettings(), settings);
    expect(await repository.watchSettings().first, settings);
  });

  test('concurrent reservations never exceed the daily limit', () async {
    final now = DateTime.utc(2026, 8, 5, 8);
    final results =
        await Future.wait(<Future<AutomaticSummaryReservationResult>>[
          for (var index = 0; index < 10; index++)
            repository.reserveUsage(
              idempotencyKey: 'usage-$index',
              articleId: 'article-$index',
              dayKey: '2026-08-05',
              dailyLimit: 3,
              now: now,
            ),
        ]);

    expect(
      results.where(
        (result) => result == AutomaticSummaryReservationResult.reserved,
      ),
      hasLength(3),
    );
    expect((await repository.readUsage('2026-08-05')).consumed, 3);
  });

  test(
    'only usable results remain charged and retries are idempotent',
    () async {
      final now = DateTime.utc(2026, 8, 5, 8);
      expect(
        await repository.reserveUsage(
          idempotencyKey: 'usage-1',
          articleId: 'article-1',
          dayKey: '2026-08-05',
          dailyLimit: 1,
          now: now,
        ),
        AutomaticSummaryReservationResult.reserved,
      );
      await repository.releaseUsage(idempotencyKey: 'usage-1');
      expect((await repository.readUsage('2026-08-05')).consumed, 0);

      await repository.reserveUsage(
        idempotencyKey: 'usage-1',
        articleId: 'article-1',
        dayKey: '2026-08-05',
        dailyLimit: 1,
        now: now,
      );
      await repository.completeUsage(
        idempotencyKey: 'usage-1',
        completedAt: now,
      );
      await repository.completeUsage(
        idempotencyKey: 'usage-1',
        completedAt: now,
      );

      expect(
        await repository.readUsageStatus('usage-1'),
        AutomaticSummaryUsageStatus.completed,
      );
      expect((await repository.readUsage('2026-08-05')).completed, 1);
    },
  );

  test(
    'an unfinished reservation moves across days without bypassing cap',
    () async {
      final firstDay = DateTime.utc(2026, 8, 5, 23, 59);
      final secondDay = DateTime.utc(2026, 8, 6, 0, 1);
      await repository.reserveUsage(
        idempotencyKey: 'stale-reservation',
        articleId: 'article-stale',
        dayKey: '2026-08-05',
        dailyLimit: 1,
        now: firstDay,
      );
      await repository.reserveUsage(
        idempotencyKey: 'current-reservation',
        articleId: 'article-current',
        dayKey: '2026-08-06',
        dailyLimit: 1,
        now: secondDay,
      );

      expect(
        await repository.reserveUsage(
          idempotencyKey: 'stale-reservation',
          articleId: 'article-stale',
          dayKey: '2026-08-06',
          dailyLimit: 1,
          now: secondDay,
        ),
        AutomaticSummaryReservationResult.limitReached,
      );
      expect((await repository.readUsage('2026-08-05')).consumed, 1);

      await repository.releaseUsage(idempotencyKey: 'current-reservation');
      expect(
        await repository.reserveUsage(
          idempotencyKey: 'stale-reservation',
          articleId: 'article-stale',
          dayKey: '2026-08-06',
          dailyLimit: 1,
          now: secondDay,
        ),
        AutomaticSummaryReservationResult.alreadyReserved,
      );
      expect((await repository.readUsage('2026-08-05')).consumed, 0);
      expect((await repository.readUsage('2026-08-06')).reserved, 1);
    },
  );
}
