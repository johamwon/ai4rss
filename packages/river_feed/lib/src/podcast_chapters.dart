import 'dart:convert';

import 'package:river_domain/river_domain.dart';

import 'podcast_feed.dart';

final class PodcastChapter {
  const PodcastChapter({
    required this.start,
    required this.title,
    this.imageUrl,
    this.linkUrl,
    this.tableOfContents = true,
  });

  final Duration start;
  final String title;
  final Uri? imageUrl;
  final Uri? linkUrl;
  final bool tableOfContents;
}

final class PodcastChapterLoader {
  const PodcastChapterLoader({required this.http});

  final HttpPort http;

  Future<List<PodcastChapter>> load(PodcastChapterSource source) async {
    if (source.mimeType != 'application/json+chapters') {
      throw const PodcastChapterException('unsupported_chapter_format');
    }
    final response = await http.get(source.url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PodcastChapterException('chapter_request_failed');
    }
    return parse(response.body, sourceUri: response.effectiveUri ?? source.url);
  }

  List<PodcastChapter> parse(String document, {required Uri sourceUri}) {
    try {
      final decoded = jsonDecode(document);
      if (decoded is! Map<String, Object?>) {
        throw const PodcastChapterException('invalid_chapter_document');
      }
      final values = decoded['chapters'];
      if (values is! List<Object?> || values.length > 500) {
        throw const PodcastChapterException('invalid_chapter_document');
      }
      final chapters = <PodcastChapter>[];
      var previousStart = -1.0;
      for (final value in values) {
        if (value is! Map<String, Object?>) {
          throw const PodcastChapterException('invalid_chapter_document');
        }
        final startValue = value['startTime'];
        final titleValue = value['title'];
        if (startValue is! num ||
            !startValue.isFinite ||
            startValue < 0 ||
            startValue > const Duration(days: 7).inSeconds ||
            startValue < previousStart ||
            titleValue is! String) {
          throw const PodcastChapterException('invalid_chapter_document');
        }
        final title = titleValue.trim();
        if (title.isEmpty || title.length > 512) {
          throw const PodcastChapterException('invalid_chapter_document');
        }
        previousStart = startValue.toDouble();
        chapters.add(
          PodcastChapter(
            start: Duration(
              milliseconds: (startValue.toDouble() * 1000).round(),
            ),
            title: title,
            imageUrl: _optionalHttpsUri(value['img'], sourceUri),
            linkUrl: _optionalHttpsUri(value['url'], sourceUri),
            tableOfContents:
                value['toc'] is bool ? value['toc']! as bool : true,
          ),
        );
      }
      return List<PodcastChapter>.unmodifiable(chapters);
    } on PodcastChapterException {
      rethrow;
    } on FormatException {
      throw const PodcastChapterException('invalid_chapter_document');
    }
  }
}

final class PodcastChapterException implements Exception {
  const PodcastChapterException(this.code);

  final String code;
}

Uri? _optionalHttpsUri(Object? value, Uri base) {
  if (value == null) return null;
  if (value is! String || value.length > 4096) {
    throw const PodcastChapterException('invalid_chapter_document');
  }
  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    throw const PodcastChapterException('invalid_chapter_document');
  }
  final resolved = parsed.hasScheme ? parsed : base.resolveUri(parsed);
  if (resolved.scheme != 'https' ||
      !resolved.hasAuthority ||
      resolved.userInfo.isNotEmpty) {
    throw const PodcastChapterException('invalid_chapter_document');
  }
  return resolved;
}
