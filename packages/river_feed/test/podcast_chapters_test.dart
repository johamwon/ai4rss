import 'package:river_domain/river_domain.dart';
import 'package:river_feed/river_feed.dart';
import 'package:test/test.dart';

void main() {
  final source = PodcastChapterSource(
    url: Uri.parse('https://example.test/meta/chapters.json'),
    mimeType: 'application/json+chapters',
  );

  test('loads ordered Podcasting 2.0 JSON chapters with safe links', () async {
    final loader = PodcastChapterLoader(
      http: _Http(
        PortHttpResponse(
          statusCode: 200,
          body: '''
            {
              "version": "1.2.0",
              "chapters": [
                {"startTime": 0, "title": "Opening", "img": "cover.jpg"},
                {"startTime": 65.5, "title": "Main topic",
                 "url": "https://example.test/notes", "toc": false}
              ]
            }
          ''',
        ),
      ),
    );

    final chapters = await loader.load(source);

    expect(chapters, hasLength(2));
    expect(chapters.first.start, Duration.zero);
    expect(
      chapters.first.imageUrl,
      Uri.parse(
        'https://example.test/meta/cover.jpg',
      ),
    );
    expect(chapters.last.start, const Duration(seconds: 65, milliseconds: 500));
    expect(chapters.last.tableOfContents, isFalse);
  });

  test('rejects unordered, oversized, or unsafe chapter documents', () {
    const loader = PodcastChapterLoader(
      http: _Http(
        PortHttpResponse(
          statusCode: 200,
          body: '{}',
        ),
      ),
    );
    for (final document in <String>[
      '{"chapters":[{"startTime":2,"title":"Two"},'
          '{"startTime":1,"title":"One"}]}',
      '{"chapters":[{"startTime":0,"title":""}]}',
      '{"chapters":[{"startTime":0,"title":"Unsafe",'
          '"url":"file:///private"}]}',
    ]) {
      expect(
        () => loader.parse(document, sourceUri: source.url),
        throwsA(
          isA<PodcastChapterException>().having(
            (error) => error.code,
            'code',
            'invalid_chapter_document',
          ),
        ),
      );
    }
  });
}

final class _Http implements HttpPort {
  const _Http(this.response);

  final PortHttpResponse response;

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async =>
      response;
}
