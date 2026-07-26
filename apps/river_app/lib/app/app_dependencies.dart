import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_platform/river_platform.dart';

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
    NetworkMonitor? network,
    OpmlFileGateway? opmlFiles,
  })  : opmlFiles = opmlFiles ?? const PlatformOpmlFileGateway(),
        audio = audio ?? const UnavailableAudioEngine(),
        audioPlayback = audioPlayback ?? DriftAudioPlaybackRepository(database),
        audioSystemSession =
            audioSystemSession ?? const UnavailableAudioSystemSession(),
        network = network ?? const UnknownNetworkMonitor(),
        externalUri = externalUri ?? const UnavailableExternalUriGateway(),
        backgroundRefresh =
            backgroundRefresh ?? PlatformBackgroundRefreshScheduler(),
        _database = database {
    jobs = PersistentJobQueue(database);
    feeds = DriftFeedRepository(database);
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
    audioController = AudioPlaybackController(
      engine: this.audio,
      repository: this.audioPlayback,
      systemSession: this.audioSystemSession,
      clock: clock,
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
        : SystemTtsAudioEngine();
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
  final HttpPort http;
  final bool automaticRefreshEnabled;
  final OpmlFileGateway opmlFiles;
  late final PersistentJobQueue jobs;
  late final DriftFeedRepository feeds;
  late final DurableOfflineArticleManager offlineArticles;
  late final FeedRefreshService feedRefresh;
  late final FeedRefreshCoordinator feedRefreshCoordinator;
  late final FeedDiscoveryService feedDiscovery;
  late final SubscriptionOrganizerService subscriptionOrganizer;
  late final DriftReaderSettingsRepository readerSettings;
  late final AudioPlaybackController audioController;
  final RiverDatabase _database;

  Future<void> close() async {
    await audioController.dispose();
    await audioSystemSession.dispose();
    await audio.dispose();
    await offlineArticles.close();
    await feedRefreshCoordinator.close();
    final httpPort = http;
    if (httpPort is BoundedHttpPort) {
      httpPort.close();
    }
    await _database.close();
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
