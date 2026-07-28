import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  test(
    'network reconnection expedites and resumes a partial download',
    () async {
      final database = RiverDatabase(NativeDatabase.memory());
      final podcasts = DriftPodcastRepository(database);
      await _seedPodcast(podcasts);
      final network = _FakeNetwork(NetworkAvailability.online);
      final backend = _FakeBackend(<_TransferOperation>[
        (request, onProgress) async {
          expect(request.resumeFromBytes, 0);
          await onProgress(
            const PodcastTransferProgress(
              partialPath: 'episode.part',
              downloadedBytes: 4,
              totalBytes: 8,
              etag: '"v1"',
            ),
          );
          return const PodcastTransferFailure(
            code: PodcastDownloadFailureCode.network,
            retryable: true,
            partialPath: 'episode.part',
            downloadedBytes: 4,
            totalBytes: 8,
            etag: '"v1"',
          );
        },
        (request, onProgress) async {
          expect(request.resumeFromBytes, 4);
          expect(request.partialPath, 'episode.part');
          expect(request.etag, '"v1"');
          return const PodcastTransferSuccess(
            availablePath: 'episode.mp3',
            downloadedBytes: 8,
            totalBytes: 8,
            etag: '"v1"',
          );
        },
      ]);
      final manager = _manager(database, podcasts, backend, network);
      addTearDown(() async {
        await manager.close();
        await network.close();
        await database.close();
      });

      await manager.start();
      await manager.enqueue('episode-1');
      await _waitFor(
        manager,
        PodcastDownloadPhase.queued,
        failureCode: PodcastDownloadFailureCode.network,
      );

      final available = manager
          .watch('episode-1')
          .firstWhere((state) => state.phase == PodcastDownloadPhase.available);
      network.emit(NetworkAvailability.offline);
      network.emit(NetworkAvailability.online);

      expect((await available).downloadedBytes, 8);
      expect(backend.calls, 2);
    },
  );

  test('storage full is terminal and keeps resumable partial state', () async {
    final database = RiverDatabase(NativeDatabase.memory());
    final podcasts = DriftPodcastRepository(database);
    await _seedPodcast(podcasts);
    final network = _FakeNetwork(NetworkAvailability.online);
    final backend = _FakeBackend(<_TransferOperation>[
      (_, _) async => const PodcastTransferFailure(
        code: PodcastDownloadFailureCode.storageFull,
        retryable: false,
        partialPath: 'episode.part',
        downloadedBytes: 4,
        totalBytes: 8,
      ),
    ]);
    final manager = _manager(database, podcasts, backend, network);
    addTearDown(() async {
      await manager.close();
      await network.close();
      await database.close();
    });

    await manager.start();
    await manager.enqueue('episode-1');
    final state = await _waitFor(manager, PodcastDownloadPhase.failed);

    expect(state.phase, PodcastDownloadPhase.failed);
    expect(state.failureCode, PodcastDownloadFailureCode.storageFull);
    expect(state.partialPath, 'episode.part');
    expect(state.downloadedBytes, 4);
    expect(backend.discarded, isEmpty);
  });

  test('corrupt media is rejected and its partial file is discarded', () async {
    final database = RiverDatabase(NativeDatabase.memory());
    final podcasts = DriftPodcastRepository(database);
    await _seedPodcast(podcasts);
    final network = _FakeNetwork(NetworkAvailability.online);
    final backend = _FakeBackend(<_TransferOperation>[
      (_, _) async => const PodcastTransferFailure(
        code: PodcastDownloadFailureCode.corruptMedia,
        retryable: false,
        partialPath: 'corrupt.part',
        downloadedBytes: 8,
        totalBytes: 8,
        discardPartial: true,
      ),
    ]);
    final manager = _manager(database, podcasts, backend, network);
    addTearDown(() async {
      await manager.close();
      await network.close();
      await database.close();
    });

    await manager.start();
    await manager.enqueue('episode-1');
    final state = await _waitFor(manager, PodcastDownloadPhase.failed);

    expect(state.phase, PodcastDownloadPhase.failed);
    expect(state.failureCode, PodcastDownloadFailureCode.corruptMedia);
    expect(state.partialPath, isNull);
    expect(state.downloadedBytes, 0);
    expect(backend.discarded, <String>['corrupt.part']);
  });

  test('remove discards the file and permits a clean redownload', () async {
    final database = RiverDatabase(NativeDatabase.memory());
    final podcasts = DriftPodcastRepository(database);
    await _seedPodcast(podcasts);
    final network = _FakeNetwork(NetworkAvailability.online);
    final backend = _FakeBackend(<_TransferOperation>[
      (_, _) async => const PodcastTransferSuccess(
        availablePath: 'first.mp3',
        downloadedBytes: 8,
        totalBytes: 8,
      ),
      (_, _) async => const PodcastTransferSuccess(
        availablePath: 'second.mp3',
        downloadedBytes: 8,
        totalBytes: 8,
      ),
    ]);
    final manager = _manager(database, podcasts, backend, network);
    addTearDown(() async {
      await manager.close();
      await network.close();
      await database.close();
    });

    await manager.start();
    await manager.enqueue('episode-1');
    await _waitFor(manager, PodcastDownloadPhase.available);
    await manager.remove('episode-1');
    expect(
      (await manager.status('episode-1')).phase,
      PodcastDownloadPhase.notDownloaded,
    );

    await manager.enqueue('episode-1');

    expect(
      (await _waitFor(manager, PodcastDownloadPhase.available)).availablePath,
      'second.mp3',
    );
    expect(backend.discarded, contains('first.mp3'));
    expect(backend.calls, 2);
  });

  test(
    'missing local media clears stale availability for streaming fallback',
    () async {
      final database = RiverDatabase(NativeDatabase.memory());
      final podcasts = DriftPodcastRepository(database);
      await _seedPodcast(podcasts);
      final network = _FakeNetwork(NetworkAvailability.online);
      final backend = _FakeBackend(<_TransferOperation>[
        (_, _) async => const PodcastTransferSuccess(
          availablePath: 'missing.mp3',
          downloadedBytes: 8,
          totalBytes: 8,
        ),
      ]);
      final manager = _manager(database, podcasts, backend, network);
      addTearDown(() async {
        await manager.close();
        await network.close();
        await database.close();
      });

      await manager.start();
      await manager.enqueue('episode-1');
      await _waitFor(manager, PodcastDownloadPhase.available);
      backend.available = false;

      final state = await manager.status('episode-1');

      expect(state.phase, PodcastDownloadPhase.notDownloaded);
      expect(state.playbackUri, isNull);
    },
  );

  test('cold restart recovers an unexpired lease and resumes bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'river-podcast-download-',
    );
    final file = File('${directory.path}${Platform.pathSeparator}river.sqlite');
    var database = RiverDatabase(NativeDatabase(file));
    var podcasts = DriftPodcastRepository(database);
    await _seedPodcast(podcasts);
    final store = DriftPodcastDownloadStore(database);
    final jobs = PersistentJobQueue(database);
    final now = DateTime.utc(2026, 7, 26, 8);
    await store.progress(
      episodeId: 'episode-1',
      sourceUri: Uri.parse('https://media.example.test/episode.mp3'),
      phase: PodcastDownloadPhase.downloading,
      partialPath: 'episode.part',
      downloadedBytes: 4,
      totalBytes: 8,
      etag: '"v1"',
      updatedAt: now,
    );
    await jobs.enqueue(
      NewDurableJob(
        id: 'download-job-1',
        type: DurablePodcastDownloadManager.jobType,
        idempotencyKey: 'podcast-download:v1:episode-1',
        payloadJson: '{"episodeId":"episode-1"}',
        availableAt: now,
      ),
      now,
    );
    await jobs.claimNext(
      now: now,
      leaseDuration: const Duration(hours: 1),
      type: DurablePodcastDownloadManager.jobType,
    );
    await database.close();

    database = RiverDatabase(NativeDatabase(file));
    podcasts = DriftPodcastRepository(database);
    final network = _FakeNetwork(NetworkAvailability.online);
    final backend = _FakeBackend(<_TransferOperation>[
      (request, _) async {
        expect(request.resumeFromBytes, 4);
        expect(request.partialPath, 'episode.part');
        return const PodcastTransferSuccess(
          availablePath: 'episode.mp3',
          downloadedBytes: 8,
          totalBytes: 8,
          etag: '"v1"',
        );
      },
    ]);
    final manager = _manager(database, podcasts, backend, network);

    await manager.start();

    expect(
      (await manager.status('episode-1')).phase,
      PodcastDownloadPhase.available,
    );
    expect(backend.calls, 1);
    await manager.close();
    await network.close();
    await database.close();
    await directory.delete(recursive: true);
  });
}

Future<PodcastDownloadState> _waitFor(
  PodcastDownloadManager manager,
  PodcastDownloadPhase phase, {
  String? failureCode,
}) => manager
    .watch('episode-1')
    .firstWhere(
      (state) =>
          state.phase == phase &&
          (failureCode == null || state.failureCode == failureCode),
    );

DurablePodcastDownloadManager _manager(
  RiverDatabase database,
  DriftPodcastRepository podcasts,
  PodcastTransferBackend backend,
  NetworkMonitor network,
) => DurablePodcastDownloadManager(
  jobs: PersistentJobQueue(database),
  store: DriftPodcastDownloadStore(database),
  loadEpisode: podcasts.findEpisodeById,
  backend: backend,
  network: network,
  clock: const _Clock(),
  ids: _Ids(),
);

Future<void> _seedPodcast(DriftPodcastRepository repository) {
  final now = DateTime.utc(2026, 7, 26, 8);
  return repository.applyRefresh(
    show: PodcastShowRecord(
      id: 'show-1',
      canonicalFeedUrl: Uri.parse('https://podcast.example.test/feed.xml'),
      title: 'River Show',
      explicitRating: PodcastExplicitRating.clean,
      defaultPlaybackRate: 1,
      downloadPolicy: PodcastDownloadPolicy.manual,
      lastRefreshedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    episodeUpserts: <PodcastEpisodeRecord>[
      PodcastEpisodeRecord(
        id: 'episode-1',
        showId: 'show-1',
        externalId: 'guid-1',
        title: 'Episode',
        mediaUrl: Uri.parse('https://media.example.test/episode.mp3'),
        mediaMimeType: 'audio/mpeg',
        mediaLengthBytes: 8,
        explicitRating: PodcastExplicitRating.clean,
        episodeType: PodcastEpisodeType.full,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

typedef _TransferOperation =
    Future<PodcastTransferResult> Function(
      PodcastTransferRequest request,
      Future<void> Function(PodcastTransferProgress progress) onProgress,
    );

final class _FakeBackend implements PodcastTransferBackend {
  _FakeBackend(this.operations);

  final List<_TransferOperation> operations;
  final List<String> discarded = <String>[];
  var calls = 0;
  var available = true;

  @override
  Future<void> discard({String? partialPath, String? availablePath}) async {
    if (partialPath != null) discarded.add(partialPath);
    if (availablePath != null) discarded.add(availablePath);
  }

  @override
  Future<bool> isAvailable(String availablePath) async => available;

  @override
  Future<PodcastTransferResult> transfer(
    PodcastTransferRequest request, {
    required Future<void> Function(PodcastTransferProgress progress) onProgress,
  }) {
    final operation = operations[calls];
    calls += 1;
    return operation(request, onProgress);
  }
}

final class _FakeNetwork implements NetworkMonitor {
  _FakeNetwork(this.current);

  NetworkAvailability current;
  final StreamController<NetworkAvailability> _changes =
      StreamController<NetworkAvailability>();

  @override
  Future<NetworkAvailability> check() async => current;

  @override
  Stream<NetworkAvailability> get changes => _changes.stream;

  void emit(NetworkAvailability value) {
    current = value;
    _changes.add(value);
  }

  Future<void> close() => _changes.close();
}

final class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 26, 8);
}

final class _Ids implements IdGenerator {
  var value = 0;

  @override
  String next() => 'podcast-job-${++value}';
}
