import 'package:river_ai/river_ai.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_test_harness/river_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('scenario controls time, HTTP and AI deterministically', () async {
    final uri = Uri.parse('https://example.test/feed');
    final scenario = RiverScenario(startsAt: DateTime.utc(2026, 7, 14))
        .withHttp(uri, '<rss/>')
        .withSummary(
          'article-1',
          const ArticleSummary(
            oneLine: 'A replayed summary',
            keyPoints: <String>[
              'Deterministic input',
              'Deterministic output',
              'No network access',
            ],
            whyItMatters: 'Replay keeps tests stable.',
            topics: <String>['testing'],
            entities: <String>['River'],
            estimatedReadingMinutes: 1,
            language: 'en',
            model: 'replay',
            promptVersion: '1',
          ),
        )
        .after(const Duration(minutes: 5));

    expect(scenario.clock.now(), DateTime.utc(2026, 7, 14, 0, 5));
    expect((await scenario.http.get(uri)).body, '<rss/>');
    final summary = await SummaryService(
      scenario.ai,
      model: 'replay',
      outputLanguage: 'en',
    ).summarize(
      Article(
        id: 'article-1',
        url: Uri.parse('https://example.test/article-1'),
        title: 'Replay',
        source: ContentSource.feed,
        plainText: 'Deterministic replay content.',
      ),
    );
    expect(summary.oneLine, 'A replayed summary');
    expect(scenario.ai.requests, <String>['article-1']);
  });
}
