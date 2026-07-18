import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_domain/river_domain.dart';
import 'package:river_platform/river_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('platform WebView renders script-generated article HTML', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      request.response
        ..headers.contentType = ContentType.html
        ..write('''
<!doctype html><html><body><main id="article"></main>
<script>
document.getElementById('article').innerHTML =
  '<h1>Dynamic article</h1><p>${'rendered text ' * 20}</p>';
</script></body></html>
''');
      unawaited(request.response.close());
    });

    try {
      final result = await InAppWebViewDynamicPageRenderer().render(
        DynamicPageRenderRequest(
          sourceUri: Uri.parse('http://127.0.0.1:${server.port}/article'),
        ),
      );
      expect(result, isA<DynamicPageRenderSuccess>());
      expect(
        (result as DynamicPageRenderSuccess).html,
        contains('Dynamic article'),
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
