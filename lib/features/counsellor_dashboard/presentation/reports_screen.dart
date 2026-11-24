import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/reports_repository.dart';
import 'counsellor_dashboard_screen.dart' show StatCard;

/// Feedback & Reports: aggregated engagement only. No diagnostic, predictive
/// or individual-level mental health data is shown.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(counsellorStatsProvider);
    final participation = ref.watch(participationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Reports')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(participationProvider);
          final _ = await ref.refresh(counsellorStatsProvider.future);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            ResponsiveCenter(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoBanner(
                    message: 'These figures describe engagement with MindSpace services. They do not '
                        'assess, diagnose or predict anyone\'s mental health. Small groups (fewer than 5 '
                        'students) are hidden to protect privacy.',
                  ),
                  const SectionHeader(title: 'Engagement'),
                  stats.when(
                    loading: () => const SizedBox(height: 160, child: LoadingView()),
                    error: (e, _) => SizedBox(height: 260, child: ErrorView(error: e, onRetry: () => ref.invalidate(counsellorStatsProvider))),
                    data: (s) => ResponsiveGrid(
                      minTileWidth: 150,
                      children: [
                        StatCard(label: 'Your completed sessions', value: '${s.completed}', icon: Icons.task_alt_rounded, color: AppColors.lavender),
                        StatCard(label: 'Programme registrations', value: '${s.registrations}', icon: Icons.how_to_reg_rounded, color: AppColors.sageDeep),
                        StatCard(
                          label: 'Attendance rate',
                          value: s.attendanceRate == null ? '–' : '${(s.attendanceRate! * 100).round()}%',
                          icon: Icons.groups_outlined,
                          color: AppColors.success,
                        ),
                        StatCard(
                          label: 'Average feedback',
                          value: s.averageRating == null ? '–' : '${s.averageRating!.toStringAsFixed(1)} / 5',
                          icon: Icons.star_outline_rounded,
                          color: AppColors.warning,
                        ),
                        StatCard(label: 'Feedback received', value: '${s.feedbackCount}', icon: Icons.rate_review_outlined, color: context.colors.primary),
                        StatCard(label: 'Published resources', value: '${s.publishedResources}', icon: Icons.auto_stories_outlined, color: const Color(0xFF4F7FA8)),
                        StatCard(label: 'Resource bookmarks', value: '${s.bookmarks}', icon: Icons.bookmark_border_rounded, color: AppColors.lavenderDeep),
                        StatCard(
                          label: 'Students using check-ins (30 days)',
                          value: s.checkinUsers30d == null ? 'Hidden (<5)' : '${s.checkinUsers30d}',
                          icon: Icons.mood_rounded,
                          color: AppColors.sage,
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader(title: 'Programme participation'),
                  participation.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => SizedBox(height: 260, child: ErrorView(error: e, onRetry: () => ref.invalidate(participationProvider))),
                    data: (list) => list.isEmpty
                        ? Text('No programmes yet.', style: context.text.bodyMedium)
                        : Column(
                            children: [
                              for (final p in list)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: AppCard(
                                    onTap: () => context.go(AppRoutes.counsellorProgramme(p.programmeId)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.title, style: context.text.titleSmall),
                                        Text('${AppDates.day(p.startsAt)} · ${p.status}', style: context.text.bodySmall),
                                        AppSpacing.gapSm,
                                        _Bar(
                                          label: 'Registered',
                                          value: p.registered + p.attended + p.absent,
                                          max: p.capacity ?? (p.registered + p.attended + p.absent).clamp(1, 1 << 30),
                                          color: context.colors.primary,
                                        ),
                                        _Bar(
                                          label: 'Attended',
                                          value: p.attended,
                                          max: (p.registered + p.attended + p.absent).clamp(1, 1 << 30),
                                          color: AppColors.success,
                                        ),
                                        AppSpacing.gapXs,
                                        Text(
                                          '${p.cancelled} cancelled · ${p.absent} absent'
                                          '${p.avgRating == null ? '' : ' · rating ${p.avgRating!.toStringAsFixed(1)}'}',
                                          style: context.text.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.max, required this.color});

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value of $max',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 84, child: Text(label, style: context.text.labelSmall)),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : (value / max).clamp(0, 1),
                  minHeight: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ),
            SizedBox(width: 44, child: Text('$value', style: context.text.labelMedium, textAlign: TextAlign.end)),
          ],
        ),
      ),
    );
  }
}
