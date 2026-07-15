import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/river_application.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.production();
  runApp(RiverApp(dependencies: dependencies));
}
