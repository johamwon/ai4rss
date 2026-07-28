import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_data/river_data.dart' hide AudioItem, AudioQueueEntry;
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_platform/river_platform.dart';
import 'package:river_sync/river_sync.dart';

final class AppDependencies {
  AppDependencies({
    required this.clock,
    required this.ids,
    required this.fullTextExtractor,
    required this.platform,
    required this.share,
    required this.http,
    required RiverDatabase database,
    this.automaticRefreshEnabled = true,
    BackgroundRefreshScheduler? backgroundRefresh,
    ExternalUriGateway? externalUri,
    AudioEngine? audio,
    AudioPlaybackRepository? audioPlayback,
    AudioSystemSession? audioSystemSession,
    AudioSegmentPrefetcher? audioSegmentPrefetcher,
    PodcastTransferBackend? podcastTransfer,
    NetworkMonitor? network,
    OpmlFileGateway? opmlFiles,
    this.syncAccount,
  })  : opmlFiles = opmlFiles ?? const PlatformOpmlFileGateway(),
        audio = audio ?? const UnavailableAudioEngine(),
        audioPlayback = audioPlayback ?? DriftAudioPlaybackRepository(database),
        audioSystemSession =
            audioSystemSession ?? const UnavailableAudioSystemSession(),
        network = network ?? const UnknownNetworkMonitor(),
        podcastTransfer =
            podcastTransfer ?? const UnavailablePodcastTransferBackend(),
        externalUri = externalUri ?? const UnavailableExternalUriGateway(),
        backgroundRefresh =
            backgroundRefresh ?? PlatformBackgroundRefreshScheduler(),
        _database = database {
    jobs = PersistentJobQueue(database);
    feeds = DriftFeedRepository(database);
    podcasts = DriftPodcastRepository(database);
    podcastDownloadStore = DriftPodcastDownloadStore(database);
    podcastDownloads = DurablePodcastDownloadManager(
      jobs: jobs,
      store: podcastDownloadStore,
      loadEpisode: podcasts.findEpisodeById,
      backend: this.podcastTransfer,
      network: this.network,
      clock: clock,
      ids: ids,
    );
    podcastRefresh = PodcastRefreshService(
      http: http,
      repository: podcasts,
      clock: clock,
      ids: ids,
    );
    podcastPolicies = PodcastDownloadPolicyService(
      repository: podcasts,
      downloads: podcastDownloads,
    );
    offlineArticles = DurableOfflineArticleManager(
      jobs: jobs,
      loadArticle: (articleId) => feeds.watchArticle(articleId).first,
      extractor: fullTextExtractor,
      network: this.network,
      clock: clock,
      ids: ids,
    );
    feedRefresh = FeedRefreshService(
      http: http,
      repository: feeds,
      clock: clock,
      ids: ids,
    );
    feedRefreshCoordinator = FeedRefreshCoordinator(
      jobs: jobs,
      refresh: feedRefresh.subscribeOrRefresh,
      clock: clock,
      ids: ids,
    );
    feedDiscovery = FeedDiscoveryService(
      http: http,
      feedRefresh: feedRefresh,
    );
    subscriptionOrganizer = SubscriptionOrganizerService(
      repository: feeds,
      clock: clock,
      ids: ids,
    );
    readerSettings = DriftReaderSettingsRepository(database);
    audioQueueRepository = DriftAudioQueueRepository(database);
    audioQueue = PersistentAudioQueue(
      repository: audioQueueRepository,
      clock: clock,
    );
    audioController = AudioPlaybackController(
      engine: this.audio,
      repository: this.audioPlayback,
      systemSession: this.audioSystemSession,
      segmentPrefetcher:
          audioSegmentPrefetcher ?? const UnavailableAudioSegmentPrefetcher(),
      clock: clock,
    );
    audioQueuePlayer = AudioQueuePlaybackCoordinator(
      queue: audioQueue,
      playback: audioController,
      resolve: _resolveQueuedAudio,
    );
  }

  static Future<AppDependencies> production({
    bool backgroundExecution = false,
  }) async {
    final database = RiverDatabase(
      driftDatabase(
        name: 'river',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      ),
    );
    await database.verifyReady();
    final http = BoundedHttpPort.standard();
    const clock = SystemClock();
    final layeredExtractor = backgroundExecution
        ? const LayeredFullTextExtractor()
        : LayeredFullTextExtractor.withDynamicPageRenderer(
            InAppWebViewDynamicPageRenderer(),
          );
    final audio = backgroundExecution
        ? const UnavailableAudioEngine()
        : RoutedAudioEngine(
            articleEngine: SystemTtsAudioEngine(),
            podcastEngine: PodcastAudioEngine(),
          );
    final audioSystemSession = backgroundExecution
        ? const UnavailableAudioSystemSession()
        : await SystemAudioSession.create();
    return AppDependencies(
      clock: clock,
      ids: SecureIdGenerator(),
      fullTextExtractor: CachedFullTextExtractor(
        delegate: HttpLoadingFullTextExtractor(
          http: http,
          delegate: layeredExtractor,
        ),
        cache: DriftExtractionCache(database),
        clock: clock,
        extractorVersions: layeredExtractor.extractorVersions,
      ),
      platform: const MethodChannelRiverPlatform(),
      share: SharePlusGateway(),
      audio: audio,
      audioSystemSession: audioSystemSession,
      externalUri: UrlLauncherExternalUriGateway(),
      network: ConnectivityNetworkMonitor(),
      podcastTransfer: IoPodcastTransferBackend(),
      http: http,
      database: database,
    );
  }

  final Clock clock;
  final IdGenerator ids;
  final FullTextExtractor fullTextExtractor;
  final RiverPlatformBridge platform;
  final BackgroundRefreshScheduler backgroundRefresh;
  final ShareGateway share;
  final AudioEngine audio;
  final AudioPlaybackRepository audioPlayback;
  final AudioSystemSession audioSystemSession;
  final ExternalUriGateway externalUri;
  final NetworkMonitor network;
  final PodcastTransferBackend podcastTransfer;
  final HttpPort http;
  final bool automaticRefreshEnabled;
  final OpmlFileGateway opmlFiles;
  final SyncAccountExperience? syncAccount;
  late final PersistentJobQueue jobs;
  late final DriftFeedRepository feeds;
  late final DriftPodcastRepository podcasts;
  late final DriftPodcastDownloadStore podcastDownloadStore;
  late final DurablePodcastDownloadManager podcastDownloads;
  late final PodcastRefreshService podcastRefresh;
  late final PodcastDownloadPolicyService podcastPolicies;
  late final DurableOfflineArticleManager offlineArticles;
  late final FeedRefreshService feedRefresh;
  late final FeedRefreshCoordinator feedRefreshCoordinator;
  late final FeedDiscoveryService feedDiscovery;
  late final SubscriptionOrganizerService subscriptionOrganizer;
  late final DriftReaderSettingsRepository readerSettings;
  late final DriftAudioQueueRepository audioQueueRepository;
  late final PersistentAudioQueue audioQueue;
  late final AudioPlaybackController audioController;
  late final AudioQueuePlaybackCoordinator audioQueuePlayer;
  final RiverDatabase _database;

  Future<void> close() async {
    await audioQueuePlayer.dispose();
    await audioController.dispose();
    await audioSystemSession.dispose();
    await audio.dispose();
    await podcastDownloads.close();
    await offlineArticles.close();
    await feedRefreshCoordinator.close();
    final httpPort = http;
    if (httpPort is BoundedHttpPort) {
      httpPort.close();
    }
    await _database.close();
  }

  Future<ResolvedAudioQueueItem?> _resolveQueuedAudio(
    AudioQueueEntry entry,
  ) async {
    switch (entry.item.kind) {
      case AudioKind.articleTts:
        final detail = await feeds.watchArticle(entry.item.id).first;
        if (detail == null) return null;
        String text;
        String revision;
        final cached = detail.content;
        if (cached != null && cached.isReadable) {
          text = cached.plainText.trim();
          revision = cached.contentHash ??
              '${cached.extractorName}@${cached.extractorVersion}:'
                  '${cached.extractedAt.microsecondsSinceEpoch}';
        } else {
          final assessed = const FeedContentAssessor().assess(
            contentHtml: detail.feedContentHtml,
            summary: detail.summary,
            sourceUri: detail.canonicalUrl,
          );
          text = assessed.content.plainText.trim();
          revision = 'feed:${text.hashCode}';
        }
        if (text.isEmpty || revision != entry.contentRevision) return null;
        final segments = const ArticleSpeechSegmenter().segment(text);
        if (segments.isEmpty) return null;
        return ResolvedAudioQueueItem(
          request: AudioLoadRequest(
            item: AudioItem(
              id: detail.id,
              kind: AudioKind.articleTts,
              title: detail.title,
              sourceUri: detail.canonicalUrl,
            ),
            speechSegments: segments,
            contentRevision: revision,
          ),
        );
      case AudioKind.podcastEpisode:
        final episode = await podcasts.findEpisodeById(entry.item.id);
        if (episode == null) return null;
        final show = await podcasts.findShowById(episode.showId);
        if (show == null) return null;
        final download = await podcastDownloads.status(episode.id);
        return ResolvedAudioQueueItem(
          request: AudioLoadRequest(
            item: AudioItem(
              id: episode.id,
              kind: AudioKind.podcastEpisode,
              title: episode.title,
              sourceUri: download.playbackUri ?? episode.mediaUrl,
            ),
          ),
          settings: AudioPlaybackSettings(rate: show.defaultPlaybackRate),
        );
    }
  }
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final class SecureIdGenerator implements IdGenerator {
  SecureIdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
