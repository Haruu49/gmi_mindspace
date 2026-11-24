import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'theme_builder.dart';

/// Dark theme: soft navy surfaces with lighter lavender/sage accents so
/// contrast stays comfortable at night.
abstract final class DarkTheme {
  static ThemeData get data {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.lavenderLight,
      onPrimary: Color(0xFF2E1F45),
      primaryContainer: Color(0xFF4A3A66),
      onPrimaryContainer: Color(0xFFEDE6F5),
      secondary: AppColors.sageLight,
      onSecondary: Color(0xFF1F2A18),
      secondaryContainer: Color(0xFF3B4834),
      onSecondaryContainer: Color(0xFFE2EBDA),
      tertiary: AppColors.warning,
      onTertiary: AppColors.navy,
      error: Color(0xFFEBA0A0),
      onError: Color(0xFF4A1414),
      errorContainer: Color(0xFF5C2A2A),
      onErrorContainer: Color(0xFFF8E3E3),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: Color(0xFF1B202A),
      surfaceContainer: AppColors.darkSurfaceHigh,
      surfaceContainerHigh: Color(0xFF323849),
      surfaceContainerHighest: Color(0xFF3A4152),
      outline: Color(0xFF555C6C),
      outlineVariant: Color(0xFF363C4A),
      shadow: Color(0x66000000),
      inverseSurface: AppColors.darkText,
      onInverseSurface: AppColors.darkBackground,
      inversePrimary: AppColors.lavender,
    );
    return buildTheme(
      scheme: scheme,
      scaffoldBackground: AppColors.darkBackground,
      textPrimary: AppColors.darkText,
      textSecondary: AppColors.darkTextSecondary,
    );
  }
}
