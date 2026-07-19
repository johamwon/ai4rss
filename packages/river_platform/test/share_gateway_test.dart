import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('maps the domain request into bounded platform share parameters',
      () async {
    ShareParams? captured;
    final gateway = SharePlusGateway(
      share: (params) async {
        captured = params;
        return const ShareResult('mail', ShareResultStatus.success);
      },
    );

    final outcome = await gateway.share(
      const ShareRequest(
        title: 'Article title',
        subject: 'Article subject',
        text: 'Article title\nhttps://example.test/article',
        anchor: ShareAnchor(left: 10, top: 20, width: 30, height: 40),
      ),
    );

    expect(outcome, ShareOutcome.completed);
    expect(captured!.title, 'Article title');
    expect(captured!.subject, 'Article subject');
    expect(captured!.text, contains('https://example.test/article'));
    expect(captured!.sharePositionOrigin!.left, 10);
    expect(captured!.sharePositionOrigin!.height, 40);
  });

  test('maps dismissed and unavailable without exposing plugin details',
      () async {
    final dismissed = SharePlusGateway(
      share: (_) async => const ShareResult('', ShareResultStatus.dismissed),
    );
    final unavailable = SharePlusGateway(
      share: (_) async => ShareResult.unavailable,
    );

    expect(
      await dismissed.share(const ShareRequest(text: 'safe text')),
      ShareOutcome.dismissed,
    );
    expect(
      await unavailable.share(const ShareRequest(text: 'safe text')),
      ShareOutcome.unavailable,
    );
  });
}
