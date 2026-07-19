import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_app/app/app_dependencies.dart';
import 'package:river_app/app/river_application.dart';
import 'package:river_data/river_data.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_extract/river_extract.dart';
import 'package:river_platform/river_platform.dart';

final class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 7, 15);
}

final class _FixedIds implements IdGenerator {
  var value = 0;

  @override
  String next() => 'fixed-${++value}';
}

final class _FakePlatform implements RiverPlatformBridge {
  @override
  Future<String> platformVersion() async => 'test';
}

final class _FakeHttp implements HttpPort {
  final List<Uri> requests = <Uri>[];
  Completer<void>? _nextFeedGate;
  Completer<void>? _activeFeedGate;
  Completer<void>? _nextFeedStarted;

  Future<void> get nextFeedStarted => _nextFeedStarted!.future;

  void blockNextFeedRequest() {
    _nextFeedGate = Completer<void>();
    _nextFeedStarted = Completer<void>();
  }

  void releaseFeedRequest() {
    final gate = _activeFeedGate ?? _nextFeedGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    requests.add(uri);
    if (uri.path == '/') {
      return PortHttpResponse(
        statusCode: 200,
        body: '''
          <!doctype html><html><head>
            <link rel="alternate" type="application/rss+xml" href="/feed.xml">
          </head></html>
        ''',
        headers: const <String, String>{'content-type': 'text/html'},
        effectiveUri: uri,
      );
    }
    final gate = _nextFeedGate;
    if (gate != null) {
      _nextFeedGate = null;
      _activeFeedGate = gate;
      _nextFeedStarted?.complete();
      await gate.future;
      _activeFeedGate = null;
    }
    return PortHttpResponse(
      statusCode: 200,
      body: '''
      <rss version="2.0"><channel><title>Test Feed</title>
        <item><guid>one</guid><title>First article</title>
        <link>https://example.test/one</link></item>
      </channel></rss>
    ''',
      headers: const <String, String>{'content-type': 'application/rss+xml'},
      effectiveUri: uri,
    );
  }
}

final class _FakeOpmlFiles implements OpmlFileGateway {
  String? importSource;
  String? exportedContents;

  @override
  Future<String?> pickImport() async => importSource;

  @override
  Future<bool> saveExport(String contents) async {
    exportedContents = contents;
    return true;
  }
}

void main() {
  late AppDependencies dependencies;
  late _FakeHttp http;
  late _FakeOpmlFiles opmlFiles;

  setUp(() {
    http = _FakeHttp();
    opmlFiles = _FakeOpmlFiles();
    dependencies = AppDependencies(
      clock: _FixedClock(),
      ids: _FixedIds(),
      fullTextExtractor: const LayeredFullTextExtractor(),
      platform: _FakePlatform(),
      http: http,
      opmlFiles: opmlFiles,
      database: RiverDatabase.inMemory(),
    );
  });

  tearDown(() => dependencies.close());

  testWidgets('empty inbox is accessible', (tester) async {
    await tester.pumpWidget(RiverApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('River'), findsOneWidget);
    expect(find.text('还没有订阅源'), findsOneWidget);
    expect(find.byTooltip('添加订阅源'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('adds a feed and renders its first article', (tester) async {
    await tester.pumpWidget(RiverApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加订阅源'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.test/feed.xml',
    );
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('操作失败'), findsNothing);
    expect(find.text('Test Feed'), findsWidgets);
    expect(find.text('First article'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('creates and shows an empty folder', (tester) async {
    await tester.pumpWidget(RiverApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('订阅与 OPML'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '技术');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('技术'), findsOneWidget);
    expect(find.text('文件夹为空'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('discovers a declared feed from a website address',
      (tester) async {
    await tester.pumpWidget(RiverApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加订阅源'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.test');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('操作失败'), findsNothing);
    expect(find.text('Test Feed'), findsWidgets);
    expect(http.requests, <Uri>[
      Uri.parse('https://example.test/'),
      Uri.parse('https://example.test/feed.xml'),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('imports and exports OPML while preserving folders',
      (tester) async {
    opmlFiles.importSource = '''
      <opml version="2.0"><head><title>Fixture</title></head><body>
        <outline text="技术"><outline text="AI">
          <outline text="AI Daily" xmlUrl="https://ai.test/feed.xml" />
        </outline></outline>
        <outline text="Loose" xmlUrl="https://loose.test/rss" />
      </body></opml>
    ''';
    await tester.pumpWidget(RiverApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('订阅与 OPML'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入 OPML'));
    await tester.pumpAndSettle();

    expect(find.text('技术 / AI'), findsOneWidget);
    expect(find.text('AI Daily'), findsOneWidget);
    expect(find.text('Loose'), findsOneWidget);
    expect(http.requests, isEmpty);

    await tester.tap(find.byTooltip('订阅与 OPML'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 OPML'));
    await tester.pumpAndSettle();

    expect(opmlFiles.exportedContents, contains('https://ai.test/feed.xml'));
    expect(opmlFiles.exportedContents, contains('技术'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows progress and cancels a durable refresh', (tester) async {
    try {
      await tester.pumpWidget(RiverApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加订阅源'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://example.test/feed.xml',
      );
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      http.blockNextFeedRequest();
      await tester.tap(find.byTooltip('刷新全部'));
      await tester.pump();
      await http.nextFeedStarted;
      await tester.pump();

      expect(find.byTooltip('取消刷新'), findsOneWidget);
      expect(find.text('正在刷新 0/1 个来源'), findsOneWidget);
      await tester.tap(find.byTooltip('取消刷新'));
      await tester.pump();
      expect(find.text('正在停止刷新，已开始的请求会安全结束'), findsOneWidget);

      http.releaseFeedRequest();
      for (var attempt = 0; attempt < 50; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.textContaining('刷新已取消').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('刷新已取消'), findsOneWidget);
      expect(find.byTooltip('刷新全部'), findsOneWidget);
    } finally {
      http.releaseFeedRequest();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });

  test('secure IDs keep UUID v4 shape and do not repeat', () {
    final generator = SecureIdGenerator();
    final first = generator.next();
    final second = generator.next();

    expect(first, isNot(second));
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
