library;

import 'package:flutter/material.dart';

abstract final class RiverTheme {
  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF146C5A),
        ),
        useMaterial3: true,
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF65D6B5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
