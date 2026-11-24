import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final message = state is AuthSignedOut ? state.message : null;
    final shortScreen = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter,
            vertical: AppSpacing.lg,
          ),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: BrandHeader()),
                AppSpacing.gapLg,
                CalmingIllustration(height: shortScreen ? 150 : 210),
                AppSpacing.gapLg,
                Text(
                  AppConstants.appName,
                  style: context.text.displaySmall,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXs,
                Text(
                  AppConstants.tagline,
                  style: context.text.titleMedium?.copyWith(color: context.colors.primary),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapSm,
                Text(
                  AppConstants.description,
                  style: context.text.bodyLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapLg,
                if (message != null) ...[
                  InfoBanner(message: message, icon: Icons.lock_clock_outlined),
                  AppSpacing.gapMd,
                ],
                AppButton(
                  label: 'Student Login',
                  icon: Icons.school_rounded,
                  onPressed: () => context.push(AppRoutes.studentLogin),
                ),
                AppSpacing.gapSm,
                AppButton.secondary(
                  label: 'Counsellor Login',
                  icon: Icons.volunteer_activism_rounded,
                  onPressed: () => context.push(AppRoutes.counsellorLogin),
                ),
                AppSpacing.gapSm,
                AppButton.outline(
                  label: 'Get Help Now',
                  icon: Icons.support_rounded,
                  onPressed: () => context.push(AppRoutes.help),
                ),
                AppSpacing.gapMd,
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('New student?', style: context.text.bodyMedium),
                    AppButton.text(
                      label: 'Create an account',
                      onPressed: () => context.push(AppRoutes.register),
                    ),
                  ],
                ),
                AppButton.text(
                  label: 'How we protect your privacy',
                  icon: Icons.shield_outlined,
                  onPressed: () => context.push(AppRoutes.privacy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
