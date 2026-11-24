import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Width breakpoints (logical pixels).
abstract final class Breakpoints {
  static const double compact = 360; // small Android phones
  static const double medium = 600; // large phones landscape / small tablets
  static const double expanded = 900; // tablets

  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < compact;
  static bool isTablet(BuildContext c) => MediaQuery.sizeOf(c).width >= medium;

  /// Number of grid columns for quick-access tiles.
  static int gridColumns(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= expanded) return 4;
    if (w >= medium) return 3;
    return 2;
  }
}

/// Centres content and caps its width so layouts stay readable on tablets.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Scrollable page body: safe area, gutter, max width and keyboard-aware
/// bottom padding. Use for forms and detail pages.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.padding = AppSpacing.page,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding.copyWith(bottom: padding.bottom + AppSpacing.xl),
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Simple responsive grid that sizes children by available width.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
    this.minTileWidth = 150,
  });

  final List<Widget> children;
  final double spacing;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / minTileWidth).floor().clamp(1, 4);
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in children) SizedBox(width: tileWidth, child: c),
          ],
        );
      },
    );
  }
}
