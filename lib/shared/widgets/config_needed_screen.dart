import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// Shown when the app was built without Supabase credentials, instead of
/// crashing. Emergency help stays reachable.
class ConfigNeededScreen extends StatelessWidget {
  const ConfigNeededScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          children: [
            AppSpacing.gapXl,
            const Center(child: BrandLogo(size: 80)),
            AppSpacing.gapLg,
            Text('Setup needed', style: context.text.headlineSmall, textAlign: TextAlign.center),
            AppSpacing.gapSm,
            Text(
              'This build has no server connection configured. Developers: run the app '
              'with --dart-define-from-file=env/dev.json (see README).',
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapLg,
            AppButton.outline(
              label: 'Get Help Now',
              icon: Icons.support_rounded,
              onPressed: () => context.push(AppRoutes.help),
            ),
          ],
        ),
      ),
    );
  }
}
