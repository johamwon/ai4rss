import 'package:flutter_test/flutter_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  test('opens a public HTTP(S) article in the external application', () async {
    Uri? captured;
    final gateway = UrlLauncherExternalUriGateway(
      launch: (uri) async {
        captured = uri;
        return true;
      },
    );
    final uri = Uri.parse('https://example.test/article');

    expect(await gateway.open(uri), ExternalUriOpenOutcome.opened);
    expect(captured, uri);
  });

  test('rejects local, credentialed, and non-web URIs before launch', () async {
    var calls = 0;
    final gateway = UrlLauncherExternalUriGateway(
      launch: (_) async {
        calls += 1;
        return true;
      },
    );

    for (final uri in <Uri>[
      Uri.parse('file:///private/article'),
      Uri.parse('javascript:alert(1)'),
      Uri.parse('https://user:secret@example.test/article'),
      Uri.parse('https:///missing-host'),
    ]) {
      expect(await gateway.open(uri), ExternalUriOpenOutcome.unavailable);
    }
    expect(calls, 0);
  });

  test('maps launcher false and exceptions to a safe unavailable outcome',
      () async {
    final unavailable = UrlLauncherExternalUriGateway(
      launch: (_) async => false,
    );
    final failed = UrlLauncherExternalUriGateway(
      launch: (_) async => throw StateError('private platform detail'),
    );
    final uri = Uri.parse('https://example.test/article');

    expect(
      await unavailable.open(uri),
      ExternalUriOpenOutcome.unavailable,
    );
    expect(await failed.open(uri), ExternalUriOpenOutcome.unavailable);
  });
}
