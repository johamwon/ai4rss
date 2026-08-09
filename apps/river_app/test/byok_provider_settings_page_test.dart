import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_ai/river_ai.dart';
import 'package:river_app/settings/byok_provider_settings_page.dart';
import 'package:river_byok/river_byok.dart';

void main() {
  testWidgets('user can save and test an AI BYOK profile', (tester) async {
    final aiVault = _AiVault();
    final mediaVault = _MediaVault();
    final transport = _Transport(
      ByokHttpResponse(
        statusCode: 200,
        body: utf8.encode('{"data":[{"id":"gpt-4.1-mini"}]}'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ByokProviderSettingsPage(
          aiVault: aiVault,
          mediaVault: mediaVault,
          connections: ByokProviderConnectionService(transport: transport),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 摘要'), findsOneWidget);
    expect(find.text('云端 TTS'), findsOneWidget);
    expect(find.textContaining('只保存在本机系统安全存储'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'API Key').first,
      'widget-provider-secret',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存').first);
    await tester.pumpAndSettle();
    expect(aiVault.value?.model, 'gpt-4.1-mini');
    expect(aiVault.value?.apiKey.reveal(), 'widget-provider-secret');
    expect(find.text('已保存 Key'), findsOneWidget);

    final testButton = find.widgetWithText(OutlinedButton, '测试连接').first;
    await tester.ensureVisible(testButton);
    await tester.pumpAndSettle();
    await tester.tap(testButton);
    await tester.pumpAndSettle();
    expect(find.text('API 与 Key 验证成功'), findsOneWidget);
    expect(
      transport.requests.single.headers['authorization'],
      'Bearer widget-provider-secret',
    );

    await tester.scrollUntilVisible(
      find.text('播客转录'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('播客转录'), findsOneWidget);
  });
}

final class _AiVault implements AiByokConfigurationVault {
  AiByokConfiguration? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AiByokConfiguration?> read() async => value;

  @override
  Future<void> write(AiByokConfiguration configuration) async =>
      value = configuration;
}

final class _MediaVault implements ByokMediaConfigurationVault {
  final Map<ByokMediaCapability, ByokMediaConfiguration> values =
      <ByokMediaCapability, ByokMediaConfiguration>{};

  @override
  Future<void> clear(ByokMediaCapability capability) async =>
      values.remove(capability);

  @override
  Future<ByokMediaConfiguration?> read(ByokMediaCapability capability) async =>
      values[capability];

  @override
  Future<void> write(ByokMediaConfiguration configuration) async =>
      values[configuration.capability] = configuration;
}

final class _Transport implements ByokHttpTransport {
  _Transport(this.response);

  final ByokHttpResponse response;
  final List<ByokHttpRequest> requests = <ByokHttpRequest>[];

  @override
  Future<ByokHttpResponse> send(ByokHttpRequest request) async {
    requests.add(request);
    return response;
  }
}
