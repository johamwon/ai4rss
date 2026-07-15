import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_feed/river_feed.dart';
import 'package:river_platform/river_platform.dart';

final class AppDependencies {
  AppDependencies({
    required this.clock,
    required this.ids,
    required this.fullTextExtractor,
    required this.platform,
    required this.http,
    required RiverDatabase database,
  }) : _database = database {
    jobs = PersistentJobQueue(database);
    feeds = DriftFeedRepository(database);
    feedRefresh = FeedRefreshService(
      http: http,
      repository: feeds,
      clock: clock,
      ids: ids,
    );
  }

  static Future<AppDependencies> production() async {
    final database = RiverDatabase(
      driftDatabase(
        name: 'river',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      ),
    );
    await database.verifyReady();
    final http = BoundedHttpPort.standard();
    return AppDependencies(
      clock: const SystemClock(),
      ids: SecureIdGenerator(),
      fullTextExtractor: const BasicHtmlExtractor(),
      platform: const MethodChannelRiverPlatform(),
      http: http,
      database: database,
    );
  }

  final Clock clock;
  final IdGenerator ids;
  final FullTextExtractor fullTextExtractor;
  final RiverPlatformBridge platform;
  final HttpPort http;
  late final PersistentJobQueue jobs;
  late final DriftFeedRepository feeds;
  late final FeedRefreshService feedRefresh;
  final RiverDatabase _database;

  Future<void> close() async {
    final httpPort = http;
    if (httpPort is BoundedHttpPort) {
      httpPort.close();
    }
    await _database.close();
  }
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final class SecureIdGenerator implements IdGenerator {
  SecureIdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
