library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class RiverTypography {
  static List<String> sansSerifFamilies(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.windows => const <String>[
            'Microsoft YaHei UI',
            'Microsoft YaHei',
            'Microsoft JhengHei UI',
            'Microsoft JhengHei',
            'Noto Sans CJK SC',
            'Segoe UI',
            'Segoe UI Emoji',
            'sans-serif',
          ],
        TargetPlatform.iOS || TargetPlatform.macOS => const <String>[
            'PingFang SC',
            'PingFang TC',
            'Hiragino Sans GB',
            'Heiti SC',
            'Apple Color Emoji',
            'sans-serif',
          ],
        TargetPlatform.android ||
        TargetPlatform.fuchsia ||
        TargetPlatform.linux =>
          const <String>[
            'Noto Sans CJK SC',
            'Noto Sans SC',
            'Noto Sans CJK TC',
            'Noto Sans',
            'Noto Color Emoji',
            'sans-serif',
          ],
      };

  static List<String> serifFamilies(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.windows => const <String>[
            'SimSun',
            'Microsoft YaHei UI',
            'Noto Serif CJK SC',
            'Microsoft JhengHei UI',
            'Georgia',
            'serif',
          ],
        TargetPlatform.iOS || TargetPlatform.macOS => const <String>[
            'Songti SC',
            'Songti TC',
            'STSong',
            'PingFang SC',
            'Apple Color Emoji',
            'serif',
          ],
        TargetPlatform.android ||
        TargetPlatform.fuchsia ||
        TargetPlatform.linux =>
          const <String>[
            'Noto Serif CJK SC',
            'Noto Serif SC',
            'Noto Serif CJK TC',
            'Noto Sans CJK SC',
            'Noto Color Emoji',
            'serif',
          ],
      };
}

abstract final class RiverTheme {
  static const _lightSeed = Color(0xFF146C5A);
  static const _darkSeed = Color(0xFF65D6B5);

  static ThemeData light({String? fontFamily, TargetPlatform? platform}) =>
      _theme(
        seedColor: _lightSeed,
        brightness: Brightness.light,
        fontFamily: fontFamily,
        platform: platform,
      );

  static ThemeData dark({String? fontFamily, TargetPlatform? platform}) =>
      _theme(
        seedColor: _darkSeed,
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        platform: platform,
      );

  static ThemeData highContrastLight({
    String? fontFamily,
    TargetPlatform? platform,
  }) =>
      _theme(
        seedColor: _lightSeed,
        brightness: Brightness.light,
        contrastLevel: 1,
        fontFamily: fontFamily,
        platform: platform,
      );

  static ThemeData highContrastDark({
    String? fontFamily,
    TargetPlatform? platform,
  }) =>
      _theme(
        seedColor: _darkSeed,
        brightness: Brightness.dark,
        contrastLevel: 1,
        fontFamily: fontFamily,
        platform: platform,
      );

  static ThemeData _theme({
    required Color seedColor,
    required Brightness brightness,
    double contrastLevel = 0,
    String? fontFamily,
    TargetPlatform? platform,
  }) {
    final effectivePlatform = platform ?? defaultTargetPlatform;
    final families = RiverTypography.sansSerifFamilies(effectivePlatform);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );
    return ThemeData(
      colorScheme: colorScheme,
      focusColor: colorScheme.primary.withValues(alpha: 0.24),
      fontFamily: fontFamily ?? families.first,
      fontFamilyFallback:
          fontFamily == null ? families.skip(1).toList() : families,
      platform: effectivePlatform,
      useMaterial3: true,
    );
  }
}
