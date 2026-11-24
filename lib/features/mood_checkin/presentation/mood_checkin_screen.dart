import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mood_repository.dart';
import 'widgets/mood_selector.dart';

/// Mood tab: pick today's mood, then see history and analytics.
class MoodCheckinScreen extends ConsumerWidget {
  const MoodCheckinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayMoodProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mood Check-in')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(moodEntriesProvider.future),
        child: ListView(
          padding: AppSpacing.page,
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('How are you feeling right now?', style: context.text.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'There are no right or wrong answers. Your check-ins are private.',
                          style: context.text.bodySmall,
                        ),
                        AppSpacing.gapMd,
                        MoodSelector(
                          onSelected: (m) => context.push(
                            Uri(path: AppRoutes.moodReflect, queryParameters: {'mood': m.dbValue})
                                .toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapMd,
                  today.when(
                    data: (entry) => entry == null
                        ? const InfoBanner(
                            message: 'You have not checked in today yet. Tap a mood above to start.',
                            icon: Icons.wb_sunny_outlined,
                          )
                        : InfoBanner(
                            message: 'Today you felt ${entry.mood.label.toLowerCase()} '
                                '${entry.mood.emoji} (${AppDates.time(entry.createdAt)}). '
                                'You can check in again any time.',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.success,
                          ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => InfoBanner(
                      message: 'Could not load today\'s check-in. Pull down to retry.',
                      color: context.colors.error,
                    ),
                  ),
                  const SectionHeader(title: 'Reflect on your journey'),
                  _LinkTile(
                    icon: Icons.history_rounded,
                    title: 'Mood history',
                    subtitle: 'Look back at your check-ins',
                    onTap: () => context.push(AppRoutes.moodHistory),
                  ),
                  _LinkTile(
                    icon: Icons.insights_rounded,
                    title: 'Weekly & monthly charts',
                    subtitle: 'Spot patterns in your own entries',
                    onTap: () => context.push(AppRoutes.moodAnalytics),
                  ),
                  _LinkTile(
                    icon: Icons.share_outlined,
                    title: 'Sharing (optional)',
                    subtitle: 'Choose whether a counsellor sees a summary',
                    onTap: () => context.push(AppRoutes.moodShare),
                  ),
                  _LinkTile(
                    icon: Icons.menu_book_rounded,
                    title: 'Write in your journal',
                    subtitle: 'Put your thoughts into words',
                    onTap: () => context.go(AppRoutes.journal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            IconBubble(icon: icon),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
