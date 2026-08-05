final class AutomaticSummarySettings {
  const AutomaticSummarySettings({
    this.enabled = false,
    this.wifiOnly = true,
    this.dailyLimit = 3,
    this.minimumRankingScore = 0.7,
  });

  static const int maximumDailyLimit = 50;

  final bool enabled;
  final bool wifiOnly;
  final int dailyLimit;
  final double minimumRankingScore;

  AutomaticSummarySettings copyWith({
    bool? enabled,
    bool? wifiOnly,
    int? dailyLimit,
    double? minimumRankingScore,
  }) =>
      AutomaticSummarySettings(
        enabled: enabled ?? this.enabled,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        dailyLimit: dailyLimit ?? this.dailyLimit,
        minimumRankingScore: minimumRankingScore ?? this.minimumRankingScore,
      );

  void validate() {
    if (dailyLimit < 1 ||
        dailyLimit > maximumDailyLimit ||
        !minimumRankingScore.isFinite ||
        minimumRankingScore < 0 ||
        minimumRankingScore > 1) {
      throw const FormatException('Invalid automatic summary settings.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AutomaticSummarySettings &&
      other.enabled == enabled &&
      other.wifiOnly == wifiOnly &&
      other.dailyLimit == dailyLimit &&
      other.minimumRankingScore == minimumRankingScore;

  @override
  int get hashCode =>
      Object.hash(enabled, wifiOnly, dailyLimit, minimumRankingScore);
}

enum AutomaticSummaryUsageStatus { reserved, completed }

enum AutomaticSummaryReservationResult {
  reserved,
  alreadyReserved,
  alreadyCompleted,
  limitReached,
}

final class AutomaticSummaryUsageSnapshot {
  const AutomaticSummaryUsageSnapshot({
    required this.dayKey,
    required this.reserved,
    required this.completed,
  });

  final String dayKey;
  final int reserved;
  final int completed;

  int get consumed => reserved + completed;
}

abstract interface class AutomaticSummaryRepository {
  Stream<AutomaticSummarySettings> watchSettings();

  Future<AutomaticSummarySettings> readSettings();

  Future<void> saveSettings(
    AutomaticSummarySettings settings, {
    required DateTime updatedAt,
  });

  Future<AutomaticSummaryReservationResult> reserveUsage({
    required String idempotencyKey,
    required String articleId,
    required String dayKey,
    required int dailyLimit,
    required DateTime now,
  });

  Future<void> completeUsage({
    required String idempotencyKey,
    required DateTime completedAt,
  });

  Future<void> releaseUsage({required String idempotencyKey});

  Future<AutomaticSummaryUsageStatus?> readUsageStatus(
    String idempotencyKey,
  );

  Future<AutomaticSummaryUsageSnapshot> readUsage(String dayKey);
}

enum AutomaticSummaryNetworkKind { offline, wifi, other, unknown }

abstract interface class AutomaticSummaryNetworkMonitor {
  Future<AutomaticSummaryNetworkKind> check();

  Stream<AutomaticSummaryNetworkKind> get changes;
}

final class UnknownAutomaticSummaryNetworkMonitor
    implements AutomaticSummaryNetworkMonitor {
  const UnknownAutomaticSummaryNetworkMonitor();

  @override
  Future<AutomaticSummaryNetworkKind> check() async =>
      AutomaticSummaryNetworkKind.unknown;

  @override
  Stream<AutomaticSummaryNetworkKind> get changes =>
      const Stream<AutomaticSummaryNetworkKind>.empty();
}
