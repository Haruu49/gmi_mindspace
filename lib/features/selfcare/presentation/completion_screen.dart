import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/selfcare_content.dart';

class SelfCareCompletionScreen extends StatelessWidget {
  const SelfCareCompletionScreen({super.key, this.activityId});

  final String? activityId;

  @override
  Widget build(BuildContext context) {
    final a = activityId == null ? null : SelfCareLibrary.byId(activityId!);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: PageBody(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CalmingIllustration(height: 160),
          AppSpacing.gapLg,
          Text('Well done', style: context.text.headlineMedium, textAlign: TextAlign.center),
          AppSpacing.gapXs,
          Text(
            a == null
                ? 'You took a moment for yourself.'
                : 'You completed "${a.title}". Taking time for yourself matters.',
            style: context.text.bodyLarge,
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapXl,
          AppButton(
            label: 'Check in with your mood',
            icon: Icons.mood_rounded,
            onPressed: () => context.go(AppRoutes.mood),
          ),
          AppSpacing.gapSm,
          AppButton.outline(
            label: 'Write in your journal',
            icon: Icons.menu_book_rounded,
            onPressed: () => context.go(AppRoutes.journal),
          ),
          AppSpacing.gapSm,
          AppButton.text(
            label: 'Back to Self-care',
            expand: true,
            onPressed: () => context.go(AppRoutes.selfCare),
          ),
        ],
      ),
    );
  }
}
