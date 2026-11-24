import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/selfcare_content.dart';

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final Set<int> _done = {};

  @override
  Widget build(BuildContext context) {
    final a = SelfCareLibrary.byId(widget.activityId);
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(
          title: 'Activity not found',
          actionLabel: 'Back to Self-care',
          onAction: () => context.go(AppRoutes.selfCare),
        ),
      );
    }

    final interactiveRoute = switch (a.kind) {
      ActivityKind.breathing => AppRoutes.breathing,
      ActivityKind.grounding => AppRoutes.grounding,
      ActivityKind.gratitude => AppRoutes.gratitude,
      ActivityKind.guided => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(a.category.label)),
      body: PageBody(
        children: [
          AppCard(
            color: a.category.color.withValues(alpha: context.isDark ? 0.2 : 0.14),
            child: Row(
              children: [
                IconBubble(icon: a.category.icon, color: a.category.color, size: 56),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: context.text.titleLarge),
                      Text('About ${a.minutes} min', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Text(a.summary, style: context.text.bodyLarge),
          const SectionHeader(title: 'How to do it'),
          for (var i = 0; i < a.steps.length; i++)
            CheckboxListTile(
              value: _done.contains(i),
              onChanged: interactiveRoute == null
                  ? (v) => setState(() => v == true ? _done.add(i) : _done.remove(i))
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(a.steps[i], style: context.text.bodyLarge),
            ),
          if (a.tip != null) ...[
            AppSpacing.gapSm,
            InfoBanner(message: a.tip!, icon: Icons.lightbulb_outline_rounded),
          ],
          AppSpacing.gapLg,
          if (interactiveRoute != null)
            AppButton(
              label: 'Start',
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.push(interactiveRoute),
            )
          else
            AppButton(
              label: 'I did it',
              icon: Icons.check_rounded,
              onPressed: () => context.pushReplacement(
                Uri(path: AppRoutes.selfCareComplete, queryParameters: {'activity': a.id}).toString(),
              ),
            ),
          AppSpacing.gapMd,
          Text(AppConstants.notTreatmentNotice, style: context.text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
