import 'package:material_ui/material_ui.dart';

/// GMI MindSpace brand palette.
///
/// Use these tokens (or `Theme.of(context).colorScheme`) instead of raw hex
/// values inside widgets so light and dark themes stay consistent.
abstract final class AppColors {
  // Brand
  static const Color lavender = Color(0xFF9274B8); // Primary
  static const Color sage = Color(0xFFA7B99A); // Secondary
  static const Color warmWhite = Color(0xFFFAF9F6); // Background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color navy = Color(0xFF263247); // Text primary
  static const Color slate = Color(0xFF7B8290); // Text secondary

  // Feedback
  static const Color success = Color(0xFF65A887);
  static const Color warning = Color(0xFFE8B66D);
  static const Color error = Color(0xFFD97979);

  // Soft tints used for cards and illustrations
  static const Color lavenderSoft = Color(0xFFEDE6F5);
  static const Color lavenderDeep = Color(0xFF6E5296);
  static const Color sageSoft = Color(0xFFEEF2EA);
  static const Color sageDeep = Color(0xFF6F8661);
  static const Color peachSoft = Color(0xFFFBEBDD);
  static const Color skySoft = Color(0xFFE3EEF7);
  static const Color divider = Color(0xFFE8E6E1);

  // Dark theme surfaces (calm, not pure black)
  static const Color darkBackground = Color(0xFF161A23);
  static const Color darkSurface = Color(0xFF1F2430);
  static const Color darkSurfaceHigh = Color(0xFF2A3040);
  static const Color darkText = Color(0xFFECEAF2);
  static const Color darkTextSecondary = Color(0xFFA9AEBB);
  static const Color lavenderLight = Color(0xFFC3AEE0);
  static const Color sageLight = Color(0xFFC5D4B9);
}
