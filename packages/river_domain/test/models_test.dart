import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('article keeps canonical source identity', () {
    final article = Article(
      id: 'article-1',
      url: Uri.parse('https://example.test/a'),
      title: 'A synthetic article',
      source: ContentSource.feed,
    );

    expect(article.id, 'article-1');
    expect(article.url.host, 'example.test');
  });

  test('reader settings have stable defaults and immutable updates', () {
    const defaults = ReaderSettings();

    expect(defaults.fontFamily, ReaderFontFamily.system);
    expect(defaults.fontScale, 1);
    expect(defaults.lineHeight, 1.75);
    expect(defaults.contentWidth, 760);
    expect(defaults.theme, ReaderThemePreference.system);

    final darkSerif = defaults.copyWith(
      fontFamily: ReaderFontFamily.serif,
      fontScale: 1.25,
      theme: ReaderThemePreference.dark,
    );
    expect(
      darkSerif,
      const ReaderSettings(
        fontFamily: ReaderFontFamily.serif,
        fontScale: 1.25,
        theme: ReaderThemePreference.dark,
      ),
    );
    expect(defaults, const ReaderSettings());
  });

  test('reader settings reject values outside supported bounds', () {
    expect(
      () => ReaderSettings(fontScale: 0.79),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => ReaderSettings(lineHeight: 2.21),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => ReaderSettings(contentWidth: 1001),
      throwsA(isA<AssertionError>()),
    );
  });

  test('audio queue keeps one cross-source current item and stable revision',
      () {
    final now = DateTime.utc(2026, 7, 28);
    final article = AudioQueueEntry(
      item: AudioItem(
        id: 'article-1',
        kind: AudioKind.articleTts,
        title: 'Article',
        sourceUri: Uri.parse('https://example.test/article'),
      ),
      position: 0,
      isCurrent: true,
      contentRevision: 'sha256:article-v1',
      enqueuedAt: now,
      updatedAt: now,
    );
    final podcast = AudioQueueEntry(
      item: AudioItem(
        id: 'podcast-1',
        kind: AudioKind.podcastEpisode,
        title: 'Podcast',
        sourceUri: Uri.parse('https://example.test/podcast.mp3'),
      ),
      position: 1,
      isCurrent: false,
      enqueuedAt: now,
      updatedAt: now,
    );
    final queue = AudioQueueSnapshot(<AudioQueueEntry>[article, podcast]);

    expect(queue.current?.item.id, article.item.id);
    expect(queue.currentIndex, 0);
    expect(queue.entries.map((entry) => entry.item.kind), <AudioKind>[
      AudioKind.articleTts,
      AudioKind.podcastEpisode,
    ]);
    expect(
      () => AudioQueueEntry(
        item: article.item,
        position: 0,
        isCurrent: true,
        enqueuedAt: now,
        updatedAt: now,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
