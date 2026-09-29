import 'package:flutter/material.dart';

/// InkMind design tokens — calm stationery, not a dashboard.
abstract final class InkTokens {
  // —— Color: light ——
  static const Color workspaceLight = Color(0xFFF3EFE7);
  static const Color paperLight = Color(0xFFFFFDF9);
  static const Color surfaceLight = Color(0xFFFAF7F1);
  static const Color textPrimaryLight = Color(0xFF1C1B19);
  static const Color textSecondaryLight = Color(0xFF6A6560);
  static const Color textTertiaryLight = Color(0xFF9A948C);
  static const Color borderLight = Color(0xFFE2DDD4);
  static const Color borderStrongLight = Color(0xFFD0CAC0);
  static const Color accentLight = Color(0xFFB85A3E); // warm ink vermillion
  static const Color accentSoftLight = Color(0xFFF3E4DE);
  static const Color successLight = Color(0xFF4F6F5B);
  static const Color dangerLight = Color(0xFFA34A3A);
  static const Color chromeLight = Color(0xFFF7F4EE);

  // —— Color: dark ——
  static const Color workspaceDark = Color(0xFF17181A);
  static const Color paperDark = Color(0xFF222428);
  static const Color surfaceDark = Color(0xFF1C1E22);
  static const Color textPrimaryDark = Color(0xFFE8E4DC);
  static const Color textSecondaryDark = Color(0xFFA09A92);
  static const Color textTertiaryDark = Color(0xFF6F6A64);
  static const Color borderDark = Color(0xFF2E3136);
  static const Color borderStrongDark = Color(0xFF3C4046);
  static const Color accentDark = Color(0xFFD4785C);
  static const Color accentSoftDark = Color(0xFF3A2A24);
  static const Color successDark = Color(0xFF7FA88A);
  static const Color dangerDark = Color(0xFFC97868);
  static const Color chromeDark = Color(0xFF1A1C1F);

  // Writing ink palette (on paper)
  static const List<int> inkPalette = [
    0xFF2A2926, // graphite
    0xFF2F4A6E, // dark blue
    0xFFA34A3A, // muted red
    0xFF3F5C48, // forest
    0xFFC46B2E, // warm orange
    0xFF6B5578, // violet
    0xFFB0AAA2, // light gray
    0xFF6E4E3A, // brown
  ];

  static const List<String> inkPaletteNames = [
    'Graphite',
    'Ink blue',
    'Muted red',
    'Forest',
    'Warm orange',
    'Violet',
    'Soft gray',
    'Sepia',
  ];

  // Cover tones for notebooks
  static const List<int> coverTones = [
    0xFF3D4A45,
    0xFF4A3F38,
    0xFF3A4558,
    0xFF5A3F3A,
    0xFF3F4A3A,
    0xFF4A4558,
    0xFF5C4A38,
    0xFF384248,
  ];

  // Spacing scale
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;

  // Radii
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double rPaper = 10;
  static const double rPill = 999;

  // Motion
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration settle = Duration(milliseconds: 280);
  static const Duration deliberate = Duration(milliseconds: 350);
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;

  // Elevation (subtle)
  static List<BoxShadow> lift([double opacity = .06]) => [
        BoxShadow(
          color: Color(0xFF1C1B19).withValues(alpha: opacity),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> paperShadow([bool dark = false]) => [
        BoxShadow(
          color: Color(0xFF1C1B19).withValues(alpha: dark ? .35 : .07),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> toolShadow() => [
        BoxShadow(
          color: const Color(0xFF1C1B19).withValues(alpha: .08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Semantic colors resolved for the active brightness.
class InkColors {
  final Brightness brightness;
  const InkColors(this.brightness);

  bool get isDark => brightness == Brightness.dark;

  Color get workspace =>
      isDark ? InkTokens.workspaceDark : InkTokens.workspaceLight;
  Color get paper => isDark ? InkTokens.paperDark : InkTokens.paperLight;
  Color get surface => isDark ? InkTokens.surfaceDark : InkTokens.surfaceLight;
  Color get chrome => isDark ? InkTokens.chromeDark : InkTokens.chromeLight;
  Color get textPrimary =>
      isDark ? InkTokens.textPrimaryDark : InkTokens.textPrimaryLight;
  Color get textSecondary =>
      isDark ? InkTokens.textSecondaryDark : InkTokens.textSecondaryLight;
  Color get textTertiary =>
      isDark ? InkTokens.textTertiaryDark : InkTokens.textTertiaryLight;
  Color get border => isDark ? InkTokens.borderDark : InkTokens.borderLight;
  Color get borderStrong =>
      isDark ? InkTokens.borderStrongDark : InkTokens.borderStrongLight;
  Color get accent => isDark ? InkTokens.accentDark : InkTokens.accentLight;
  Color get accentSoft =>
      isDark ? InkTokens.accentSoftDark : InkTokens.accentSoftLight;
  Color get success => isDark ? InkTokens.successDark : InkTokens.successLight;
  Color get danger => isDark ? InkTokens.dangerDark : InkTokens.dangerLight;

  static InkColors of(BuildContext context) =>
      InkColors(Theme.of(context).brightness);
}
