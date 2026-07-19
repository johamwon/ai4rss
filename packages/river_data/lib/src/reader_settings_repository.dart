import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart';

import 'database.dart';

final class DriftReaderSettingsRepository implements ReaderSettingsRepository {
  const DriftReaderSettingsRepository(this.database);

  static const rowId = 'default';

  final RiverDatabase database;

  @override
  Stream<ReaderSettings> watchSettings() {
    final query = database.select(database.readerSettingsRows)
      ..where((table) => table.id.equals(rowId));
    return query.watchSingleOrNull().map(
      (row) => row == null
          ? const ReaderSettings()
          : ReaderSettings(
              fontFamily: _enumOrDefault(
                ReaderFontFamily.values,
                row.fontFamily,
                ReaderFontFamily.system,
              ),
              fontScale: row.fontScale.clamp(0.8, 1.6),
              lineHeight: row.lineHeight.clamp(1.3, 2.2),
              contentWidth: row.contentWidth.clamp(480, 1000),
              theme: _enumOrDefault(
                ReaderThemePreference.values,
                row.theme,
                ReaderThemePreference.system,
              ),
            ),
    );
  }

  @override
  Future<void> saveSettings(
    ReaderSettings settings, {
    required DateTime updatedAt,
  }) {
    return database
        .into(database.readerSettingsRows)
        .insertOnConflictUpdate(
          ReaderSettingsRowsCompanion.insert(
            id: rowId,
            fontFamily: Value<String>(settings.fontFamily.name),
            fontScale: Value<double>(settings.fontScale),
            lineHeight: Value<double>(settings.lineHeight),
            contentWidth: Value<double>(settings.contentWidth),
            theme: Value<String>(settings.theme.name),
            updatedAt: updatedAt,
          ),
        );
  }
}

T _enumOrDefault<T extends Enum>(List<T> values, String name, T fallback) =>
    values.where((value) => value.name == name).firstOrNull ?? fallback;
