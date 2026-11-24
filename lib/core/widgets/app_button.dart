import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, text, danger }

/// The one button used across the app.
///
/// * Shows a spinner and blocks taps while [isLoading] is true.
/// * Expands to full width by default (mobile-first forms).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.outline;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Color spinnerColor = switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.danger => scheme.onError,
      AppButtonVariant.secondary => scheme.onSecondary,
      _ => scheme.primary,
    };

    final Widget child = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: spinnerColor,
              semanticsLabel: 'Loading',
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), AppSpacing.gapXs],
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ],
          );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      AppButtonVariant.secondary => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.secondary,
            foregroundColor: scheme.onSecondary,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        ),
      AppButtonVariant.danger => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
    };

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: isLoading ? '$label, loading' : null,
      excludeSemantics: isLoading,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
