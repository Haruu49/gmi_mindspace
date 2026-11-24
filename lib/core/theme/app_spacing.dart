import 'package:material_ui/material_ui.dart';

/// 4-point spacing scale used for padding, margins and gaps.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter on phones.
  static const double pageGutter = 20;

  /// Content never grows wider than this on tablets / landscape.
  static const double maxContentWidth = 640;

  static const SizedBox gapXxs = SizedBox(height: xxs, width: xxs);
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);

  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: pageGutter,
    vertical: md,
  );
  static const EdgeInsets card = EdgeInsets.all(md);
}
