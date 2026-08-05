import 'dart:async';
import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_audio/river_audio.dart';
import 'package:river_data/river_data.dart' hide AudioItem, AudioQueueEntry;
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_knowledge/river_knowledge.dart';
import 'package:river_platform/river_platform.dart';
import 'package:river_sync/river_sync.dart';

import '../knowledge/notion_workspace.dart';
import '../preferences/automatic_summaries.dart';
import '../preferences/personalized_articles.dart';
import 'article_summary.dart';

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
    this.readingBehaviorIntroductionEnabled = false,
    BackgroundRefreshScheduler? backgroundRefresh,
    ExternalUriGateway? externalUri,
    AudioEngine? audio,
    AudioPlaybackRepository? audioPlayback,
    AudioSystemSession? audioSystemSession,
    AudioSegmentPrefetcher? audioSegmentPrefetcher,
    PodcastTransferBackend? podcastTransfer,
    NetworkMonitor? network,
    AutomaticSummaryNetworkMonitor? automaticSummaryNetwork,
    OpmlFileGateway? opmlFiles,
    KnowledgeMarkdownFileGateway? knowledgeFiles,
    KnowledgeImageFetcher? knowledgeImages,
    KnowledgeConnector? notionConnector,
    AiHttpTransport? aiTransport,
    AiByokConfigurationVault? aiConfigurations,
    AiLongSummaryCheckpointStore? aiSummaryCheckpoints,
    ArticleSummaryExperience? articleSummaries,
    ReadingBehaviorRepository? readingBehaviorRepository,
    this.notionWorkspace,
    this.syncAccount,
  })  : knowledgeFiles =
            knowledgeFiles ?? const PlatformKnowledgeMarkdownFileGateway(),
        knowledgeImages = knowledgeImages ?? IoKnowledgeImageFetcher(),
        opmlFiles = opmlFiles ?? const PlatformOpmlFileGateway(),
        audio = audio ?? const UnavailableAudioEngine(),
        audioPlayback = audioPlayback ?? DriftAudioPlaybackRepository(database),
        audioSystemSession =
            audioSystemSession ?? const UnavailableAudioSystemSession(),
        network = network ?? const UnknownNetworkMonitor(),
        automaticSummaryNetwork = automaticSummaryNetwork ??
            const UnknownAutomaticSummaryNetworkMonitor(),
        podcastTransfer =
            podcastTransfer ?? const UnavailablePodcastTransferBackend(),
        externalUri = externalUri ?? const UnavailableExternalUriGateway(),
        backgroundRefresh =
            backgroundRefresh ?? PlatformBackgroundRefreshScheduler(),
        aiTransport = aiTransport ?? PackageHttpAiTransport(),
        _database = database {
    jobs = PersistentJobQueue(database);
    feeds = DriftFeedRepository(database);
    knowledge = DriftKnowledgeRepository(database);
    knowledgeExports = notionConnector == null
        ? null
        : DurableKnowledgeExportManager(
            jobs: jobs,
            repository: knowledge,
            connectors: <KnowledgeConnector>[notionConnector],
            clock: clock,
            ids: ids,
          );
    unawaited(knowledgeExports?.start());
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
    readingBehavior =
        readingBehaviorRepository ?? DriftReadingEventRepository(database);
    personalizedArticles = LocalPersonalizedArticleExperience(
      feeds: feeds,
      behavior: readingBehavior,
      clock: clock,
    );
    this.articleSummaries = articleSummaries ??
        ByokArticleSummaryExperience(
          configurations: aiConfigurations ??
              PlatformSecureAiByokConfigurationVault.standard(),
          artifacts: DriftAiArtifactRepository(database),
          checkpoints:
              aiSummaryCheckpoints ?? PlatformAiLongSummaryCheckpointStore(),
          network: this.network,
          clock: clock,
          transport: this.aiTransport,
        );
    automaticSummaryRepository = DriftAutomaticSummaryRepository(database);
    automaticSummaries = DurableAutomaticSummaryManager(
      jobs: jobs,
      repository: automaticSummaryRepository,
      loadArticle: (articleId) => feeds.watchArticle(articleId).first,
      summaries: this.articleSummaries,
      network: this.automaticSummaryNetwork,
      clock: clock,
      ids: ids,
      extractor: fullTextExtractor,
    );
    annotations = DriftArticleAnnotationRepository(database);
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
    final externalUri = UrlLauncherExternalUriGateway();
    KnowledgeConnector? notionConnector;
    NotionWorkspaceExperience? notionWorkspace;
    const notionBrokerUrl = String.fromEnvironment('RIVER_NOTION_BROKER_URL');
    if (notionBrokerUrl.isNotEmpty && !backgroundExecution) {
      final transport = IoNotionHttpTransport();
      final vault = PlatformSecureNotionAuthorizationVault.standard();
      final broker = HttpNotionOAuthBroker(
        brokerBaseUri: Uri.parse(notionBrokerUrl),
        transport: transport,
      );
      final connector = NotionApiConnector(
        transport: transport,
        vault: vault,
        oauthBroker: broker,
      );
      notionConnector = connector;
      notionWorkspace = LiveNotionWorkspaceExperience(
        vault: vault,
        connection: NotionConnectionController(
          broker: broker,
          vault: vault,
        ),
        targets: connector,
        connector: connector,
        externalUri: externalUri,
        selectionStore: SecureNotionTargetSelectionStore.standard(),
      );
    }
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
      externalUri: externalUri,
      network: ConnectivityNetworkMonitor(),
      automaticSummaryNetwork: ConnectivityAutomaticSummaryNetworkMonitor(),
      podcastTransfer: IoPodcastTransferBackend(),
      http: http,
      database: database,
      readingBehaviorIntroductionEnabled: true,
      notionConnector: notionConnector,
      notionWorkspace: notionWorkspace,
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
  final AutomaticSummaryNetworkMonitor automaticSummaryNetwork;
  final PodcastTransferBackend podcastTransfer;
  final HttpPort http;
  final AiHttpTransport aiTransport;
  final bool automaticRefreshEnabled;
  final bool readingBehaviorIntroductionEnabled;
  final OpmlFileGateway opmlFiles;
  final KnowledgeMarkdownFileGateway knowledgeFiles;
  final KnowledgeImageFetcher knowledgeImages;
  final NotionWorkspaceExperience? notionWorkspace;
  final SyncAccountExperience? syncAccount;
  late final PersistentJobQueue jobs;
  late final DriftFeedRepository feeds;
  late final DriftKnowledgeRepository knowledge;
  late final DurableKnowledgeExportManager? knowledgeExports;
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
  late final ReadingBehaviorRepository readingBehavior;
  late final LocalPersonalizedArticleExperience personalizedArticles;
  late final DriftAutomaticSummaryRepository automaticSummaryRepository;
  late final DurableAutomaticSummaryManager automaticSummaries;
  late final DriftArticleAnnotationRepository annotations;
  late final DriftAudioQueueRepository audioQueueRepository;
  late final PersistentAudioQueue audioQueue;
  late final AudioPlaybackController audioController;
  late final AudioQueuePlaybackCoordinator audioQueuePlayer;
  late final ArticleSummaryExperience articleSummaries;
  final RiverDatabase _database;

  Future<void> close() async {
    await knowledgeExports?.close();
    await notionWorkspace?.close();
    await audioQueuePlayer.dispose();
    await audioController.dispose();
    await automaticSummaries.close();
    await audioSystemSession.dispose();
    await audio.dispose();
    await podcastDownloads.close();
    await offlineArticles.close();
    await feedRefreshCoordinator.close();
    final httpPort = http;
    if (httpPort is BoundedHttpPort) {
      httpPort.close();
    }
    final aiHttp = aiTransport;
    if (aiHttp is PackageHttpAiTransport) {
      aiHttp.close();
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
