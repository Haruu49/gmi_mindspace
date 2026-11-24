import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'theme_builder.dart';

/// Light theme: warm white background, lavender primary, sage secondary.
abstract final class LightTheme {
  static ThemeData get data {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lavender,
      onPrimary: Colors.white,
      primaryContainer: AppColors.lavenderSoft,
      onPrimaryContainer: AppColors.lavenderDeep,
      secondary: AppColors.sage,
      onSecondary: AppColors.navy,
      secondaryContainer: AppColors.sageSoft,
      onSecondaryContainer: AppColors.sageDeep,
      tertiary: AppColors.warning,
      onTertiary: AppColors.navy,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFFF8E3E3),
      onErrorContainer: Color(0xFF8E3B3B),
      surface: AppColors.surface,
      onSurface: AppColors.navy,
      onSurfaceVariant: AppColors.slate,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.warmWhite,
      surfaceContainer: Color(0xFFF4F2EE),
      surfaceContainerHigh: Color(0xFFEFEDE8),
      surfaceContainerHighest: Color(0xFFE9E6E0),
      outline: Color(0xFFCFCBC4),
      outlineVariant: AppColors.divider,
      shadow: Color(0x14263247),
      inverseSurface: AppColors.navy,
      onInverseSurface: AppColors.warmWhite,
      inversePrimary: AppColors.lavenderLight,
    );
    return buildTheme(
      scheme: scheme,
      scaffoldBackground: AppColors.warmWhite,
      textPrimary: AppColors.navy,
      textSecondary: AppColors.slate,
    );
  }
}
