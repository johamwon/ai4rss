import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  test('v1 fixture migrates to v3 without losing article state', () async {
    final fixture = await _materializeFixture('v001_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.title, 'River v1 migration fixture');
    expect(article.feedSummary, 'Existing preview survives migration');
    expect(article.starred, isTrue);
    expect(article.feedContentHtml, isNull);
    expect(await _userVersion(migrated), 3);
    expect(
      await DriftReaderSettingsRepository(migrated).watchSettings().first,
      const ReaderSettings(),
    );
  });

  test('interrupted v2 column addition retries idempotently', () async {
    final fixture = await _materializeFixture('v001_populated.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('ALTER TABLE articles ADD COLUMN feed_content_html TEXT')
      ..execute(
        "UPDATE articles SET feed_content_html = '<p>Recovered body</p>'",
      )
      ..close();
    final recovered = await _openFixture(fixture);

    final article = await recovered.select(recovered.articles).getSingle();
    expect(article.feedContentHtml, '<p>Recovered body</p>');
    expect(await _userVersion(recovered), 3);
  });

  test('v2 fixture creates the settings table and preserves article', () async {
    final fixture = await _materializeFixture('v002_populated.sql');
    final migrated = await _openFixture(fixture);

    final article = await migrated.select(migrated.articles).getSingle();
    expect(article.feedContentHtml, '<p>Current immediate body</p>');
    expect(await _userVersion(migrated), 3);
    expect(
      await DriftReaderSettingsRepository(migrated).watchSettings().first,
      const ReaderSettings(),
    );
  });

  test('interrupted v3 table creation retries idempotently', () async {
    final fixture = await _materializeFixture('v002_populated.sql');
    final raw = sqlite.sqlite3.open(fixture.path);
    raw
      ..execute('''
        CREATE TABLE reader_settings_rows (
          id TEXT NOT NULL PRIMARY KEY,
          font_family TEXT NOT NULL DEFAULT 'system',
          font_scale REAL NOT NULL DEFAULT 1,
          line_height REAL NOT NULL DEFAULT 1.75,
          content_width REAL NOT NULL DEFAULT 760,
          theme TEXT NOT NULL DEFAULT 'system',
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        INSERT INTO reader_settings_rows VALUES
        ('default', 'serif', 1.3, 1.9, 700, 'dark', 1784390400)
      ''')
      ..close();
    final recovered = await _openFixture(fixture);

    final settings = await DriftReaderSettingsRepository(
      recovered,
    ).watchSettings().first;
    expect(settings.fontFamily, ReaderFontFamily.serif);
    expect(settings.fontScale, 1.3);
    expect(settings.theme, ReaderThemePreference.dark);
    expect(await _userVersion(recovered), 3);
  });

  test('current v3 fixture opens with article and settings intact', () async {
    final fixture = await _materializeFixture('v003_populated.sql');
    final current = await _openFixture(fixture);

    final article = await current.select(current.articles).getSingle();
    expect(article.scrollDepth, 0.63);
    expect(article.starred, isTrue);
    final settings = await DriftReaderSettingsRepository(
      current,
    ).watchSettings().first;
    expect(settings.fontFamily, ReaderFontFamily.serif);
    expect(settings.contentWidth, 680);
    expect(settings.theme, ReaderThemePreference.dark);
    expect(await _userVersion(current), 3);
  });
}

Future<File> _materializeFixture(String name) async {
  final directory = await Directory.systemTemp.createTemp('river-migration-');
  final file = File('${directory.path}${Platform.pathSeparator}fixture.db');
  final source = File('../../fixtures/migrations/$name').readAsStringSync();
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute(source);
  } finally {
    raw.close();
  }
  return file;
}

Future<RiverDatabase> _openFixture(File fixture) async {
  final database = RiverDatabase(NativeDatabase(fixture));
  await database.verifyReady();
  addTearDown(() async {
    await database.close();
    if (fixture.parent.existsSync()) {
      await fixture.parent.delete(recursive: true);
    }
  });
  return database;
}

Future<int> _userVersion(RiverDatabase database) async =>
    (await database.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );
