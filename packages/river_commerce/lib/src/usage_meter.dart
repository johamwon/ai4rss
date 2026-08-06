final class UsageBalance {
  const UsageBalance({required this.capability, required this.remaining});

  final String capability;
  final int remaining;
}

final class UsageMeter {
  UsageMeter(Map<String, int> initialBalances)
      : _balances = Map<String, int>.from(initialBalances);

  final Map<String, int> _balances;
  final Map<String, UsageBalance> _completed = <String, UsageBalance>{};

  UsageBalance consume({
    required String idempotencyKey,
    required String capability,
    required int amount,
    required bool producedUsableResult,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final existing = _completed[idempotencyKey];
    if (existing != null) return existing;

    final current = _balances[capability] ?? 0;
    if (!producedUsableResult) {
      return UsageBalance(capability: capability, remaining: current);
    }
    if (current < amount) {
      throw StateError('Insufficient $capability balance');
    }
    final result = UsageBalance(
      capability: capability,
      remaining: current - amount,
    );
    _balances[capability] = result.remaining;
    _completed[idempotencyKey] = result;
    return result;
  }

  int remaining(String capability) => _balances[capability] ?? 0;
}
