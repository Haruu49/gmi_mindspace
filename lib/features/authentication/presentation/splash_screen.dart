import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';

/// Shown while the saved session and role are being restored. The router
/// moves on automatically once [authControllerProvider] settles.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: state is AuthProfileError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: ErrorView(
                          error: state.error,
                          onRetry: () => ref.read(authControllerProvider.notifier).retry(),
                        ),
                      ),
                      AppButton.text(
                        label: 'Sign out',
                        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(size: 96),
                      AppSpacing.gapLg,
                      Text(AppConstants.appName, style: context.text.headlineMedium),
                      AppSpacing.gapXs,
                      Text(
                        AppConstants.tagline,
                        style: context.text.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapXl,
                      const CircularProgressIndicator(semanticsLabel: 'Loading'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
