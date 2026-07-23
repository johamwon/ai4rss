import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftReaderSettingsRepository repository;

  setUp(() {
    database = RiverDatabase.inMemory();
    repository = DriftReaderSettingsRepository(database);
  });

  tearDown(() => database.close());

  test('defaults are available before a row exists', () async {
    expect(await repository.watchSettings().first, const ReaderSettings());
  });

  test('save is an idempotent singleton update', () async {
    final settings = const ReaderSettings(
      fontFamily: ReaderFontFamily.serif,
      fontScale: 1.3,
      lineHeight: 1.9,
      contentWidth: 680,
      theme: ReaderThemePreference.dark,
    );
    final updatedAt = DateTime.utc(2026, 7, 19);

    await repository.saveSettings(settings, updatedAt: updatedAt);
    await repository.saveSettings(settings, updatedAt: updatedAt);

    expect(await repository.watchSettings().first, settings);
    expect(
      await database.select(database.readerSettingsRows).get(),
      hasLength(1),
    );
  });

  test('saved settings survive a database restart', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'river-reader-settings-',
    );
    final file = File('${directory.path}${Platform.pathSeparator}river.db');

    database = RiverDatabase(NativeDatabase(file));
    final settings = const ReaderSettings(
      fontFamily: ReaderFontFamily.sansSerif,
      fontScale: 1.2,
      lineHeight: 1.85,
      contentWidth: 720,
      theme: ReaderThemePreference.light,
    );
    await DriftReaderSettingsRepository(
      database,
    ).saveSettings(settings, updatedAt: DateTime.utc(2026, 7, 19));
    await database.close();

    database = RiverDatabase(NativeDatabase(file));
    expect(
      await DriftReaderSettingsRepository(database).watchSettings().first,
      settings,
    );
    await database.close();
    await directory.delete(recursive: true);
    database = RiverDatabase.inMemory();
  });

  test(
    'invalid stored enum and numeric values recover to safe settings',
    () async {
      await database.customStatement('''
      INSERT INTO reader_settings_rows
      (id, font_family, font_scale, line_height, content_width, theme, updated_at)
      VALUES ('default', 'removed-font', 99, 0.1, 5000, 'removed-theme', 0)
    ''');

      final settings = await repository.watchSettings().first;
      expect(settings.fontFamily, ReaderFontFamily.system);
      expect(settings.fontScale, 1.6);
      expect(settings.lineHeight, 1.3);
      expect(settings.contentWidth, 1000);
      expect(settings.theme, ReaderThemePreference.system);
    },
  );
}
