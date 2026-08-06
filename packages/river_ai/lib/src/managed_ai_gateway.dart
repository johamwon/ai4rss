import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'prompt_registry.dart';
import 'provider.dart';
import 'summary_schema.dart';

enum ManagedAiCapability { articleSummary, deepAnalysis }

enum ManagedAiPlan { free, pro }

final class ManagedAiPrincipal {
  ManagedAiPrincipal({required this.accountKey, required this.plan}) {
    if (!_safeKey.hasMatch(accountKey)) {
      throw ArgumentError.value(accountKey, 'accountKey');
    }
  }

  static final RegExp _safeKey = RegExp(r'^[A-Za-z0-9._:-]{3,128}$');

  final String accountKey;
  final ManagedAiPlan plan;

  @override
  String toString() =>
      'ManagedAiPrincipal(plan: ${plan.name}, account: [REDACTED])';
}

final class ManagedAiGatewayRequest {
  ManagedAiGatewayRequest({
    required this.operationId,
    required this.capability,
    required this.prompt,
    required Map<String, Object?> responseSchema,
    required this.outputLanguage,
    this.maxOutputTokens = 1600,
    this.timeout = const Duration(seconds: 45),
  }) : responseSchema = Map<String, Object?>.unmodifiable(responseSchema) {
    if (!_operationKey.hasMatch(operationId)) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    if (!_languageTag.hasMatch(outputLanguage)) {
      throw ArgumentError.value(outputLanguage, 'outputLanguage');
    }
    if (responseSchema.isEmpty ||
        responseSchema['title'] != prompt.responseSchemaName) {
      throw ArgumentError.value(responseSchema, 'responseSchema');
    }
    if (maxOutputTokens < 1 || maxOutputTokens > 32768) {
      throw RangeError.range(maxOutputTokens, 1, 32768, 'maxOutputTokens');
    }
    if (timeout < const Duration(seconds: 1) ||
        timeout > const Duration(minutes: 2)) {
      throw RangeError.range(
        timeout.inMilliseconds,
        const Duration(seconds: 1).inMilliseconds,
        const Duration(minutes: 2).inMilliseconds,
        'timeout',
      );
    }
  }

  static final RegExp _operationKey = RegExp(r'^[A-Za-z0-9._:-]{3,256}$');
  static final RegExp _languageTag =
      RegExp(r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$');

  final String operationId;
  final ManagedAiCapability capability;
  final AiPrompt prompt;
  final Map<String, Object?> responseSchema;
  final String outputLanguage;
  final int maxOutputTokens;
  final Duration timeout;

  String get fingerprint => sha256
      .convert(
        utf8.encode(
          _canonicalJson(<String, Object?>{
            'capability': capability.name,
            'promptTemplate': prompt.templateId,
            'promptVersion': prompt.version,
            'system': prompt.system,
            'user': prompt.user,
            'schema': responseSchema,
            'language': outputLanguage,
            'maxOutputTokens': maxOutputTokens,
            'timeoutMicros': timeout.inMicroseconds,
          }),
        ),
      )
      .toString();

  @override
  String toString() => 'ManagedAiGatewayRequest('
      'operationIdHash: ${_shortHash(operationId)}, '
      'capability: ${capability.name}, '
      'prompt: ${prompt.versionKey}, '
      'schema: ${prompt.responseSchemaName}, '
      'language: $outputLanguage, '
      'maxOutputTokens: $maxOutputTokens, '
      'timeout: ${timeout.inSeconds}s'
      ')';
}

final class ManagedAiRouteTarget {
  ManagedAiRouteTarget({
    required this.routeId,
    required this.providerId,
    required this.model,
    required this.inputMicrosPerMillionTokens,
    required this.outputMicrosPerMillionTokens,
    this.timeout = const Duration(seconds: 30),
  }) {
    if (!_safeId.hasMatch(routeId) || !_safeId.hasMatch(providerId)) {
      throw ArgumentError('Route and provider identifiers must be safe IDs');
    }
    if (model.trim().isEmpty || model.length > 200) {
      throw ArgumentError.value(model, 'model');
    }
    if (inputMicrosPerMillionTokens < 0 || outputMicrosPerMillionTokens < 0) {
      throw ArgumentError('Provider prices cannot be negative');
    }
    if (timeout < const Duration(seconds: 1) ||
        timeout > const Duration(minutes: 2)) {
      throw ArgumentError.value(timeout, 'timeout');
    }
  }

  static final RegExp _safeId = RegExp(r'^[a-z][a-z0-9_.-]{2,63}$');

  final String routeId;
  final String providerId;
  final String model;
  final int inputMicrosPerMillionTokens;
  final int outputMicrosPerMillionTokens;
  final Duration timeout;

  int costMicros(AiTokenUsage usage) =>
      _ceilDiv(
        usage.inputTokens * inputMicrosPerMillionTokens,
        1000000,
      ) +
      _ceilDiv(
        usage.outputTokens * outputMicrosPerMillionTokens,
        1000000,
      );
}

final class ManagedAiRoutingRule {
  ManagedAiRoutingRule({
    required this.plan,
    required this.capability,
    required List<ManagedAiRouteTarget> targets,
  }) : targets = List<ManagedAiRouteTarget>.unmodifiable(targets) {
    if (targets.isEmpty || targets.length > 4) {
      throw ArgumentError.value(targets.length, 'targets.length');
    }
    if (targets.map((target) => target.routeId).toSet().length !=
        targets.length) {
      throw ArgumentError('Route targets must be unique');
    }
  }

  final ManagedAiPlan plan;
  final ManagedAiCapability capability;
  final List<ManagedAiRouteTarget> targets;
}

final class ManagedAiRoutingTable {
  ManagedAiRoutingTable(Iterable<ManagedAiRoutingRule> rules) {
    for (final rule in rules) {
      final key = _routeKey(rule.plan, rule.capability);
      if (_rules.containsKey(key)) {
        throw ArgumentError('Duplicate managed AI routing rule: $key');
      }
      _rules[key] = rule;
    }
    if (_rules.isEmpty) throw ArgumentError('At least one route is required');
  }

  final Map<String, ManagedAiRoutingRule> _rules =
      <String, ManagedAiRoutingRule>{};

  List<ManagedAiRouteTarget> resolve(
    ManagedAiPlan plan,
    ManagedAiCapability capability,
  ) {
    final rule = _rules[_routeKey(plan, capability)];
    if (rule == null) {
      throw ManagedAiGatewayFailure(
        code: ManagedAiGatewayFailureCode.routeUnavailable,
        retryable: false,
      );
    }
    return rule.targets;
  }
}

/// Implementations bind route IDs to server-owned provider clients and secrets.
/// Neither the client request nor the routing table contains a provider key.
abstract interface class ManagedAiUpstreamRegistry {
  AiProvider resolve(String routeId);
}

final class StaticManagedAiUpstreamRegistry
    implements ManagedAiUpstreamRegistry {
  StaticManagedAiUpstreamRegistry(Map<String, AiProvider> providers)
      : _providers = Map<String, AiProvider>.unmodifiable(providers);

  final Map<String, AiProvider> _providers;

  @override
  AiProvider resolve(String routeId) {
    final provider = _providers[routeId];
    if (provider == null) {
      throw ManagedAiGatewayFailure(
        code: ManagedAiGatewayFailureCode.routeUnavailable,
        retryable: false,
      );
    }
    return provider;
  }
}

abstract interface class ManagedAiOutputValidator {
  bool accepts(ManagedAiGatewayRequest request, AiProviderResponse response);
}

final class AcceptAllManagedAiOutputValidator
    implements ManagedAiOutputValidator {
  const AcceptAllManagedAiOutputValidator();

  @override
  bool accepts(ManagedAiGatewayRequest request, AiProviderResponse response) =>
      true;
}

final class ArticleSummaryManagedAiOutputValidator
    implements ManagedAiOutputValidator {
  const ArticleSummaryManagedAiOutputValidator({
    this.schema = const ArticleSummarySchema(),
  });

  final ArticleSummarySchema schema;

  @override
  bool accepts(ManagedAiGatewayRequest request, AiProviderResponse response) {
    if (request.capability != ManagedAiCapability.articleSummary ||
        request.prompt.responseSchemaName != ArticleSummarySchema.name) {
      return false;
    }
    try {
      schema.parse(
        response.output,
        model: response.model,
        promptVersion: request.prompt.versionKey,
        expectedLanguage: request.outputLanguage,
      );
      return true;
    } on AiSchemaFailure {
      return false;
    }
  }
}

abstract interface class ManagedAiGatewayClock {
  DateTime now();

  Duration elapsed();
}

abstract interface class ManagedAiTimeoutGuard {
  Future<T> within<T>(Future<T> future, Duration timeout);
}

final class FutureManagedAiTimeoutGuard implements ManagedAiTimeoutGuard {
  const FutureManagedAiTimeoutGuard();

  @override
  Future<T> within<T>(Future<T> future, Duration timeout) =>
      future.timeout(timeout);
}

final class ManagedAiRateLimitPolicy {
  const ManagedAiRateLimitPolicy({
    this.maximumRequests = 20,
    this.window = const Duration(minutes: 1),
  });

  final int maximumRequests;
  final Duration window;

  void validate() {
    if (maximumRequests < 1 || maximumRequests > 10000) {
      throw RangeError.range(maximumRequests, 1, 10000, 'maximumRequests');
    }
    if (window < const Duration(seconds: 1) ||
        window > const Duration(days: 1)) {
      throw ArgumentError.value(window, 'window');
    }
  }
}

final class ManagedAiCircuitBreakerPolicy {
  const ManagedAiCircuitBreakerPolicy({
    this.failureThreshold = 2,
    this.openDuration = const Duration(seconds: 30),
  });

  final int failureThreshold;
  final Duration openDuration;

  void validate() {
    if (failureThreshold < 1 || failureThreshold > 100) {
      throw RangeError.range(failureThreshold, 1, 100, 'failureThreshold');
    }
    if (openDuration < const Duration(seconds: 1) ||
        openDuration > const Duration(hours: 1)) {
      throw ArgumentError.value(openDuration, 'openDuration');
    }
  }
}

enum ManagedAiDiagnosticOutcome {
  accepted,
  providerFailure,
  timedOut,
  qualityRejected,
  circuitOpen,
  rateLimited,
}

final class ManagedAiDiagnosticEvent {
  const ManagedAiDiagnosticEvent({
    required this.operationHash,
    required this.capability,
    required this.outcome,
    required this.attempt,
    required this.elapsed,
    required this.costMicros,
    this.routeId,
    this.failureCode,
  });

  final String operationHash;
  final ManagedAiCapability capability;
  final ManagedAiDiagnosticOutcome outcome;
  final int attempt;
  final Duration elapsed;
  final int costMicros;
  final String? routeId;
  final String? failureCode;

  @override
  String toString() => 'ManagedAiDiagnosticEvent('
      'operationHash: $operationHash, '
      'capability: ${capability.name}, '
      'outcome: ${outcome.name}, '
      'attempt: $attempt, '
      'elapsedMs: ${elapsed.inMilliseconds}, '
      'costMicros: $costMicros, '
      'routeId: $routeId, '
      'failureCode: $failureCode'
      ')';
}

abstract interface class ManagedAiDiagnosticSink {
  void record(ManagedAiDiagnosticEvent event);
}

final class NullManagedAiDiagnosticSink implements ManagedAiDiagnosticSink {
  const NullManagedAiDiagnosticSink();

  @override
  void record(ManagedAiDiagnosticEvent event) {}
}

enum ManagedAiGatewayFailureCode {
  idempotencyConflict,
  rateLimited,
  routeUnavailable,
  timeout,
  providerUnavailable,
  qualityRejected,
  invalidRequest,
  cancelled,
}

final class ManagedAiGatewayFailure implements Exception {
  ManagedAiGatewayFailure({
    required this.code,
    required this.retryable,
    this.retryAfter,
  }) {
    if (!retryable && retryAfter != null) {
      throw ArgumentError('Non-retryable failures cannot declare retryAfter');
    }
  }

  final ManagedAiGatewayFailureCode code;
  final bool retryable;
  final Duration? retryAfter;

  @override
  String toString() => 'ManagedAiGatewayFailure('
      'code: ${code.name}, '
      'retryable: $retryable, '
      'retryAfterSeconds: ${retryAfter?.inSeconds}'
      ')';
}

final class ManagedAiGatewayResponse {
  const ManagedAiGatewayResponse({
    required this.response,
    required this.routeId,
    required this.attempts,
    required this.totalCostMicros,
    required this.usedFallback,
  });

  final AiProviderResponse response;
  final String routeId;
  final int attempts;
  final int totalCostMicros;
  final bool usedFallback;

  @override
  String toString() => 'ManagedAiGatewayResponse('
      'routeId: $routeId, '
      'attempts: $attempts, '
      'usedFallback: $usedFallback, '
      'totalCostMicros: $totalCostMicros, '
      'response: $response'
      ')';
}

/// Bridges existing AI orchestration to the managed gateway. The caller's
/// model is deliberately ignored: only the trusted routing table selects an
/// upstream model, and provider credentials remain inside the registry.
final class ManagedAiGatewayProviderAdapter implements AiProvider {
  const ManagedAiGatewayProviderAdapter({
    required this.gateway,
    required this.principal,
    required this.capability,
    required this.outputLanguage,
  });

  final ManagedAiGateway gateway;
  final ManagedAiPrincipal principal;
  final ManagedAiCapability capability;
  final String outputLanguage;

  @override
  String get id => 'river-managed-ai';

  @override
  Future<AiProviderResponse> complete(AiProviderRequest request) async {
    final result = await gateway.complete(
      principal: principal,
      request: ManagedAiGatewayRequest(
        operationId: request.operationId,
        capability: capability,
        prompt: request.prompt,
        responseSchema: request.responseSchema,
        outputLanguage: outputLanguage,
        maxOutputTokens: request.maxOutputTokens,
        timeout: request.timeout,
      ),
    );
    return result.response;
  }
}

final class ManagedAiGateway {
  ManagedAiGateway({
    required ManagedAiRoutingTable routes,
    required ManagedAiUpstreamRegistry upstreams,
    required ManagedAiOutputValidator outputValidator,
    required ManagedAiGatewayClock clock,
    ManagedAiTimeoutGuard timeoutGuard = const FutureManagedAiTimeoutGuard(),
    ManagedAiDiagnosticSink diagnostics = const NullManagedAiDiagnosticSink(),
    ManagedAiRateLimitPolicy rateLimit = const ManagedAiRateLimitPolicy(),
    ManagedAiCircuitBreakerPolicy circuitBreaker =
        const ManagedAiCircuitBreakerPolicy(),
    this.idempotencyRetention = const Duration(hours: 24),
    this.maximumCompletedRequests = 10000,
  })  : _routes = routes,
        _upstreams = upstreams,
        _outputValidator = outputValidator,
        _clock = clock,
        _timeoutGuard = timeoutGuard,
        _diagnostics = diagnostics,
        _rateLimit = rateLimit,
        _circuitPolicy = circuitBreaker {
    rateLimit.validate();
    circuitBreaker.validate();
    if (idempotencyRetention < const Duration(minutes: 1) ||
        idempotencyRetention > const Duration(days: 7)) {
      throw ArgumentError.value(idempotencyRetention, 'idempotencyRetention');
    }
    if (maximumCompletedRequests < 1 || maximumCompletedRequests > 1000000) {
      throw RangeError.range(
        maximumCompletedRequests,
        1,
        1000000,
        'maximumCompletedRequests',
      );
    }
  }

  final ManagedAiRoutingTable _routes;
  final ManagedAiUpstreamRegistry _upstreams;
  final ManagedAiOutputValidator _outputValidator;
  final ManagedAiGatewayClock _clock;
  final ManagedAiTimeoutGuard _timeoutGuard;
  final ManagedAiDiagnosticSink _diagnostics;
  final ManagedAiRateLimitPolicy _rateLimit;
  final ManagedAiCircuitBreakerPolicy _circuitPolicy;
  final Duration idempotencyRetention;
  final int maximumCompletedRequests;
  final Map<String, _RateWindow> _rateWindows = <String, _RateWindow>{};
  final Map<String, _CircuitState> _circuits = <String, _CircuitState>{};
  final Map<String, _InFlightRequest> _inFlight = <String, _InFlightRequest>{};
  final Map<String, _CompletedRequest> _completed =
      <String, _CompletedRequest>{};

  Future<ManagedAiGatewayResponse> complete({
    required ManagedAiPrincipal principal,
    required ManagedAiGatewayRequest request,
  }) {
    final key = '${principal.accountKey}:${request.operationId}';
    final fingerprint = sha256
        .convert(utf8.encode('${principal.plan.name}:${request.fingerprint}'))
        .toString();
    final now = _clock.now().toUtc();
    var completed = _completed[key];
    if (completed != null &&
        !now.isBefore(completed.completedAt.add(idempotencyRetention))) {
      _completed.remove(key);
      completed = null;
    }
    if (completed != null) {
      _ensureSameFingerprint(completed.fingerprint, fingerprint);
      return Future<ManagedAiGatewayResponse>.value(completed.response);
    }
    final running = _inFlight[key];
    if (running != null) {
      _ensureSameFingerprint(running.fingerprint, fingerprint);
      return running.future;
    }

    final future = _execute(principal, request);
    _inFlight[key] = _InFlightRequest(fingerprint, future);
    unawaited(
      future.then<void>(
        (response) {
          _pruneCompleted(_clock.now().toUtc());
          _completed[key] = _CompletedRequest(
            fingerprint,
            response,
            _clock.now().toUtc(),
          );
          _inFlight.remove(key);
        },
        onError: (Object _, StackTrace __) {
          _inFlight.remove(key);
        },
      ),
    );
    return future;
  }

  void _pruneCompleted(DateTime now) {
    _completed.removeWhere(
      (key, value) =>
          !now.isBefore(value.completedAt.add(idempotencyRetention)),
    );
    while (_completed.length >= maximumCompletedRequests) {
      _completed.remove(_completed.keys.first);
    }
  }

  Future<ManagedAiGatewayResponse> _execute(
    ManagedAiPrincipal principal,
    ManagedAiGatewayRequest request,
  ) async {
    _consumeRateLimit(principal, request);
    final targets = _routes.resolve(principal.plan, request.capability);
    final started = _clock.elapsed();
    var totalCostMicros = 0;
    var attempted = 0;
    ManagedAiGatewayFailureCode finalCode =
        ManagedAiGatewayFailureCode.routeUnavailable;

    for (var targetIndex = 0; targetIndex < targets.length; targetIndex += 1) {
      final target = targets[targetIndex];
      final circuit = _circuits.putIfAbsent(
        target.routeId,
        _CircuitState.new,
      );
      if (!circuit.tryAcquire(_clock.now().toUtc(), _circuitPolicy)) {
        _record(
          request,
          target,
          attempted,
          ManagedAiDiagnosticOutcome.circuitOpen,
          started,
          0,
          ManagedAiGatewayFailureCode.providerUnavailable.name,
        );
        finalCode = ManagedAiGatewayFailureCode.providerUnavailable;
        continue;
      }

      final elapsed = _clock.elapsed() - started;
      final remaining = request.timeout - elapsed;
      if (remaining <= Duration.zero) {
        circuit.releaseProbe();
        finalCode = ManagedAiGatewayFailureCode.timeout;
        break;
      }
      attempted += 1;
      final attemptTimeout =
          remaining < target.timeout ? remaining : target.timeout;
      final provider = _upstreams.resolve(target.routeId);
      if (provider.id != target.providerId) {
        circuit.onFailure(_clock.now().toUtc(), _circuitPolicy);
        finalCode = ManagedAiGatewayFailureCode.routeUnavailable;
        continue;
      }

      try {
        final response = await _timeoutGuard.within(
          provider.complete(
            AiProviderRequest(
              operationId: request.operationId,
              model: target.model,
              prompt: request.prompt,
              responseSchema: request.responseSchema,
              maxOutputTokens: request.maxOutputTokens,
              timeout: attemptTimeout,
            ),
          ),
          attemptTimeout,
        );
        final attemptCost = target.costMicros(response.usage);
        totalCostMicros += attemptCost;
        if (!_outputValidator.accepts(request, response)) {
          circuit.onFailure(_clock.now().toUtc(), _circuitPolicy);
          finalCode = ManagedAiGatewayFailureCode.qualityRejected;
          _record(
            request,
            target,
            attempted,
            ManagedAiDiagnosticOutcome.qualityRejected,
            started,
            attemptCost,
            finalCode.name,
          );
          continue;
        }
        circuit.onSuccess();
        _record(
          request,
          target,
          attempted,
          ManagedAiDiagnosticOutcome.accepted,
          started,
          attemptCost,
          null,
        );
        return ManagedAiGatewayResponse(
          response: response,
          routeId: target.routeId,
          attempts: attempted,
          totalCostMicros: totalCostMicros,
          usedFallback: targetIndex > 0,
        );
      } on TimeoutException {
        circuit.onFailure(_clock.now().toUtc(), _circuitPolicy);
        finalCode = ManagedAiGatewayFailureCode.timeout;
        _record(
          request,
          target,
          attempted,
          ManagedAiDiagnosticOutcome.timedOut,
          started,
          0,
          finalCode.name,
        );
      } on AiProviderFailure catch (failure) {
        final mapped = _mapProviderFailure(failure);
        finalCode = mapped;
        if (!_canFallback(failure.code)) {
          circuit.releaseProbe();
          throw ManagedAiGatewayFailure(
            code: mapped,
            retryable: failure.retryable,
            retryAfter: failure.retryAfter,
          );
        }
        circuit.onFailure(_clock.now().toUtc(), _circuitPolicy);
        _record(
          request,
          target,
          attempted,
          ManagedAiDiagnosticOutcome.providerFailure,
          started,
          0,
          failure.code.name,
        );
      }
    }

    throw ManagedAiGatewayFailure(
      code: finalCode,
      retryable: finalCode != ManagedAiGatewayFailureCode.invalidRequest &&
          finalCode != ManagedAiGatewayFailureCode.cancelled,
    );
  }

  void _consumeRateLimit(
    ManagedAiPrincipal principal,
    ManagedAiGatewayRequest request,
  ) {
    final now = _clock.now().toUtc();
    final key = '${principal.accountKey}:${request.capability.name}';
    var window = _rateWindows[key];
    if (window == null ||
        !now.isBefore(window.startedAt.add(_rateLimit.window))) {
      window = _RateWindow(now);
      _rateWindows[key] = window;
    }
    if (window.count >= _rateLimit.maximumRequests) {
      final retryAfter =
          window.startedAt.add(_rateLimit.window).difference(now);
      _diagnostics.record(
        ManagedAiDiagnosticEvent(
          operationHash: _shortHash(request.operationId),
          capability: request.capability,
          outcome: ManagedAiDiagnosticOutcome.rateLimited,
          attempt: 0,
          elapsed: Duration.zero,
          costMicros: 0,
          failureCode: ManagedAiGatewayFailureCode.rateLimited.name,
        ),
      );
      throw ManagedAiGatewayFailure(
        code: ManagedAiGatewayFailureCode.rateLimited,
        retryable: true,
        retryAfter: retryAfter,
      );
    }
    window.count += 1;
  }

  void _record(
    ManagedAiGatewayRequest request,
    ManagedAiRouteTarget target,
    int attempt,
    ManagedAiDiagnosticOutcome outcome,
    Duration started,
    int costMicros,
    String? failureCode,
  ) {
    _diagnostics.record(
      ManagedAiDiagnosticEvent(
        operationHash: _shortHash(request.operationId),
        capability: request.capability,
        outcome: outcome,
        attempt: attempt,
        elapsed: _clock.elapsed() - started,
        costMicros: costMicros,
        routeId: target.routeId,
        failureCode: failureCode,
      ),
    );
  }
}

final class _RateWindow {
  _RateWindow(this.startedAt);

  final DateTime startedAt;
  int count = 0;
}

final class _CircuitState {
  int failures = 0;
  DateTime? openUntil;
  bool probeInFlight = false;

  bool tryAcquire(DateTime now, ManagedAiCircuitBreakerPolicy policy) {
    final until = openUntil;
    if (until == null) return true;
    if (now.isBefore(until)) return false;
    if (probeInFlight) return false;
    probeInFlight = true;
    return true;
  }

  void onSuccess() {
    failures = 0;
    openUntil = null;
    probeInFlight = false;
  }

  void onFailure(DateTime now, ManagedAiCircuitBreakerPolicy policy) {
    failures += 1;
    probeInFlight = false;
    if (failures >= policy.failureThreshold) {
      openUntil = now.add(policy.openDuration);
    }
  }

  void releaseProbe() => probeInFlight = false;
}

final class _InFlightRequest {
  const _InFlightRequest(this.fingerprint, this.future);

  final String fingerprint;
  final Future<ManagedAiGatewayResponse> future;
}

final class _CompletedRequest {
  const _CompletedRequest(this.fingerprint, this.response, this.completedAt);

  final String fingerprint;
  final ManagedAiGatewayResponse response;
  final DateTime completedAt;
}

String _routeKey(ManagedAiPlan plan, ManagedAiCapability capability) =>
    '${plan.name}:${capability.name}';

void _ensureSameFingerprint(String expected, String actual) {
  if (expected != actual) {
    throw ManagedAiGatewayFailure(
      code: ManagedAiGatewayFailureCode.idempotencyConflict,
      retryable: false,
    );
  }
}

bool _canFallback(AiProviderFailureCode code) => switch (code) {
      AiProviderFailureCode.authenticationRequired ||
      AiProviderFailureCode.quotaExceeded ||
      AiProviderFailureCode.rateLimited ||
      AiProviderFailureCode.timeout ||
      AiProviderFailureCode.unavailable =>
        true,
      AiProviderFailureCode.invalidRequest ||
      AiProviderFailureCode.cancelled =>
        false,
    };

ManagedAiGatewayFailureCode _mapProviderFailure(AiProviderFailure failure) =>
    switch (failure.code) {
      AiProviderFailureCode.timeout => ManagedAiGatewayFailureCode.timeout,
      AiProviderFailureCode.invalidRequest =>
        ManagedAiGatewayFailureCode.invalidRequest,
      AiProviderFailureCode.cancelled => ManagedAiGatewayFailureCode.cancelled,
      AiProviderFailureCode.authenticationRequired ||
      AiProviderFailureCode.quotaExceeded ||
      AiProviderFailureCode.rateLimited ||
      AiProviderFailureCode.unavailable =>
        ManagedAiGatewayFailureCode.providerUnavailable,
    };

String _shortHash(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 16);

int _ceilDiv(int value, int divisor) => (value + divisor - 1) ~/ divisor;

String _canonicalJson(Object? value) {
  Object? normalize(Object? item) {
    if (item is Map) {
      final keys = item.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: normalize(item[key]),
      };
    }
    if (item is List) {
      return item.map(normalize).toList(growable: false);
    }
    return item;
  }

  return jsonEncode(normalize(value));
}
