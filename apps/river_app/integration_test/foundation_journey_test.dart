import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:river_app/app/app_dependencies.dart';
import 'package:river_app/app/river_application.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts with a real persistent database', (tester) async {
    final dependencies = await AppDependencies.production();
    addTearDown(dependencies.close);
    await tester.pumpWidget(RiverApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('River'), findsOneWidget);
    expect(find.byTooltip('添加订阅源'), findsOneWidget);
  });
}
