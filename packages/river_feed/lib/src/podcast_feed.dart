import 'dart:collection';

import 'package:river_domain/river_domain.dart';
import 'package:xml/xml.dart';

import 'feed_refresh_service.dart';

enum PodcastExplicitRating { explicit, clean, unknown }

enum PodcastEpisodeType { full, trailer, bonus, unknown }

enum PodcastDownloadPolicy { manual, newestOnly, all }

final class ParsedPodcastFeed {
  const ParsedPodcastFeed({
    required this.title,
    required this.episodes,
    required this.explicitRating,
    required this.duplicateEpisodeCount,
    this.description,
    this.author,
    this.websiteUrl,
    this.imageUrl,
    this.language,
  });

  final String title;
  final String? description;
  final String? author;
  final Uri? websiteUrl;
  final Uri? imageUrl;
  final String? language;
  final PodcastExplicitRating explicitRating;
  final List<ParsedPodcastEpisode> episodes;
  final int duplicateEpisodeCount;
}

final class ParsedPodcastEpisode {
  const ParsedPodcastEpisode({
    required this.externalId,
    required this.title,
    required this.mediaUrl,
    required this.explicitRating,
    required this.episodeType,
    this.description,
    this.author,
    this.episodeUrl,
    this.imageUrl,
    this.mediaMimeType,
    this.mediaLengthBytes,
    this.publishedAt,
    this.duration,
    this.episodeNumber,
    this.seasonNumber,
  });

  final String externalId;
  final String title;
  final String? description;
  final String? author;
  final Uri? episodeUrl;
  final Uri mediaUrl;
  final Uri? imageUrl;
  final String? mediaMimeType;
  final int? mediaLengthBytes;
  final DateTime? publishedAt;
  final Duration? duration;
  final int? episodeNumber;
  final int? seasonNumber;
  final PodcastExplicitRating explicitRating;
  final PodcastEpisodeType episodeType;
}

final class PodcastShowRecord {
  const PodcastShowRecord({
    required this.id,
    required this.canonicalFeedUrl,
    required this.title,
    required this.explicitRating,
    required this.defaultPlaybackRate,
    required this.downloadPolicy,
    required this.lastRefreshedAt,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.author,
    this.websiteUrl,
    this.imageUrl,
    this.language,
    this.etag,
    this.lastModified,
  }) : assert(defaultPlaybackRate >= 0.5 && defaultPlaybackRate <= 3);

  final String id;
  final Uri canonicalFeedUrl;
  final String title;
  final String? description;
  final String? author;
  final Uri? websiteUrl;
  final Uri? imageUrl;
  final String? language;
  final PodcastExplicitRating explicitRating;
  final double defaultPlaybackRate;
  final PodcastDownloadPolicy downloadPolicy;
  final String? etag;
  final String? lastModified;
  final DateTime lastRefreshedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class PodcastEpisodeRecord {
  const PodcastEpisodeRecord({
    required this.id,
    required this.showId,
    required this.externalId,
    required this.title,
    required this.mediaUrl,
    required this.explicitRating,
    required this.episodeType,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.author,
    this.episodeUrl,
    this.imageUrl,
    this.mediaMimeType,
    this.mediaLengthBytes,
    this.publishedAt,
    this.duration,
    this.episodeNumber,
    this.seasonNumber,
  });

  final String id;
  final String showId;
  final String externalId;
  final String title;
  final String? description;
  final String? author;
  final Uri? episodeUrl;
  final Uri mediaUrl;
  final Uri? imageUrl;
  final String? mediaMimeType;
  final int? mediaLengthBytes;
  final DateTime? publishedAt;
  final Duration? duration;
  final int? episodeNumber;
  final int? seasonNumber;
  final PodcastExplicitRating explicitRating;
  final PodcastEpisodeType episodeType;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract interface class PodcastRepository {
  Future<PodcastShowRecord?> findShowByCanonicalUrl(Uri canonicalFeedUrl);

  Future<List<PodcastEpisodeRecord>> listEpisodes(String showId);

  Future<void> applyRefresh({
    required PodcastShowRecord show,
    required List<PodcastEpisodeRecord> episodeUpserts,
  });

  Future<void> markNotModified({
    required String showId,
    required DateTime refreshedAt,
  });
}

final class PodcastFeedParser {
  const PodcastFeedParser();

  ParsedPodcastFeed parse(String document, {required Uri sourceUri}) {
    try {
      final xml = XmlDocument.parse(document);
      final root = xml.rootElement;
      if (root.name.local.toLowerCase() != 'rss') {
        throw const PodcastParseException('Podcast feed must be RSS');
      }
      final channel = _firstChild(root, 'channel');
      if (channel == null) {
        throw const PodcastParseException('Podcast channel is missing');
      }

      final showExplicit = _explicit(_itunesText(channel, 'explicit'));
      final showImage = _safeWebUri(
            _itunesChild(channel, 'image')?.getAttribute('href'),
            sourceUri,
          ) ??
          _safeWebUri(
            _text(_firstChild(channel, 'image'), 'url'),
            sourceUri,
          );
      final episodesByIdentity = LinkedHashMap<String, ParsedPodcastEpisode>();
      var duplicates = 0;
      for (final item in _children(channel, 'item')) {
        final episode = _parseEpisode(
          item,
          sourceUri: sourceUri,
          showExplicit: showExplicit,
          showImage: showImage,
        );
        if (episode == null) {
          continue;
        }
        if (episodesByIdentity.containsKey(episode.externalId)) {
          duplicates += 1;
          continue;
        }
        episodesByIdentity[episode.externalId] = episode;
      }
      if (episodesByIdentity.isEmpty) {
        throw const PodcastParseException(
          'Podcast feed contains no playable audio enclosure',
        );
      }

      return ParsedPodcastFeed(
        title: _text(channel, 'title') ?? '(untitled podcast)',
        description:
            _text(channel, 'description') ?? _itunesText(channel, 'summary'),
        author: _itunesText(channel, 'author') ?? _text(channel, 'author'),
        websiteUrl: _safeWebUri(_text(channel, 'link'), sourceUri),
        imageUrl: showImage,
        language: _normalizedText(_text(channel, 'language')),
        explicitRating: showExplicit,
        episodes: List<ParsedPodcastEpisode>.unmodifiable(
          episodesByIdentity.values,
        ),
        duplicateEpisodeCount: duplicates,
      );
    } on PodcastParseException {
      rethrow;
    } catch (error) {
      throw PodcastParseException('Malformed podcast RSS', cause: error);
    }
  }

  ParsedPodcastEpisode? _parseEpisode(
    XmlElement item, {
    required Uri sourceUri,
    required PodcastExplicitRating showExplicit,
    required Uri? showImage,
  }) {
    final enclosure = _children(item, 'enclosure').firstWhereOrNull(
      (candidate) => _isAudioEnclosure(candidate, sourceUri),
    );
    if (enclosure == null) {
      return null;
    }
    final mediaUrl = _safeWebUri(enclosure.getAttribute('url'), sourceUri);
    if (mediaUrl == null) {
      return null;
    }
    final episodeUrl = _safeWebUri(_text(item, 'link'), sourceUri);
    final guid = _normalizedText(_text(item, 'guid'));
    final externalId = guid ?? episodeUrl?.toString() ?? mediaUrl.toString();
    final episodeExplicit = _explicit(_itunesText(item, 'explicit'));
    return ParsedPodcastEpisode(
      externalId: externalId,
      title: _text(item, 'title') ?? '(untitled episode)',
      description: _text(item, 'description') ?? _itunesText(item, 'summary'),
      author: _itunesText(item, 'author') ??
          _text(item, 'creator', namespaceHint: 'dc') ??
          _text(item, 'author'),
      episodeUrl: episodeUrl,
      mediaUrl: mediaUrl,
      imageUrl: _safeWebUri(
            _itunesChild(item, 'image')?.getAttribute('href'),
            sourceUri,
          ) ??
          showImage,
      mediaMimeType: _normalizedText(enclosure.getAttribute('type')),
      mediaLengthBytes: _positiveInt(enclosure.getAttribute('length')),
      publishedAt: _date(_text(item, 'pubDate')),
      duration: _duration(_itunesText(item, 'duration')),
      episodeNumber: _positiveInt(_itunesText(item, 'episode')),
      seasonNumber: _positiveInt(_itunesText(item, 'season')),
      explicitRating: episodeExplicit == PodcastExplicitRating.unknown
          ? showExplicit
          : episodeExplicit,
      episodeType: _episodeType(_itunesText(item, 'episodeType')),
    );
  }
}

final class PodcastRefreshService {
  const PodcastRefreshService({
    required this.http,
    required this.repository,
    required this.clock,
    required this.ids,
    this.parser = const PodcastFeedParser(),
  });

  final HttpPort http;
  final PodcastRepository repository;
  final Clock clock;
  final IdGenerator ids;
  final PodcastFeedParser parser;

  Future<PodcastRefreshResult> subscribeOrRefresh(Uri requestedUri) async {
    final canonicalUrl = canonicalizeFeedUrl(requestedUri);
    final existingShow = await repository.findShowByCanonicalUrl(canonicalUrl);
    final response = await http.get(
      canonicalUrl,
      headers: <String, String>{
        if (existingShow?.etag case final etag?) 'if-none-match': etag,
        if (existingShow?.lastModified case final modified?)
          'if-modified-since': modified,
      },
    );
    final refreshedAt = clock.now().toUtc();
    if (response.statusCode == 304) {
      if (existingShow == null) {
        throw const PodcastRefreshException(
          'Received not-modified for an unknown podcast',
        );
      }
      await repository.markNotModified(
        showId: existingShow.id,
        refreshedAt: refreshedAt,
      );
      return PodcastRefreshResult(
        showId: existingShow.id,
        insertedEpisodes: 0,
        updatedEpisodes: 0,
        unchangedEpisodes: 0,
        discardedDuplicates: 0,
        notModified: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PodcastRefreshException(
        'Podcast request failed with HTTP ${response.statusCode}',
      );
    }

    final parsed = parser.parse(
      response.body,
      sourceUri: response.effectiveUri ?? canonicalUrl,
    );
    final showId = existingShow?.id ?? ids.next();
    final existingEpisodes = existingShow == null
        ? const <PodcastEpisodeRecord>[]
        : await repository.listEpisodes(showId);
    final episodesByExternalId = <String, PodcastEpisodeRecord>{
      for (final episode in existingEpisodes) episode.externalId: episode,
    };
    final upserts = <PodcastEpisodeRecord>[];
    var inserted = 0;
    var updated = 0;
    var unchanged = 0;
    for (final episode in parsed.episodes) {
      final existing = episodesByExternalId[episode.externalId];
      final record = _episodeRecord(
        episode,
        showId: showId,
        id: existing?.id ?? ids.next(),
        createdAt: existing?.createdAt ?? refreshedAt,
        updatedAt: refreshedAt,
      );
      if (existing == null) {
        inserted += 1;
        upserts.add(record);
      } else if (_sameEpisodeContent(existing, record)) {
        unchanged += 1;
      } else {
        updated += 1;
        upserts.add(record);
      }
    }

    final show = PodcastShowRecord(
      id: showId,
      canonicalFeedUrl: canonicalUrl,
      title: parsed.title,
      description: parsed.description,
      author: parsed.author,
      websiteUrl: parsed.websiteUrl,
      imageUrl: parsed.imageUrl,
      language: parsed.language,
      explicitRating: parsed.explicitRating,
      defaultPlaybackRate: existingShow?.defaultPlaybackRate ?? 1,
      downloadPolicy:
          existingShow?.downloadPolicy ?? PodcastDownloadPolicy.manual,
      etag: _header(response.headers, 'etag'),
      lastModified: _header(response.headers, 'last-modified'),
      lastRefreshedAt: refreshedAt,
      createdAt: existingShow?.createdAt ?? refreshedAt,
      updatedAt: refreshedAt,
    );
    await repository.applyRefresh(show: show, episodeUpserts: upserts);
    return PodcastRefreshResult(
      showId: showId,
      insertedEpisodes: inserted,
      updatedEpisodes: updated,
      unchangedEpisodes: unchanged,
      discardedDuplicates: parsed.duplicateEpisodeCount,
      notModified: false,
    );
  }
}

final class PodcastRefreshResult {
  const PodcastRefreshResult({
    required this.showId,
    required this.insertedEpisodes,
    required this.updatedEpisodes,
    required this.unchangedEpisodes,
    required this.discardedDuplicates,
    required this.notModified,
  });

  final String showId;
  final int insertedEpisodes;
  final int updatedEpisodes;
  final int unchangedEpisodes;
  final int discardedDuplicates;
  final bool notModified;
}

final class PodcastParseException implements Exception {
  const PodcastParseException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PodcastParseException: $message';
}

final class PodcastRefreshException implements Exception {
  const PodcastRefreshException(this.message);

  final String message;

  @override
  String toString() => 'PodcastRefreshException: $message';
}

PodcastEpisodeRecord _episodeRecord(
  ParsedPodcastEpisode episode, {
  required String showId,
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
}) =>
    PodcastEpisodeRecord(
      id: id,
      showId: showId,
      externalId: episode.externalId,
      title: episode.title,
      description: episode.description,
      author: episode.author,
      episodeUrl: episode.episodeUrl,
      mediaUrl: episode.mediaUrl,
      imageUrl: episode.imageUrl,
      mediaMimeType: episode.mediaMimeType,
      mediaLengthBytes: episode.mediaLengthBytes,
      publishedAt: episode.publishedAt,
      duration: episode.duration,
      episodeNumber: episode.episodeNumber,
      seasonNumber: episode.seasonNumber,
      explicitRating: episode.explicitRating,
      episodeType: episode.episodeType,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

bool _sameEpisodeContent(
  PodcastEpisodeRecord first,
  PodcastEpisodeRecord second,
) =>
    first.showId == second.showId &&
    first.externalId == second.externalId &&
    first.title == second.title &&
    first.description == second.description &&
    first.author == second.author &&
    first.episodeUrl == second.episodeUrl &&
    first.mediaUrl == second.mediaUrl &&
    first.imageUrl == second.imageUrl &&
    first.mediaMimeType == second.mediaMimeType &&
    first.mediaLengthBytes == second.mediaLengthBytes &&
    first.publishedAt == second.publishedAt &&
    first.duration == second.duration &&
    first.episodeNumber == second.episodeNumber &&
    first.seasonNumber == second.seasonNumber &&
    first.explicitRating == second.explicitRating &&
    first.episodeType == second.episodeType;

XmlElement? _firstChild(XmlElement parent, String local) {
  for (final child in _children(parent, local)) {
    return child;
  }
  return null;
}

Iterable<XmlElement> _children(XmlElement parent, String local) =>
    parent.children.whereType<XmlElement>().where(
          (element) => element.name.local.toLowerCase() == local.toLowerCase(),
        );

XmlElement? _itunesChild(XmlElement parent, String local) {
  for (final child in _children(parent, local)) {
    final namespace = child.name.namespaceUri?.toLowerCase() ?? '';
    final prefix = child.name.prefix?.toLowerCase() ?? '';
    if (namespace.contains('itunes') || prefix == 'itunes') {
      return child;
    }
  }
  return null;
}

String? _itunesText(XmlElement parent, String local) =>
    _normalizedText(_itunesChild(parent, local)?.innerText);

String? _text(
  XmlElement? parent,
  String local, {
  String? namespaceHint,
}) {
  if (parent == null) {
    return null;
  }
  for (final child in _children(parent, local)) {
    if (namespaceHint != null) {
      final namespace = child.name.namespaceUri?.toLowerCase() ?? '';
      final prefix = child.name.prefix?.toLowerCase() ?? '';
      if (!namespace.contains(namespaceHint) && prefix != namespaceHint) {
        continue;
      }
    }
    return _normalizedText(child.innerText);
  }
  return null;
}

String? _normalizedText(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _isAudioEnclosure(XmlElement enclosure, Uri sourceUri) {
  final uri = _safeWebUri(enclosure.getAttribute('url'), sourceUri);
  if (uri == null) {
    return false;
  }
  final mimeType = enclosure.getAttribute('type')?.trim().toLowerCase();
  if (mimeType != null && mimeType.isNotEmpty) {
    return mimeType.startsWith('audio/');
  }
  final path = uri.path.toLowerCase();
  return const <String>[
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
    '.wav',
    '.flac',
  ].any(path.endsWith);
}

Uri? _safeWebUri(String? value, Uri base) {
  final normalized = _normalizedText(value);
  if (normalized == null) {
    return null;
  }
  final parsed = Uri.tryParse(normalized);
  if (parsed == null) {
    return null;
  }
  final resolved = parsed.hasScheme ? parsed : base.resolveUri(parsed);
  if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
      !resolved.hasAuthority ||
      resolved.userInfo.isNotEmpty) {
    return null;
  }
  return resolved;
}

int? _positiveInt(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

Duration? _duration(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final parts = normalized.split(':');
  if (parts.length > 3 ||
      parts.any((part) => !RegExp(r'^\d+$').hasMatch(part))) {
    return null;
  }
  final values = parts.map(int.parse).toList(growable: false);
  final seconds = switch (values) {
    [final seconds] => seconds,
    [final minutes, final seconds] when seconds < 60 => minutes * 60 + seconds,
    [final hours, final minutes, final seconds]
        when minutes < 60 && seconds < 60 =>
      hours * 3600 + minutes * 60 + seconds,
    _ => 0,
  };
  if (seconds <= 0 || seconds > const Duration(days: 7).inSeconds) {
    return null;
  }
  return Duration(seconds: seconds);
}

PodcastExplicitRating _explicit(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'yes' || 'true' || 'explicit' => PodcastExplicitRating.explicit,
    'no' || 'false' || 'clean' => PodcastExplicitRating.clean,
    _ => PodcastExplicitRating.unknown,
  };
}

PodcastEpisodeType _episodeType(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'full' => PodcastEpisodeType.full,
    'trailer' => PodcastEpisodeType.trailer,
    'bonus' => PodcastEpisodeType.bonus,
    _ => PodcastEpisodeType.unknown,
  };
}

DateTime? _date(String? value) {
  if (value == null) {
    return null;
  }
  final iso = DateTime.tryParse(value);
  if (iso != null) {
    return iso.toUtc();
  }
  final match = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{2,4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+([A-Za-z]+|[+-]\d{4})$',
  ).firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  const months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) {
    return null;
  }
  var year = int.parse(match.group(3)!);
  if (year < 100) {
    year += year >= 70 ? 1900 : 2000;
  }
  final zone = match.group(7)!.toUpperCase();
  var offset = Duration.zero;
  if (RegExp(r'^[+-]\d{4}$').hasMatch(zone)) {
    final sign = zone.startsWith('-') ? -1 : 1;
    offset = Duration(
      hours: sign * int.parse(zone.substring(1, 3)),
      minutes: sign * int.parse(zone.substring(3, 5)),
    );
  }
  return DateTime.utc(
    year,
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  ).subtract(offset);
}

String? _header(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name) {
      return entry.value;
    }
  }
  return null;
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) predicate) {
    for (final value in this) {
      if (predicate(value)) {
        return value;
      }
    }
    return null;
  }
}
