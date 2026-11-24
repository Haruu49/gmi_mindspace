import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/selfcare_content.dart';

class SelfCareHomeScreen extends StatefulWidget {
  const SelfCareHomeScreen({super.key});

  @override
  State<SelfCareHomeScreen> createState() => _SelfCareHomeScreenState();
}

class _SelfCareHomeScreenState extends State<SelfCareHomeScreen> {
  SelfCareCategory? _category;

  @override
  Widget build(BuildContext context) {
    final list = _category == null
        ? SelfCareLibrary.activities
        : SelfCareLibrary.inCategory(_category!);
    return Scaffold(
      appBar: AppBar(title: const Text('Self-care Corner')),
      body: PageBody(
        children: [
          Text('Small steps, kind to yourself', style: context.text.titleLarge),
          AppSpacing.gapXs,
          Text(
            'Pick something that fits how much time and energy you have.',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.gapMd,
          ResponsiveGrid(
            minTileWidth: 150,
            children: [
              FeatureCard(
                icon: Icons.air_rounded,
                title: 'Breathe',
                subtitle: 'Guided breathing',
                tint: AppColors.skySoft,
                onTap: () => context.push(AppRoutes.breathing),
              ),
              FeatureCard(
                icon: Icons.center_focus_strong_outlined,
                title: 'Ground',
                subtitle: '5-4-3-2-1 senses',
                tint: AppColors.sageSoft,
                iconColor: AppColors.sageDeep,
                onTap: () => context.push(AppRoutes.grounding),
              ),
              FeatureCard(
                icon: Icons.favorite_border_rounded,
                title: 'Gratitude',
                subtitle: 'Three good things',
                tint: AppColors.peachSoft,
                iconColor: AppColors.error,
                onTap: () => context.push(AppRoutes.gratitude),
              ),
            ],
          ),
          const SectionHeader(title: 'Explore by category'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in SelfCareCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: ChoiceChip(
                      avatar: Icon(c.icon, size: 18),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          for (final a in list) ...[
            SelfCareActivityCard(activity: a),
            AppSpacing.gapSm,
          ],
          AppSpacing.gapSm,
          const InfoBanner(message: AppConstants.notTreatmentNotice),
        ],
      ),
    );
  }
}

class SelfCareActivityCard extends StatelessWidget {
  const SelfCareActivityCard({super.key, required this.activity});

  final SelfCareActivity activity;

  @override
  Widget build(BuildContext context) {
    final c = activity.category;
    return AppCard(
      onTap: () => context.push(AppRoutes.selfCareActivity(activity.id)),
      child: Row(
        children: [
          IconBubble(icon: c.icon, color: c.color, size: 48),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title, style: context.text.titleSmall),
                AppSpacing.gapXxs,
                Text(activity.summary, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                AppSpacing.gapXs,
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    StatusChip(label: c.label, color: c.color),
                    StatusChip(label: '${activity.minutes} min', color: context.colors.primary, icon: Icons.schedule_rounded),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
