import 'package:river_domain/river_domain.dart';

import 'fakes.dart';

final class RiverScenario {
  RiverScenario({DateTime? startsAt})
      : clock = FakeClock(startsAt ?? DateTime.utc(2026, 1, 1));

  final FakeClock clock;
  final FakeHttpPort http = FakeHttpPort();
  final ReplayAiProvider ai = ReplayAiProvider();
  final FakeIdGenerator ids = FakeIdGenerator();
  final FakeKnowledgeConnector knowledge = FakeKnowledgeConnector();

  RiverScenario withHttp(Uri uri, String body, {int statusCode = 200}) {
    http.register(
      uri,
      PortHttpResponse(statusCode: statusCode, body: body),
    );
    return this;
  }

  RiverScenario withSummary(String articleId, ArticleSummary summary) {
    ai.register(articleId, summary);
    return this;
  }

  RiverScenario after(Duration duration) {
    clock.advance(duration);
    return this;
  }
}
