import 'package:flutter/widgets.dart';

import 'app_dependencies.dart';

final class RiverDependenciesScope extends InheritedWidget {
  const RiverDependenciesScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RiverDependenciesScope>();
    assert(
      scope != null,
      'RiverDependenciesScope is missing above this context.',
    );
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(RiverDependenciesScope oldWidget) {
    return !identical(dependencies, oldWidget.dependencies);
  }
}
