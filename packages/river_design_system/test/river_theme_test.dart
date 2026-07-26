import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_design_system/river_design_system.dart';

void main() {
  test('high contrast themes meet critical WCAG text contrast ratios', () {
    for (final theme in <ThemeData>[
      RiverTheme.highContrastLight(),
      RiverTheme.highContrastDark(),
    ]) {
      final colors = theme.colorScheme;
      expect(
        _contrast(colors.primary, colors.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.surface, colors.onSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.error, colors.onError),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.errorContainer, colors.onErrorContainer),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('normal and high contrast themes preserve their brightness', () {
    expect(RiverTheme.light().brightness, Brightness.light);
    expect(RiverTheme.highContrastLight().brightness, Brightness.light);
    expect(RiverTheme.dark().brightness, Brightness.dark);
    expect(RiverTheme.highContrastDark().brightness, Brightness.dark);
  });
}

double _contrast(Color first, Color second) {
  final lighter =
      first.computeLuminance() >= second.computeLuminance() ? first : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
