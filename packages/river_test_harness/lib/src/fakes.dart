import 'package:river_domain/river_domain.dart';

final class FakeClock implements Clock {
  FakeClock(this._value);

  DateTime _value;

  @override
  DateTime now() => _value;

  void advance(Duration duration) {
    _value = _value.add(duration);
  }

  void set(DateTime value) {
    _value = value;
  }
}

final class FakeIdGenerator implements IdGenerator {
  var _counter = 0;

  @override
  String next() => 'test-${++_counter}';
}

final class FakeHttpPort implements HttpPort {
  final Map<Uri, PortHttpResponse> _responses = <Uri, PortHttpResponse>{};
  final List<Uri> requests = <Uri>[];

  void register(Uri uri, PortHttpResponse response) {
    _responses[uri] = response;
  }

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    requests.add(uri);
    final response = _responses[uri];
    if (response == null) {
      throw StateError('No fake HTTP response registered for $uri');
    }
    return response;
  }
}

final class ReplayAiProvider implements AiProvider {
  final Map<String, ArticleSummary> _responses = <String, ArticleSummary>{};
  final List<String> requests = <String>[];

  void register(String articleId, ArticleSummary summary) {
    _responses[articleId] = summary;
  }

  @override
  Future<ArticleSummary> summarize(Article article) async {
    requests.add(article.id);
    final response = _responses[article.id];
    if (response == null) {
      throw StateError('No replay AI response for ${article.id}');
    }
    return response;
  }
}

final class FakeKnowledgeConnector implements KnowledgeConnector {
  FakeKnowledgeConnector({this.id = 'fake-knowledge'});

  @override
  final String id;

  final Map<String, KnowledgeConnectorObject> exports =
      <String, KnowledgeConnectorObject>{};
  final List<String> idempotencyKeys = <String>[];

  @override
  Future<KnowledgeConnectorObject> create(
    KnowledgeConnectorCreateRequest request,
  ) async {
    idempotencyKeys.add(request.idempotencyKey);
    return exports.putIfAbsent(
      request.item.id,
      () => KnowledgeConnectorObject(
        externalObjectId: 'external-${request.item.id}',
        externalUrl: Uri.parse('https://knowledge.test/${request.item.id}'),
      ),
    );
  }

  @override
  Future<void> delete(KnowledgeConnectorDeleteRequest request) async {
    exports.removeWhere(
      (_, object) => object.externalObjectId == request.externalObjectId,
    );
  }

  @override
  Future<KnowledgeConnectorObjectStatus> status(
    KnowledgeConnectorStatusRequest request,
  ) async {
    final object = exports.values
        .where(
          (candidate) => candidate.externalObjectId == request.externalObjectId,
        )
        .firstOrNull;
    return KnowledgeConnectorObjectStatus(
      phase: object == null
          ? KnowledgeConnectorObjectPhase.missing
          : KnowledgeConnectorObjectPhase.available,
      externalUrl: object?.externalUrl,
    );
  }

  @override
  Future<KnowledgeConnectorConnectionStatus> testConnection() async {
    return const KnowledgeConnectorConnectionStatus(
      phase: KnowledgeConnectorConnectionPhase.connected,
    );
  }

  @override
  Future<KnowledgeConnectorObject> update(
    KnowledgeConnectorUpdateRequest request,
  ) async {
    idempotencyKeys.add(request.idempotencyKey);
    final object = KnowledgeConnectorObject(
      externalObjectId: request.externalObjectId,
      externalUrl: Uri.parse('https://knowledge.test/${request.item.id}'),
    );
    exports[request.item.id] = object;
    return object;
  }
}
