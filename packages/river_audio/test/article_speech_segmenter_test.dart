import 'package:river_audio/river_audio.dart';
import 'package:river_domain/river_domain.dart';
import 'package:test/test.dart';

void main() {
  test('segments Chinese and English with their punctuation and language', () {
    const source = '这是第一句。“第二句也保留标点！”\n'
        'This is one. Dr. Smith stays together.';

    final segments = const ArticleSpeechSegmenter().segment(source);

    expect(
      segments.map((segment) => segment.text),
      <String>[
        '这是第一句。',
        '“第二句也保留标点！”',
        'This is one.',
        'Dr. Smith stays together.',
      ],
    );
    expect(
      segments.map((segment) => segment.languageTag),
      <String?>['zh-CN', 'zh-CN', 'en-US', 'en-US'],
    );
    expect(
      segments.indexed.every((entry) => entry.$1 == entry.$2.index),
      isTrue,
    );
  });

  test('keeps decimals and common abbreviations inside the sentence', () {
    const source = 'Dr. Smith measured 3.14 meters. Next sentence!';

    final segments = const ArticleSpeechSegmenter().segment(source);

    expect(
      segments.map((segment) => segment.text),
      <String>[
        'Dr. Smith measured 3.14 meters.',
        'Next sentence!',
      ],
    );
  });

  test('leaves a genuinely mixed-language sentence on the system default', () {
    const source = 'River 支持本地 TTS。';

    final segments = const ArticleSpeechSegmenter().segment(source);

    expect(segments, hasLength(1));
    expect(segments.single.languageTag, isNull);
  });

  test('splits an overlong sentence at safe boundaries', () {
    const source =
        'Alpha beta gamma delta epsilon zeta eta theta iota kappa 😀 omega.';
    final segments =
        const ArticleSpeechSegmenter(maxSegmentCharacters: 24).segment(source);

    expect(segments, hasLength(greaterThan(2)));
    expect(
      segments.every((segment) => segment.text.length <= 24),
      isTrue,
    );
    expect(
      segments.every(
        (segment) => !segment.text.contains('\u{FFFD}'),
      ),
      isTrue,
    );
    for (final segment in segments) {
      expect(segment.sourceStart, lessThan(segment.sourceEnd));
      expect(segment.sourceEnd, lessThanOrEqualTo(source.length));
    }
  });

  test('replaces fenced code with a bounded non-code placeholder', () {
    const source = 'Before code.\n'
        '```dart\n'
        'final secret = token;\n'
        '```\n'
        '正文继续。';

    final segments = const ArticleSpeechSegmenter().segment(source);

    expect(segments, hasLength(3));
    expect(segments.first.text, 'Before code.');
    expect(segments[1].kind, SpeechSegmentKind.codePlaceholder);
    expect(segments[1].text, isNot(contains('secret')));
    expect(
      source.substring(segments[1].sourceStart, segments[1].sourceEnd),
      contains('final secret = token;'),
    );
    expect(segments.last.text, '正文继续。');
  });

  test('two-hour synthetic article stays within a bounded speech-plan budget',
      () {
    const sentence =
        'River reads this complete sentence locally and keeps its position. ';
    const targetCharacters = 120 * 900;
    final source = List<String>.filled(
      (targetCharacters / sentence.length).ceil(),
      sentence,
      growable: false,
    ).join();
    final stopwatch = Stopwatch()..start();

    final segments = const ArticleSpeechSegmenter().segment(source);

    stopwatch.stop();
    final retainedEstimate = segments.fold<int>(
      0,
      (total, segment) => total + segment.text.length * 2 + 256,
    );
    expect(source.length, greaterThanOrEqualTo(targetCharacters));
    expect(segments, isNotEmpty);
    expect(
      segments.every((segment) => segment.text.length <= 280),
      isTrue,
    );
    expect(
      segments.indexed.every(
        (entry) =>
            entry.$2.index == entry.$1 &&
            (entry.$1 == 0 ||
                segments[entry.$1 - 1].sourceEnd <= entry.$2.sourceStart),
      ),
      isTrue,
    );
    expect(retainedEstimate, lessThan(2 * 1024 * 1024));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('empty and whitespace-only articles have no speech work', () {
    const segmenter = ArticleSpeechSegmenter();

    expect(segmenter.segment(''), isEmpty);
    expect(segmenter.segment(' \n\t　'), isEmpty);
  });
}
