import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart' hide AudioItem;
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  late RiverDatabase database;
  late DriftAudioPlaybackRepository repository;

  setUp(() {
    database = RiverDatabase.inMemory();
    repository = DriftAudioPlaybackRepository(database);
  });

  tearDown(() => database.close());

  test('article speech position and settings round trip', () async {
    final updatedAt = DateTime.utc(2026, 7, 26, 14, 30);
    await repository.save(
      AudioPlaybackSnapshot(
        item: _articleItem,
        position: const AudioPlaybackPosition.speech(
          segmentIndex: 7,
          characterOffset: 23,
        ),
        settings: const AudioPlaybackSettings(
          rate: 1.5,
          pitch: 0.8,
          voiceId: 'voice-1',
          languageTag: 'zh-CN',
        ),
        contentRevision: 'sha256:revision-1',
        updatedAt: updatedAt,
      ),
    );

    final restored = await repository.read(_articleItem.id);
    expect(restored?.item.kind, AudioKind.articleTts);
    expect(restored?.item.sourceUri, _articleItem.sourceUri);
    expect(restored?.position.segmentIndex, 7);
    expect(restored?.position.characterOffset, 23);
    expect(restored?.settings.rate, 1.5);
    expect(restored?.settings.pitch, 0.8);
    expect(restored?.settings.voiceId, 'voice-1');
    expect(restored?.settings.languageTag, 'zh-CN');
    expect(restored?.contentRevision, 'sha256:revision-1');
    expect(restored?.updatedAt, updatedAt);
  });

  test('podcast duration position uses the same persistent record', () async {
    final item = AudioItem(
      id: 'podcast-1',
      kind: AudioKind.podcastEpisode,
      title: 'Episode',
      sourceUri: Uri.parse('https://example.test/episode.mp3'),
    );
    await repository.save(
      AudioPlaybackSnapshot(
        item: item,
        position: AudioPlaybackPosition.media(
          const Duration(minutes: 12, seconds: 34),
        ),
        settings: const AudioPlaybackSettings(rate: 1.25),
        updatedAt: DateTime.utc(2026, 7, 26),
      ),
    );

    final restored = await repository.read(item.id);
    expect(
      restored?.position.mediaPosition,
      const Duration(minutes: 12, seconds: 34),
    );
    expect(restored?.contentRevision, isNull);
    expect(restored?.settings.rate, 1.25);
  });

  test('saved playback survives restart and can be cleared', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('river-audio-');
    final file = File('${directory.path}${Platform.pathSeparator}river.db');
    database = RiverDatabase(NativeDatabase(file));
    await DriftAudioPlaybackRepository(database).save(
      AudioPlaybackSnapshot(
        item: _articleItem,
        position: const AudioPlaybackPosition.speech(
          segmentIndex: 2,
          characterOffset: 9,
        ),
        settings: const AudioPlaybackSettings(rate: 2),
        contentRevision: 'sha256:restart',
        updatedAt: DateTime.utc(2026, 7, 26),
      ),
    );
    await database.close();

    database = RiverDatabase(NativeDatabase(file));
    repository = DriftAudioPlaybackRepository(database);
    expect((await repository.read(_articleItem.id))?.position.segmentIndex, 2);
    await repository.clear(_articleItem.id);
    expect(await repository.read(_articleItem.id), isNull);

    await database.close();
    await directory.delete(recursive: true);
    database = RiverDatabase.inMemory();
  });

  test('unsafe stored values are bounded or rejected', () async {
    await database.customStatement('''
      INSERT INTO audio_items (
        id, kind, title, source_uri, position_ms, segment_index,
        character_offset, content_revision, playback_rate, pitch,
        voice_id, language_tag, created_at, updated_at
      ) VALUES (
        'bounded', 'articleTts', 'Bounded', 'river://article/bounded',
        0, 1, 2, 'revision', 99, 0.1, '', '',
        1784995200, 1784995200
      )
    ''');
    await database.customStatement('''
      INSERT INTO audio_items (
        id, kind, title, source_uri, position_ms, playback_rate,
        created_at, updated_at
      ) VALUES (
        'invalid', 'articleTts', 'Invalid', 'river://article/invalid',
        0, 1, 1784995200, 1784995200
      )
    ''');

    final bounded = await repository.read('bounded');
    expect(bounded?.settings.rate, 3);
    expect(bounded?.settings.pitch, 0.5);
    expect(bounded?.settings.voiceId, isNull);
    expect(bounded?.settings.languageTag, isNull);
    expect(await repository.read('invalid'), isNull);
  });
}

final _articleItem = AudioItem(
  id: 'article-1',
  kind: AudioKind.articleTts,
  title: 'Article',
  sourceUri: Uri.parse('river://article/1'),
);
