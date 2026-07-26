import 'package:drift/drift.dart';
import 'package:river_domain/river_domain.dart';

import 'database.dart';

final class DriftPodcastDownloadStore {
  const DriftPodcastDownloadStore(this.database);

  final RiverDatabase database;

  Future<PodcastDownloadState?> read(String episodeId) async {
    final row = await (database.select(
      database.podcastDownloads,
    )..where((table) => table.episodeId.equals(episodeId))).getSingleOrNull();
    return row == null ? null : _state(row);
  }

  Future<void> queue({
    required String episodeId,
    required Uri sourceUri,
    required DateTime updatedAt,
    PodcastDownloadState? resume,
  }) => database
      .into(database.podcastDownloads)
      .insertOnConflictUpdate(
        PodcastDownloadsCompanion.insert(
          episodeId: episodeId,
          state: Value<String>(PodcastDownloadPhase.queued.name),
          sourceUrl: Value<String>(sourceUri.toString()),
          partialPath: Value<String?>(resume?.partialPath),
          availablePath: const Value<String?>(null),
          downloadedBytes: Value<int>(resume?.downloadedBytes ?? 0),
          totalBytes: Value<int?>(resume?.totalBytes),
          etag: Value<String?>(resume?.etag),
          failureCode: const Value<String?>(null),
          updatedAt: updatedAt,
        ),
      );

  Future<void> progress({
    required String episodeId,
    required Uri sourceUri,
    required PodcastDownloadPhase phase,
    String? partialPath,
    required int downloadedBytes,
    required DateTime updatedAt,
    int? totalBytes,
    String? etag,
    String? failureCode,
  }) => database
      .into(database.podcastDownloads)
      .insertOnConflictUpdate(
        PodcastDownloadsCompanion.insert(
          episodeId: episodeId,
          state: Value<String>(phase.name),
          sourceUrl: Value<String>(sourceUri.toString()),
          partialPath: Value<String?>(partialPath),
          availablePath: const Value<String?>(null),
          downloadedBytes: Value<int>(downloadedBytes),
          totalBytes: Value<int?>(totalBytes),
          etag: Value<String?>(etag),
          failureCode: Value<String?>(failureCode),
          updatedAt: updatedAt,
        ),
      );

  Future<void> available({
    required String episodeId,
    required Uri sourceUri,
    required String availablePath,
    required int totalBytes,
    required DateTime updatedAt,
    String? etag,
  }) => database
      .into(database.podcastDownloads)
      .insertOnConflictUpdate(
        PodcastDownloadsCompanion.insert(
          episodeId: episodeId,
          state: Value<String>(PodcastDownloadPhase.available.name),
          sourceUrl: Value<String>(sourceUri.toString()),
          partialPath: const Value<String?>(null),
          availablePath: Value<String>(availablePath),
          downloadedBytes: Value<int>(totalBytes),
          totalBytes: Value<int>(totalBytes),
          etag: Value<String?>(etag),
          failureCode: const Value<String?>(null),
          updatedAt: updatedAt,
        ),
      );

  Future<void> failed({
    required String episodeId,
    required Uri sourceUri,
    required String failureCode,
    required DateTime updatedAt,
    String? partialPath,
    int downloadedBytes = 0,
    int? totalBytes,
    String? etag,
  }) => database
      .into(database.podcastDownloads)
      .insertOnConflictUpdate(
        PodcastDownloadsCompanion.insert(
          episodeId: episodeId,
          state: Value<String>(PodcastDownloadPhase.failed.name),
          sourceUrl: Value<String>(sourceUri.toString()),
          partialPath: Value<String?>(partialPath),
          availablePath: const Value<String?>(null),
          downloadedBytes: Value<int>(downloadedBytes),
          totalBytes: Value<int?>(totalBytes),
          etag: Value<String?>(etag),
          failureCode: Value<String>(failureCode),
          updatedAt: updatedAt,
        ),
      );

  Future<PodcastDownloadState?> remove(String episodeId) async {
    return database.transaction(() async {
      final existing = await read(episodeId);
      await (database.delete(
        database.podcastDownloads,
      )..where((table) => table.episodeId.equals(episodeId))).go();
      return existing;
    });
  }
}

PodcastDownloadState _state(PodcastDownload row) => PodcastDownloadState(
  episodeId: row.episodeId,
  phase: PodcastDownloadPhase.values.firstWhere(
    (phase) => phase.name == row.state,
    orElse: () => PodcastDownloadPhase.failed,
  ),
  sourceUri: row.sourceUrl == null ? null : Uri.tryParse(row.sourceUrl!),
  partialPath: row.partialPath,
  availablePath: row.availablePath,
  downloadedBytes: row.downloadedBytes,
  totalBytes: row.totalBytes,
  etag: row.etag,
  failureCode: row.failureCode,
);
