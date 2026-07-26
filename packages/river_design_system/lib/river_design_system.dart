library;

import 'package:flutter/material.dart';

abstract final class RiverTheme {
  static const _lightSeed = Color(0xFF146C5A);
  static const _darkSeed = Color(0xFF65D6B5);

  static ThemeData light() => _theme(
        seedColor: _lightSeed,
        brightness: Brightness.light,
      );

  static ThemeData dark() => _theme(
        seedColor: _darkSeed,
        brightness: Brightness.dark,
      );

  static ThemeData highContrastLight() => _theme(
        seedColor: _lightSeed,
        brightness: Brightness.light,
        contrastLevel: 1,
      );

  static ThemeData highContrastDark() => _theme(
        seedColor: _darkSeed,
        brightness: Brightness.dark,
        contrastLevel: 1,
      );

  static ThemeData _theme({
    required Color seedColor,
    required Brightness brightness,
    double contrastLevel = 0,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );
    return ThemeData(
      colorScheme: colorScheme,
      focusColor: colorScheme.primary.withValues(alpha: 0.24),
      useMaterial3: true,
    );
  }
}
