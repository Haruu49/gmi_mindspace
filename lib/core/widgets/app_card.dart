import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Rounded card with optional tap, tint colour or gradient.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.card,
    this.color,
    this.gradient,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? scheme.surface) : null,
      gradient: gradient,
      borderRadius: AppRadius.lgAll,
      border: Border.all(
        color: borderColor ??
            (color == null && gradient == null
                ? scheme.outlineVariant
                : Colors.transparent),
      ),
      boxShadow: context.isDark
          ? null
          : [
              BoxShadow(
                color: scheme.shadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
    );

    final content = Padding(padding: padding, child: child);

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      container: true,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: onTap == null
              ? content
              : InkWell(
                  borderRadius: AppRadius.lgAll,
                  onTap: onTap,
                  child: content,
                ),
        ),
      ),
    );
  }
}

/// Square-ish quick-access tile with an icon bubble, title and subtitle.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tint,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? tint;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final bg = context.isDark
        ? scheme.surfaceContainer
        : (tint ?? scheme.primaryContainer);
    return AppCard(
      onTap: onTap,
      color: bg,
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: context.isDark ? 0.15 : 0.85),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, color: iconColor ?? scheme.primary, size: 26),
          ),
          AppSpacing.gapSm,
          Text(title, style: context.text.titleSmall, maxLines: 2),
          if (subtitle != null) ...[
            AppSpacing.gapXxs,
            Text(
              subtitle!,
              style: context.text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
