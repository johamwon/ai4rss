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
}
