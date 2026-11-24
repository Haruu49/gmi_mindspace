import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Shared layout for login / registration / reset screens: back button,
/// calm header, scrollable keyboard-safe form area.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.icon = Icons.spa_rounded,
    this.accent,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.colors.primary;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.welcome),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.help),
            icon: Icon(Icons.support_rounded, color: context.colors.error),
            label: const Text('Get help'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Center(child: IconBubble(icon: icon, color: color, size: 64)),
          AppSpacing.gapMd,
          Text(title, style: context.text.headlineSmall, textAlign: TextAlign.center),
          AppSpacing.gapXs,
          Text(
            subtitle,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapLg,
          ...children,
        ],
      ),
    );
  }
}

/// Inline error box shown above form buttons.
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: InfoBanner(
          message: message!,
          icon: Icons.error_outline_rounded,
          color: context.colors.error,
        ),
      ),
    );
  }
}
