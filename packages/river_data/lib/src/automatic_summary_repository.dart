import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart';

import 'database.dart';

final class DriftAutomaticSummaryRepository
    implements AutomaticSummaryRepository {
  const DriftAutomaticSummaryRepository(this._database);

  final RiverDatabase _database;

  @override
  Stream<AutomaticSummarySettings> watchSettings() =>
      (_database.select(
        _database.automaticSummarySettingsRows,
      )..where((table) => table.id.equals(1))).watchSingleOrNull().map(
        (row) =>
            row == null ? const AutomaticSummarySettings() : _settings(row),
      );

  @override
  Future<AutomaticSummarySettings> readSettings() async {
    final row = await (_database.select(
      _database.automaticSummarySettingsRows,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    return row == null ? const AutomaticSummarySettings() : _settings(row);
  }

  @override
  Future<void> saveSettings(
    AutomaticSummarySettings settings, {
    required DateTime updatedAt,
  }) async {
    settings.validate();
    await _database
        .into(_database.automaticSummarySettingsRows)
        .insertOnConflictUpdate(
          AutomaticSummarySettingsRowsCompanion.insert(
            id: const Value<int>(1),
            enabled: Value<bool>(settings.enabled),
            wifiOnly: Value<bool>(settings.wifiOnly),
            dailyLimit: Value<int>(settings.dailyLimit),
            minimumRankingScore: Value<double>(settings.minimumRankingScore),
            updatedAt: updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<AutomaticSummaryReservationResult> reserveUsage({
    required String idempotencyKey,
    required String articleId,
    required String dayKey,
    required int dailyLimit,
    required DateTime now,
  }) {
    _validateUsageIdentity(idempotencyKey, articleId, dayKey);
    if (dailyLimit < 1 ||
        dailyLimit > AutomaticSummarySettings.maximumDailyLimit) {
      throw ArgumentError.value(dailyLimit, 'dailyLimit');
    }
    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.automaticSummaryUsageRows)
                ..where((table) => table.idempotencyKey.equals(idempotencyKey)))
              .getSingleOrNull();
      if (existing != null) {
        if (existing.articleId != articleId) {
          throw const FormatException('Automatic summary usage collision.');
        }
        if (existing.status == AutomaticSummaryUsageStatus.completed.name) {
          return AutomaticSummaryReservationResult.alreadyCompleted;
        }
        if (existing.status != AutomaticSummaryUsageStatus.reserved.name) {
          throw const FormatException('Invalid automatic summary usage.');
        }
        if (existing.dayKey == dayKey) {
          return AutomaticSummaryReservationResult.alreadyReserved;
        }
        if (await _consumedForDay(dayKey) >= dailyLimit) {
          return AutomaticSummaryReservationResult.limitReached;
        }
        final moved =
            await (_database.update(_database.automaticSummaryUsageRows)..where(
                  (table) =>
                      table.idempotencyKey.equals(idempotencyKey) &
                      table.status.equals(
                        AutomaticSummaryUsageStatus.reserved.name,
                      ) &
                      table.dayKey.equals(existing.dayKey),
                ))
                .write(
                  AutomaticSummaryUsageRowsCompanion(
                    dayKey: Value<String>(dayKey),
                    updatedAt: Value<DateTime>(now.toUtc()),
                  ),
                );
        if (moved != 1) {
          throw StateError('Automatic summary reservation changed.');
        }
        return AutomaticSummaryReservationResult.alreadyReserved;
      }
      if (await _consumedForDay(dayKey) >= dailyLimit) {
        return AutomaticSummaryReservationResult.limitReached;
      }
      final timestamp = now.toUtc();
      await _database
          .into(_database.automaticSummaryUsageRows)
          .insert(
            AutomaticSummaryUsageRowsCompanion.insert(
              idempotencyKey: idempotencyKey,
              articleId: articleId,
              dayKey: dayKey,
              status: AutomaticSummaryUsageStatus.reserved.name,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      return AutomaticSummaryReservationResult.reserved;
    });
  }

  Future<int> _consumedForDay(String dayKey) async {
    final countExpression = _database.automaticSummaryUsageRows.idempotencyKey
        .count();
    final query = _database.selectOnly(_database.automaticSummaryUsageRows)
      ..addColumns(<Expression<Object>>[countExpression])
      ..where(
        _database.automaticSummaryUsageRows.dayKey.equals(dayKey) &
            _database.automaticSummaryUsageRows.status.isIn(<String>[
              AutomaticSummaryUsageStatus.reserved.name,
              AutomaticSummaryUsageStatus.completed.name,
            ]),
      );
    return (await query.getSingle()).read(countExpression) ?? 0;
  }

  @override
  Future<void> completeUsage({
    required String idempotencyKey,
    required DateTime completedAt,
  }) async {
    _validateIdentifier(idempotencyKey, 'idempotencyKey');
    final updated =
        await (_database.update(_database.automaticSummaryUsageRows)..where(
              (table) =>
                  table.idempotencyKey.equals(idempotencyKey) &
                  table.status.equals(
                    AutomaticSummaryUsageStatus.reserved.name,
                  ),
            ))
            .write(
              AutomaticSummaryUsageRowsCompanion(
                status: Value<String>(
                  AutomaticSummaryUsageStatus.completed.name,
                ),
                updatedAt: Value<DateTime>(completedAt.toUtc()),
              ),
            );
    if (updated == 0) {
      final existing =
          await (_database.select(_database.automaticSummaryUsageRows)
                ..where((table) => table.idempotencyKey.equals(idempotencyKey)))
              .getSingleOrNull();
      if (existing?.status != AutomaticSummaryUsageStatus.completed.name) {
        throw StateError('Automatic summary usage was not reserved.');
      }
    }
  }

  @override
  Future<void> releaseUsage({required String idempotencyKey}) async {
    _validateIdentifier(idempotencyKey, 'idempotencyKey');
    await (_database.delete(_database.automaticSummaryUsageRows)..where(
          (table) =>
              table.idempotencyKey.equals(idempotencyKey) &
              table.status.equals(AutomaticSummaryUsageStatus.reserved.name),
        ))
        .go();
  }

  @override
  Future<AutomaticSummaryUsageStatus?> readUsageStatus(
    String idempotencyKey,
  ) async {
    _validateIdentifier(idempotencyKey, 'idempotencyKey');
    final row =
        await (_database.select(_database.automaticSummaryUsageRows)
              ..where((table) => table.idempotencyKey.equals(idempotencyKey)))
            .getSingleOrNull();
    if (row == null) return null;
    return AutomaticSummaryUsageStatus.values.firstWhere(
      (status) => status.name == row.status,
      orElse: () => throw const FormatException(
        'Invalid automatic summary usage status.',
      ),
    );
  }

  @override
  Future<AutomaticSummaryUsageSnapshot> readUsage(String dayKey) async {
    _validateDayKey(dayKey);
    final rows = await (_database.select(
      _database.automaticSummaryUsageRows,
    )..where((table) => table.dayKey.equals(dayKey))).get();
    return AutomaticSummaryUsageSnapshot(
      dayKey: dayKey,
      reserved: rows
          .where(
            (row) => row.status == AutomaticSummaryUsageStatus.reserved.name,
          )
          .length,
      completed: rows
          .where(
            (row) => row.status == AutomaticSummaryUsageStatus.completed.name,
          )
          .length,
    );
  }
}

AutomaticSummarySettings _settings(AutomaticSummarySettingsRow row) {
  final value = AutomaticSummarySettings(
    enabled: row.enabled,
    wifiOnly: row.wifiOnly,
    dailyLimit: row.dailyLimit,
    minimumRankingScore: row.minimumRankingScore,
  );
  value.validate();
  return value;
}

void _validateUsageIdentity(
  String idempotencyKey,
  String articleId,
  String dayKey,
) {
  _validateIdentifier(idempotencyKey, 'idempotencyKey');
  _validateIdentifier(articleId, 'articleId');
  _validateDayKey(dayKey);
}

void _validateIdentifier(String value, String name) {
  if (value.isEmpty || value.length > 512 || value.trim() != value) {
    throw ArgumentError.value(value, name);
  }
}

void _validateDayKey(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'dayKey');
  }
}
