import 'package:flutter/material.dart';
import 'tokens.dart';

// Backward-compatible aliases used across the codebase during redesign.
const forest = InkTokens.accentLight;
const ochre = Color(0xffc4785c);
const inkNight = InkTokens.workspaceDark;
const inkAqua = InkTokens.accentLight;
const paper = InkTokens.paperLight;
const inkColors = InkTokens.inkPalette;

ThemeData inkTheme(bool dark) {
  final colors = InkColors(dark ? Brightness.dark : Brightness.light);
  final scheme = ColorScheme(
    brightness: colors.brightness,
    primary: colors.accent,
    onPrimary: Colors.white,
    secondary: colors.success,
    onSecondary: Colors.white,
    error: colors.danger,
    onError: Colors.white,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.borderStrong,
    outlineVariant: colors.border,
    surfaceContainerLowest: colors.paper,
    surfaceContainerLow: colors.chrome,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.chrome,
    surfaceContainerHighest: colors.border,
  );

  final base = Typography.material2021(
    platform: TargetPlatform.iOS,
  ).black.apply(
    fontFamily: 'Segoe UI',
    bodyColor: colors.textPrimary,
    displayColor: colors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.workspace,
    fontFamily: 'Segoe UI',
    visualDensity: VisualDensity.standard,
    textTheme: base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: 'Lora',
        fontSize: 40,
        height: 1.15,
        letterSpacing: -.6,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: 'Lora',
        fontSize: 32,
        height: 1.2,
        letterSpacing: -.4,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: 'Lora',
        fontSize: 24,
        height: 1.25,
        letterSpacing: -.3,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
        color: colors.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.55,
        color: colors.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.5,
        color: colors.textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.45,
        color: colors.textSecondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: .3,
        color: colors.textTertiary,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.workspace,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 44),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkTokens.r12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        minimumSize: const Size(48, 44),
        side: BorderSide(color: colors.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkTokens.r12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.chrome,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InkTokens.r12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InkTokens.r12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(InkTokens.r12),
        borderSide: BorderSide(color: colors.accent, width: 1.2),
      ),
      hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InkTokens.r16),
        side: BorderSide(color: colors.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(InkTokens.r20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.textPrimary,
      contentTextStyle: TextStyle(color: colors.paper, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InkTokens.r12),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return Colors.white;
        return colors.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return colors.accent;
        return colors.border;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.border,
      thumbColor: colors.accent,
      overlayColor: colors.accent.withValues(alpha: .12),
      trackHeight: 2.5,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InkTokens.r12),
        side: BorderSide(color: colors.border),
      ),
      textStyle: TextStyle(fontSize: 13, color: colors.textPrimary),
    ),
    iconTheme: IconThemeData(color: colors.textPrimary, size: 20),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
  );
}

TextStyle editorial(BuildContext context, [double size = 32]) => TextStyle(
      fontFamily: 'Lora',
      fontSize: size,
      height: 1.2,
      color: InkColors.of(context).textPrimary,
      letterSpacing: -.4,
      fontWeight: FontWeight.w500,
    );

TextStyle wordmark(BuildContext context, [double size = 22]) => TextStyle(
      fontFamily: 'Lora',
      fontSize: size,
      height: 1,
      letterSpacing: -.6,
      fontWeight: FontWeight.w500,
      color: InkColors.of(context).textPrimary,
    );

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: .6,
          color: InkColors.of(context).textTertiary,
        ),
      );
}
