import 'package:material_ui/material_ui.dart';

import 'dark_theme.dart';
import 'light_theme.dart';

export 'app_colors.dart';
export 'app_radius.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// Single entry point for the GMI MindSpace design system.
///
/// `import 'package:gmi_mindspace/core/theme/app_theme.dart';` gives access to
/// [AppTheme], [AppColors], [AppSpacing], [AppRadius] and [AppTypography].
abstract final class AppTheme {
  static ThemeData get light => LightTheme.data;
  static ThemeData get dark => DarkTheme.data;
}

/// Convenience accessors so widgets stay short and readable.
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
