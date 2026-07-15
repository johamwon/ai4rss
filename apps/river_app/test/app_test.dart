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
  @override
  Future<PortHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async =>
      PortHttpResponse(
        statusCode: 200,
        body: '''
      <rss version="2.0"><channel><title>Test Feed</title>
        <item><guid>one</guid><title>First article</title>
        <link>https://example.test/one</link></item>
      </channel></rss>
    ''',
        effectiveUri: uri,
      );
}

void main() {
  late AppDependencies dependencies;

  setUp(() {
    dependencies = AppDependencies(
      clock: _FixedClock(),
      ids: _FixedIds(),
      fullTextExtractor: const BasicHtmlExtractor(),
      platform: _FakePlatform(),
      http: _FakeHttp(),
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
    expect(find.text('Test Feed'), findsOneWidget);
    expect(find.text('First article'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
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
