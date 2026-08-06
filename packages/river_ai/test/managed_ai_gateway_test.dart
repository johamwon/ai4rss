import 'dart:async';
import 'dart:convert';

import 'package:river_ai/river_ai.dart';
import 'package:test/test.dart';

void main() {
  group('managed AI gateway', () {
    test('routes by trusted plan and never accepts a client model or key',
        () async {
      final fixture = _Fixture();
      final managedRequest = _request('route-op');
      final adapter = ManagedAiGatewayProviderAdapter(
        gateway: fixture.gateway,
        principal: _principal(ManagedAiPlan.free),
        capability: ManagedAiCapability.articleSummary,
        outputLanguage: 'zh-CN',
      );

      final response = await adapter.complete(
        AiProviderRequest(
          operationId: managedRequest.operationId,
          model: 'caller-cannot-select-this-model',
          prompt: managedRequest.prompt,
          responseSchema: managedRequest.responseSchema,
          timeout: managedRequest.timeout,
        ),
      );

      expect(response.model, 'economy-model');
      expect(fixture.primary.requests.single.model, 'economy-model');
      expect(_request('route-op').toString(), isNot(contains('private body')));
      expect(
        _principal(ManagedAiPlan.free).toString(),
        isNot(contains('acct-1')),
      );
    });

    test('falls back on provider failure and reports only usable route',
        () async {
      final fixture = _Fixture(
        primaryHandler: (request) => throw AiProviderFailure(
          code: AiProviderFailureCode.unavailable,
          retryable: true,
        ),
      );

      final result = await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: _request('provider-fallback'),
      );

      expect(result.routeId, 'fallback.route');
      expect(result.usedFallback, isTrue);
      expect(result.attempts, 2);
      expect(fixture.fallback.requests, hasLength(1));
    });

    test('rejects invalid quality before fallback and includes incurred cost',
        () async {
      final fixture = _Fixture(
        primaryHandler: (request) async => _response(
          request,
          output: '{"not":"the summary schema"}',
        ),
      );

      final result = await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.pro),
        request: _request('quality-fallback'),
      );

      expect(result.routeId, 'fallback.route');
      expect(result.totalCostMicros, 2400);
      expect(
        fixture.events.map((event) => event.outcome),
        <ManagedAiDiagnosticOutcome>[
          ManagedAiDiagnosticOutcome.qualityRejected,
          ManagedAiDiagnosticOutcome.accepted,
        ],
      );
    });

    test('bounded timeout falls back without exposing provider detail',
        () async {
      final guard = _ScriptedTimeoutGuard(<bool>[true, false]);
      final fixture = _Fixture(timeoutGuard: guard);

      final result = await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: _request('timeout-fallback'),
      );

      expect(result.routeId, 'fallback.route');
      expect(result.attempts, 2);
      expect(guard.timeouts, everyElement(const Duration(seconds: 5)));
      expect(fixture.events.first.outcome, ManagedAiDiagnosticOutcome.timedOut);
    });

    test('fallback receives only the remaining total request budget', () async {
      final clock = _GatewayClock();
      final guard = _ScriptedTimeoutGuard(<bool>[false, false]);
      final fixture = _Fixture(
        gatewayClock: clock,
        timeoutGuard: guard,
        primaryHandler: (request) async {
          clock.advance(const Duration(seconds: 4));
          return _response(request, output: '{"invalid":true}');
        },
      );

      await fixture.call('remaining-budget');

      expect(
        guard.timeouts,
        <Duration>[
          const Duration(seconds: 5),
          const Duration(seconds: 1),
        ],
      );
    });

    test('coalesces in-flight duplicates and replays completed result',
        () async {
      final completer = Completer<AiProviderResponse>();
      final fixture = _Fixture(
        primaryHandler: (request) => completer.future,
        maximumRequests: 1,
      );
      final request = _request('same-operation');

      final first = fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: request,
      );
      final duplicate = fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: request,
      );
      completer.complete(_response(fixture.primary.requests.single));

      final values = await Future.wait(<Future<ManagedAiGatewayResponse>>[
        first,
        duplicate,
      ]);
      final replay = await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: request,
      );

      expect(identical(values[0], values[1]), isTrue);
      expect(identical(values[0], replay), isTrue);
      expect(fixture.primary.requests, hasLength(1));
    });

    test('same idempotency key with different input fails closed', () async {
      final fixture = _Fixture();
      await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: _request('conflicting-operation'),
      );

      expect(
        () => fixture.gateway.complete(
          principal: _principal(ManagedAiPlan.free),
          request: _request(
            'conflicting-operation',
            body: 'different private body',
          ),
        ),
        throwsA(
          isA<ManagedAiGatewayFailure>().having(
            (failure) => failure.code,
            'code',
            ManagedAiGatewayFailureCode.idempotencyConflict,
          ),
        ),
      );
      expect(fixture.primary.requests, hasLength(1));
    });

    test('completed replay retention is bounded in time', () async {
      final fixture = _Fixture();
      final request = _request('retained-operation');
      await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: request,
      );
      fixture.clock.advance(const Duration(hours: 24));

      await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: request,
      );

      expect(fixture.primary.requests, hasLength(2));
    });

    test('rate limits unique account capability requests per UTC window',
        () async {
      final fixture = _Fixture(maximumRequests: 1);
      await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: _request('rate-one'),
      );

      await expectLater(
        fixture.gateway.complete(
          principal: _principal(ManagedAiPlan.free),
          request: _request('rate-two'),
        ),
        throwsA(
          isA<ManagedAiGatewayFailure>()
              .having(
                (failure) => failure.code,
                'code',
                ManagedAiGatewayFailureCode.rateLimited,
              )
              .having(
                (failure) => failure.retryAfter,
                'retryAfter',
                const Duration(minutes: 1),
              ),
        ),
      );

      fixture.clock.advance(const Duration(minutes: 1));
      await fixture.gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: _request('rate-three'),
      );
      expect(fixture.primary.requests, hasLength(2));
    });

    test('opens circuit, skips unhealthy primary, then permits one recovery',
        () async {
      var failuresRemaining = 2;
      final fixture = _Fixture(
        primaryHandler: (request) async {
          if (failuresRemaining > 0) {
            failuresRemaining -= 1;
            throw AiProviderFailure(
              code: AiProviderFailureCode.unavailable,
              retryable: true,
            );
          }
          return _response(request);
        },
        circuitFailureThreshold: 2,
      );

      await fixture.call('circuit-one');
      await fixture.call('circuit-two');
      final skipped = await fixture.call('circuit-three');

      expect(skipped.routeId, 'fallback.route');
      expect(skipped.attempts, 1);
      expect(skipped.usedFallback, isTrue);
      expect(fixture.primary.requests, hasLength(2));

      fixture.clock.advance(const Duration(seconds: 30));
      final recovered = await fixture.call('circuit-four');
      expect(recovered.routeId, 'primary.route');
      expect(fixture.primary.requests, hasLength(3));
    });

    test('half-open circuit admits only one concurrent recovery probe',
        () async {
      var first = true;
      final recovery = Completer<AiProviderResponse>();
      final fixture = _Fixture(
        primaryHandler: (request) {
          if (first) {
            first = false;
            throw AiProviderFailure(
              code: AiProviderFailureCode.unavailable,
              retryable: true,
            );
          }
          return recovery.future;
        },
        circuitFailureThreshold: 1,
      );
      await fixture.call('half-open-initial');
      fixture.clock.advance(const Duration(seconds: 30));

      final probe = fixture.call('half-open-probe');
      final concurrent = await fixture.call('half-open-concurrent');
      recovery.complete(_response(fixture.primary.requests.last));
      final recovered = await probe;

      expect(concurrent.routeId, 'fallback.route');
      expect(recovered.routeId, 'primary.route');
      expect(fixture.primary.requests, hasLength(2));
    });

    test('invalid requests do not fall back to another billable provider',
        () async {
      final fixture = _Fixture(
        primaryHandler: (request) => throw AiProviderFailure(
          code: AiProviderFailureCode.invalidRequest,
          retryable: false,
        ),
      );

      await expectLater(
        fixture.call('invalid-request'),
        throwsA(
          isA<ManagedAiGatewayFailure>().having(
            (failure) => failure.code,
            'code',
            ManagedAiGatewayFailureCode.invalidRequest,
          ),
        ),
      );
      expect(fixture.fallback.requests, isEmpty);
    });

    test('diagnostics contain hashes and aggregates but no private content',
        () async {
      final fixture = _Fixture();
      await fixture.call('private-operation-id');

      final diagnostics = fixture.events.join('\n');
      expect(diagnostics, isNot(contains('private-operation-id')));
      expect(diagnostics, isNot(contains('private body')));
      expect(diagnostics, isNot(contains('secret-provider-key')));
      expect(diagnostics, contains('operationHash'));
      expect(diagnostics, contains('costMicros'));
    });
  });
}

final class _Fixture {
  _Fixture({
    Future<AiProviderResponse> Function(AiProviderRequest)? primaryHandler,
    ManagedAiTimeoutGuard timeoutGuard = const FutureManagedAiTimeoutGuard(),
    int maximumRequests = 20,
    int circuitFailureThreshold = 2,
    _GatewayClock? gatewayClock,
  })  : clock = gatewayClock ?? _GatewayClock(),
        primary = _ScriptedProvider(
          'primary-provider',
          primaryHandler ?? (request) async => _response(request),
        ),
        fallback = _ScriptedProvider(
          'fallback-provider',
          (request) async => _response(request),
        ) {
    gateway = ManagedAiGateway(
      routes: ManagedAiRoutingTable(<ManagedAiRoutingRule>[
        for (final plan in ManagedAiPlan.values)
          ManagedAiRoutingRule(
            plan: plan,
            capability: ManagedAiCapability.articleSummary,
            targets: <ManagedAiRouteTarget>[
              _target(
                routeId: 'primary.route',
                providerId: 'primary-provider',
                model: plan == ManagedAiPlan.free
                    ? 'economy-model'
                    : 'quality-model',
              ),
              _target(
                routeId: 'fallback.route',
                providerId: 'fallback-provider',
                model: 'fallback-model',
              ),
            ],
          ),
      ]),
      upstreams: StaticManagedAiUpstreamRegistry(<String, AiProvider>{
        'primary.route': primary,
        'fallback.route': fallback,
      }),
      outputValidator: const ArticleSummaryManagedAiOutputValidator(),
      clock: clock,
      timeoutGuard: timeoutGuard,
      diagnostics: _ListDiagnosticSink(events),
      rateLimit: ManagedAiRateLimitPolicy(
        maximumRequests: maximumRequests,
      ),
      circuitBreaker: ManagedAiCircuitBreakerPolicy(
        failureThreshold: circuitFailureThreshold,
      ),
    );
  }

  final _GatewayClock clock;
  final List<ManagedAiDiagnosticEvent> events = <ManagedAiDiagnosticEvent>[];
  final _ScriptedProvider primary;
  final _ScriptedProvider fallback;
  late final ManagedAiGateway gateway;

  Future<ManagedAiGatewayResponse> call(String operationId) => gateway.complete(
        principal: _principal(ManagedAiPlan.free),
        request: _request(operationId),
      );
}

ManagedAiPrincipal _principal(ManagedAiPlan plan) =>
    ManagedAiPrincipal(accountKey: 'acct-1', plan: plan);

ManagedAiGatewayRequest _request(
  String operationId, {
  String body = 'private body',
}) {
  final prompt = articleSummaryPromptV1.render(<String, String>{
    'articleId': 'article-1',
    'title': 'Private title',
    'content': body,
    'language': 'zh-CN',
  });
  return ManagedAiGatewayRequest(
    operationId: operationId,
    capability: ManagedAiCapability.articleSummary,
    prompt: prompt,
    responseSchema: ArticleSummarySchema.jsonSchema,
    outputLanguage: 'zh-CN',
    timeout: const Duration(seconds: 5),
  );
}

ManagedAiRouteTarget _target({
  required String routeId,
  required String providerId,
  required String model,
}) =>
    ManagedAiRouteTarget(
      routeId: routeId,
      providerId: providerId,
      model: model,
      inputMicrosPerMillionTokens: 1000000,
      outputMicrosPerMillionTokens: 2000000,
      timeout: const Duration(seconds: 5),
    );

AiProviderResponse _response(
  AiProviderRequest request, {
  String? output,
}) =>
    AiProviderResponse(
      output: output ??
          jsonEncode(<String, Object?>{
            'schemaVersion': ArticleSummarySchema.name,
            'oneLine': '这是合格的一句话摘要。',
            'keyPoints': <String>['要点一', '要点二', '要点三'],
            'whyItMatters': '帮助读者快速判断文章价值。',
            'topics': <String>['RSS'],
            'entities': <String>['River'],
            'estimatedReadingMinutes': 3,
            'language': 'zh-CN',
          }),
      model: request.model,
      usage: AiTokenUsage(inputTokens: 1000, outputTokens: 100),
      elapsed: const Duration(milliseconds: 20),
    );

final class _ScriptedProvider implements AiProvider {
  _ScriptedProvider(this.id, this.handler);

  @override
  final String id;
  final Future<AiProviderResponse> Function(AiProviderRequest request) handler;
  final List<AiProviderRequest> requests = <AiProviderRequest>[];
  final String secret = 'secret-provider-key';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) {
    requests.add(request);
    return handler(request);
  }
}

final class _GatewayClock implements ManagedAiGatewayClock {
  DateTime _now = DateTime.utc(2026, 8, 6, 12);
  Duration _elapsed = Duration.zero;

  void advance(Duration duration) {
    _now = _now.add(duration);
    _elapsed += duration;
  }

  @override
  Duration elapsed() => _elapsed;

  @override
  DateTime now() => _now;
}

final class _ScriptedTimeoutGuard implements ManagedAiTimeoutGuard {
  _ScriptedTimeoutGuard(this._shouldTimeout);

  final List<bool> _shouldTimeout;
  final List<Duration> timeouts = <Duration>[];

  @override
  Future<T> within<T>(Future<T> future, Duration timeout) async {
    timeouts.add(timeout);
    if (_shouldTimeout.removeAt(0)) throw TimeoutException('private timeout');
    return future;
  }
}

final class _ListDiagnosticSink implements ManagedAiDiagnosticSink {
  const _ListDiagnosticSink(this.events);

  final List<ManagedAiDiagnosticEvent> events;

  @override
  void record(ManagedAiDiagnosticEvent event) => events.add(event);
}
