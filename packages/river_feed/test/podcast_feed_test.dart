import 'dart:io';

import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

final class _Clock implements Clock {
  _Clock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _Ids implements IdGenerator {
  var value = 0;

  @override
  String next() => 'river-${++value}';
}

final class _Http implements HttpPort {
  _Http(this.response);

  PortHttpResponse response;
  Map<String, String>? lastHeaders;

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    lastHeaders = Map<String, String>.unmodifiable(headers);
    return response;
  }
}

final class _Repository implements PodcastRepository {
  PodcastShowRecord? show;
  final List<PodcastEpisodeRecord> episodes = <PodcastEpisodeRecord>[];
  List<PodcastEpisodeRecord> lastUpserts = <PodcastEpisodeRecord>[];
  DateTime? notModifiedAt;

  @override
  Future<void> applyRefresh({
    required PodcastShowRecord show,
    required List<PodcastEpisodeRecord> episodeUpserts,
  }) async {
    this.show = show;
    lastUpserts = List<PodcastEpisodeRecord>.unmodifiable(episodeUpserts);
    for (final upsert in episodeUpserts) {
      final index = episodes.indexWhere((episode) => episode.id == upsert.id);
      if (index < 0) {
        episodes.add(upsert);
      } else {
        episodes[index] = upsert;
      }
    }
  }

  @override
  Future<PodcastShowRecord?> findShowByCanonicalUrl(
    Uri canonicalFeedUrl,
  ) async =>
      show?.canonicalFeedUrl == canonicalFeedUrl ? show : null;

  @override
  Future<List<PodcastEpisodeRecord>> listEpisodes(String showId) async =>
      episodes
          .where((episode) => episode.showId == showId)
          .toList(growable: false);

  @override
  Future<void> markNotModified({
    required String showId,
    required DateTime refreshedAt,
  }) async {
    notModifiedAt = refreshedAt;
  }
}

void main() {
  const parser = PodcastFeedParser();

  test('parses common podcast metadata and deduplicates a repeated GUID', () {
    final fixture = File(
      '../../fixtures/feeds/podcast_rss.xml',
    ).readAsStringSync();

    final feed = parser.parse(
      fixture,
      sourceUri: Uri.parse('https://podcast.example.test/feed.xml'),
    );

    expect(feed.title, 'River Audio Lab');
    expect(feed.author, 'River Lab');
    expect(feed.language, 'zh-CN');
    expect(feed.explicitRating, PodcastExplicitRating.clean);
    expect(
      feed.imageUrl,
      Uri.parse('https://podcast.example.test/images/show.jpg'),
    );
    expect(feed.duplicateEpisodeCount, 1);
    expect(feed.episodes, hasLength(1));
    final episode = feed.episodes.single;
    expect(episode.externalId, 'episode-42');
    expect(episode.author, 'Lin');
    expect(
      episode.mediaUrl,
      Uri.parse('https://podcast.example.test/audio/episode-42.mp3'),
    );
    expect(episode.mediaMimeType, 'audio/mpeg');
    expect(episode.mediaLengthBytes, 12345678);
    expect(episode.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(episode.episodeNumber, 42);
    expect(episode.seasonNumber, 3);
    expect(episode.episodeType, PodcastEpisodeType.full);
    expect(episode.explicitRating, PodcastExplicitRating.explicit);
    expect(episode.publishedAt, DateTime.utc(2026, 7, 25, 0, 30));
  });

  test('rejects feeds without a safe playable audio enclosure', () {
    const unsafe = '''
      <rss version="2.0"><channel><title>Unsafe</title>
        <item><guid>one</guid><title>One</title>
          <enclosure url="https://user:secret@example.test/one.mp3"
            type="audio/mpeg" />
        </item>
        <item><guid>two</guid><title>Two</title>
          <enclosure url="https://example.test/video.mp4" type="video/mp4" />
        </item>
      </channel></rss>
    ''';

    expect(
      () => parser.parse(
        unsafe,
        sourceUri: Uri.parse('https://example.test/feed.xml'),
      ),
      throwsA(
        isA<PodcastParseException>().having(
          (error) => error.message,
          'message',
          contains('no playable'),
        ),
      ),
    );
  });

  test('invalid optional metadata degrades without losing the episode', () {
    const unusual = '''
      <rss version="2.0"
        xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel><title>Unusual</title><itunes:explicit>maybe</itunes:explicit>
          <item><title>Episode</title><link>/episodes/stable</link>
            <itunes:duration>01:99</itunes:duration>
            <itunes:episode>-1</itunes:episode>
            <itunes:episodeType>special</itunes:episodeType>
            <enclosure url="/audio/no-type.mp3" />
          </item>
        </channel>
      </rss>
    ''';

    final episode = parser
        .parse(
          unusual,
          sourceUri: Uri.parse('https://example.test/feed.xml'),
        )
        .episodes
        .single;

    expect(episode.externalId, 'https://example.test/episodes/stable');
    expect(episode.duration, isNull);
    expect(episode.episodeNumber, isNull);
    expect(episode.explicitRating, PodcastExplicitRating.unknown);
    expect(episode.episodeType, PodcastEpisodeType.unknown);
  });

  test('parses bounded Podcasting 2.0 chapter and transcript references', () {
    final fixture = File(
      '../../fixtures/feeds/podcast_2_0.xml',
    ).readAsStringSync();

    final episode = parser
        .parse(
          fixture,
          sourceUri: Uri.parse('https://podcast.example.test/feed.xml'),
        )
        .episodes
        .single;

    expect(
      episode.chapterSource,
      PodcastChapterSource(
        url: Uri.parse(
          'https://podcast.example.test/meta/chapters.json',
        ),
        mimeType: 'application/json+chapters',
      ),
    );
    expect(episode.transcripts, <PodcastTranscriptReference>[
      PodcastTranscriptReference(
        url: Uri.parse(
          'https://podcast.example.test/meta/captions.vtt',
        ),
        mimeType: 'text/vtt',
        language: 'zh-CN',
        rel: 'captions',
      ),
      PodcastTranscriptReference(
        url: Uri.parse(
          'https://podcast.example.test/meta/transcript.txt',
        ),
        mimeType: 'text/plain',
        language: 'en',
      ),
    ]);
    expect(episode.transcripts.first.isCaptions, isTrue);
  });

  test('ignores lookalike namespaces and unsafe optional resources', () {
    const document = '''
      <rss version="2.0"
        xmlns:fake="https://example.test/not-podcasting"
        xmlns:podcast="https://podcastindex.org/namespace/1.0">
        <channel><title>Optional metadata</title>
          <item><guid>one</guid><title>One</title>
            <enclosure url="https://example.test/one.mp3"
              type="audio/mpeg" />
            <fake:chapters url="https://example.test/fake.json"
              type="application/json+chapters" />
            <podcast:chapters url="https://user:secret@example.test/real.json"
              type="application/json+chapters" />
            <podcast:transcript url="file:///private/transcript.vtt"
              type="text/vtt" />
          </item>
        </channel>
      </rss>
    ''';

    final episode = parser
        .parse(
          document,
          sourceUri: Uri.parse('https://example.test/feed.xml'),
        )
        .episodes
        .single;

    expect(episode.chapterSource, isNull);
    expect(episode.transcripts, isEmpty);
  });

  test('same GUID keeps its River id when the media URL changes', () async {
    final repository = _Repository();
    final http = _Http(
      PortHttpResponse(
        statusCode: 200,
        body: _podcastDocument(mediaPath: '/audio/original.mp3'),
        headers: const <String, String>{'etag': 'v1'},
      ),
    );
    final clock = _Clock(DateTime.utc(2026, 7, 25));
    final service = PodcastRefreshService(
      http: http,
      repository: repository,
      clock: clock,
      ids: _Ids(),
    );

    final first = await service.subscribeOrRefresh(
      Uri.parse('HTTPS://PODCAST.EXAMPLE.TEST:443/feed.xml#fragment'),
    );
    final originalId = repository.episodes.single.id;
    expect(first.insertedEpisodes, 1);
    expect(first.updatedEpisodes, 0);
    expect(repository.show?.etag, 'v1');

    clock.value = DateTime.utc(2026, 7, 26);
    http.response = PortHttpResponse(
      statusCode: 200,
      body: _podcastDocument(mediaPath: '/audio/rehosted.m4a'),
      headers: const <String, String>{'etag': 'v2'},
    );
    final second = await service.subscribeOrRefresh(
      Uri.parse('https://podcast.example.test/feed.xml'),
    );

    expect(second.insertedEpisodes, 0);
    expect(second.updatedEpisodes, 1);
    expect(repository.episodes, hasLength(1));
    expect(repository.episodes.single.id, originalId);
    expect(
      repository.episodes.single.mediaUrl,
      Uri.parse('https://podcast.example.test/audio/rehosted.m4a'),
    );
    expect(http.lastHeaders, <String, String>{'if-none-match': 'v1'});
  });

  test('an unchanged refresh produces no episode write', () async {
    final body = _podcastDocument(mediaPath: '/audio/one.mp3');
    final repository = _Repository();
    final http = _Http(PortHttpResponse(statusCode: 200, body: body));
    final service = PodcastRefreshService(
      http: http,
      repository: repository,
      clock: _Clock(DateTime.utc(2026, 7, 25)),
      ids: _Ids(),
    );

    await service.subscribeOrRefresh(
      Uri.parse('https://podcast.example.test/feed.xml'),
    );
    final result = await service.subscribeOrRefresh(
      Uri.parse('https://podcast.example.test/feed.xml'),
    );

    expect(result.insertedEpisodes, 0);
    expect(result.updatedEpisodes, 0);
    expect(result.unchangedEpisodes, 1);
    expect(repository.lastUpserts, isEmpty);
  });

  test('conditional not-modified advances freshness without parsing', () async {
    final repository = _Repository();
    final clock = _Clock(DateTime.utc(2026, 7, 25));
    final http = _Http(
      PortHttpResponse(
        statusCode: 200,
        body: _podcastDocument(mediaPath: '/audio/one.mp3'),
        headers: const <String, String>{
          'etag': 'v1',
          'last-modified': 'Sat, 25 Jul 2026 00:00:00 GMT',
        },
      ),
    );
    final service = PodcastRefreshService(
      http: http,
      repository: repository,
      clock: clock,
      ids: _Ids(),
    );
    await service.subscribeOrRefresh(
      Uri.parse('https://podcast.example.test/feed.xml'),
    );

    clock.value = DateTime.utc(2026, 7, 26);
    http.response = const PortHttpResponse(statusCode: 304, body: '');
    final result = await service.subscribeOrRefresh(
      Uri.parse('https://podcast.example.test/feed.xml'),
    );

    expect(result.notModified, isTrue);
    expect(repository.notModifiedAt, DateTime.utc(2026, 7, 26));
    expect(http.lastHeaders, <String, String>{
      'if-none-match': 'v1',
      'if-modified-since': 'Sat, 25 Jul 2026 00:00:00 GMT',
    });
  });
}

String _podcastDocument({required String mediaPath}) => '''
  <rss version="2.0"
    xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
    <channel><title>River Show</title><itunes:explicit>no</itunes:explicit>
      <item><guid isPermaLink="false">stable-guid</guid>
        <title>Stable episode</title><link>/episodes/stable</link>
        <itunes:duration>90</itunes:duration>
        <enclosure url="$mediaPath" type="audio/mpeg" length="2048" />
      </item>
    </channel>
  </rss>
''';
