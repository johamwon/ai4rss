import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart' as domain;

import 'database.dart';

final class DriftAudioPlaybackRepository
    implements domain.AudioPlaybackRepository {
  const DriftAudioPlaybackRepository(this.database);

  final RiverDatabase database;

  @override
  Future<domain.AudioPlaybackSnapshot?> read(String itemId) async {
    final query = database.select(database.audioItems)
      ..where((table) => table.id.equals(itemId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final kind = domain.AudioKind.values
        .where((candidate) => candidate.name == row.kind)
        .firstOrNull;
    final sourceUri = Uri.tryParse(row.sourceUri);
    if (kind == null ||
        sourceUri == null ||
        !sourceUri.hasScheme ||
        row.title.trim().isEmpty) {
      return null;
    }

    final settings = domain.AudioPlaybackSettings(
      rate: row.playbackRate.clamp(0.5, 3).toDouble(),
      pitch: row.pitch.clamp(0.5, 2).toDouble(),
      voiceId: _nonEmpty(row.voiceId),
      languageTag: _nonEmpty(row.languageTag),
    );
    final item = domain.AudioItem(
      id: row.id,
      kind: kind,
      title: row.title,
      sourceUri: sourceUri,
    );
    if (kind == domain.AudioKind.articleTts) {
      final segmentIndex = row.segmentIndex;
      final characterOffset = row.characterOffset;
      final contentRevision = _nonEmpty(row.contentRevision);
      if (segmentIndex == null ||
          segmentIndex < 0 ||
          characterOffset == null ||
          characterOffset < 0 ||
          contentRevision == null) {
        return null;
      }
      return domain.AudioPlaybackSnapshot(
        item: item,
        position: domain.AudioPlaybackPosition.speech(
          segmentIndex: segmentIndex,
          characterOffset: characterOffset,
        ),
        settings: settings,
        contentRevision: contentRevision,
        updatedAt: row.updatedAt.toUtc(),
      );
    }

    return domain.AudioPlaybackSnapshot(
      item: item,
      position: domain.AudioPlaybackPosition.media(
        Duration(milliseconds: row.positionMs.clamp(0, 1 << 53)),
      ),
      settings: settings,
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  @override
  Future<void> save(domain.AudioPlaybackSnapshot snapshot) async {
    final existing = await (database.select(
      database.audioItems,
    )..where((table) => table.id.equals(snapshot.item.id))).getSingleOrNull();
    final isSpeech = snapshot.position.isSpeech;
    await database
        .into(database.audioItems)
        .insertOnConflictUpdate(
          AudioItemsCompanion.insert(
            id: snapshot.item.id,
            kind: snapshot.item.kind.name,
            title: snapshot.item.title,
            sourceUri: snapshot.item.sourceUri.toString(),
            positionMs: Value<int>(
              snapshot.position.mediaPosition?.inMilliseconds ?? 0,
            ),
            segmentIndex: Value<int?>(
              isSpeech ? snapshot.position.segmentIndex : null,
            ),
            characterOffset: Value<int?>(
              isSpeech ? snapshot.position.characterOffset : null,
            ),
            contentRevision: Value<String?>(snapshot.contentRevision),
            playbackRate: Value<double>(snapshot.settings.rate),
            pitch: Value<double>(snapshot.settings.pitch),
            voiceId: Value<String?>(snapshot.settings.voiceId),
            languageTag: Value<String?>(snapshot.settings.languageTag),
            createdAt: existing?.createdAt ?? snapshot.updatedAt,
            updatedAt: snapshot.updatedAt,
          ),
        );
  }

  @override
  Future<void> clear(String itemId) async {
    await (database.delete(
      database.audioItems,
    )..where((table) => table.id.equals(itemId))).go();
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
