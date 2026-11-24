import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../../counselling/data/counselling_repository.dart';
import '../../counselling/presentation/widgets/appointment_card.dart';
import '../../notifications/data/notification_repository.dart';
import '../data/reports_repository.dart';

class CounsellorDashboardScreen extends ConsumerWidget {
  const CounsellorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final stats = ref.watch(counsellorStatsProvider);
    final appts = ref.watch(counsellorAppointmentsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BrandHeader(logoSize: 30),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.counsellorNotifications),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.counsellorProfile),
              child: Semantics(label: 'Profile', button: true, child: UserAvatar(profile: profile, radius: 18)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(counsellorAppointmentsProvider);
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
                  Text('${AppDates.greeting()}, ${profile?.firstName ?? ''}', style: context.text.headlineSmall),
                  AppSpacing.gapXs,
                  const InfoBanner(
                    icon: Icons.lock_outline_rounded,
                    message: 'Student journals and private mood notes are never available here. '
                        'Figures below are aggregated engagement counts only.',
                  ),
                  const SectionHeader(title: 'Overview'),
                  stats.when(
                    loading: () => const SizedBox(height: 160, child: LoadingView()),
                    error: (e, _) => SizedBox(
                      height: 280,
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(counsellorStatsProvider)),
                    ),
                    data: (s) => ResponsiveGrid(
                      minTileWidth: 150,
                      children: [
                        StatCard(
                          label: 'Pending requests',
                          value: '${s.pending}',
                          icon: Icons.hourglass_top_rounded,
                          color: AppColors.warning,
                          onTap: () => context.go(AppRoutes.counsellorAppointments),
                        ),
                        StatCard(label: 'Confirmed', value: '${s.confirmed}', icon: Icons.check_circle_outline, color: AppColors.success),
                        StatCard(label: 'Next 7 days', value: '${s.upcoming7d}', icon: Icons.date_range_rounded, color: context.colors.primary),
                        StatCard(label: 'Completed', value: '${s.completed}', icon: Icons.task_alt_rounded, color: AppColors.lavender),
                        StatCard(
                          label: 'Active programmes',
                          value: '${s.activeProgrammes}',
                          icon: Icons.celebration_outlined,
                          color: AppColors.sageDeep,
                          onTap: () => context.go(AppRoutes.counsellorProgrammes),
                        ),
                        StatCard(
                          label: 'Participation',
                          value: s.attendanceRate == null
                              ? '${s.registrations} joined'
                              : '${(s.attendanceRate! * 100).round()}% attended',
                          icon: Icons.groups_outlined,
                          color: const Color(0xFF4F7FA8),
                          onTap: () => context.push(AppRoutes.counsellorReports),
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader(title: 'Manage'),
                  ResponsiveGrid(
                    minTileWidth: 150,
                    children: [
                      FeatureCard(
                        icon: Icons.event_note_rounded,
                        title: 'Appointments',
                        subtitle: 'Requests & schedule',
                        onTap: () => context.go(AppRoutes.counsellorAppointments),
                      ),
                      FeatureCard(
                        icon: Icons.schedule_rounded,
                        title: 'Availability',
                        subtitle: 'Open your slots',
                        tint: AppColors.sageSoft,
                        iconColor: AppColors.sageDeep,
                        onTap: () => context.push(AppRoutes.counsellorAvailability),
                      ),
                      FeatureCard(
                        icon: Icons.celebration_outlined,
                        title: 'Programmes',
                        subtitle: 'Create & publish',
                        tint: AppColors.peachSoft,
                        iconColor: const Color(0xFFC07A45),
                        onTap: () => context.go(AppRoutes.counsellorProgrammes),
                      ),
                      FeatureCard(
                        icon: Icons.auto_stories_outlined,
                        title: 'Learning Hub',
                        subtitle: 'Manage content',
                        tint: AppColors.skySoft,
                        iconColor: const Color(0xFF4F7FA8),
                        onTap: () => context.go(AppRoutes.counsellorContent),
                      ),
                      FeatureCard(
                        icon: Icons.insights_rounded,
                        title: 'Feedback & Reports',
                        subtitle: 'Engagement overview',
                        onTap: () => context.push(AppRoutes.counsellorReports),
                      ),
                    ],
                  ),
                  ...appts.maybeWhen(
                    data: (list) {
                      final upcoming = list.where((a) => a.isUpcoming).take(5).toList();
                      return [
                        SectionHeader(
                          title: 'Upcoming appointments',
                          actionLabel: 'All',
                          onAction: () => context.go(AppRoutes.counsellorAppointments),
                        ),
                        if (upcoming.isEmpty)
                          Text('No upcoming appointments.', style: context.text.bodyMedium)
                        else
                          for (final a in upcoming) ...[
                            AppointmentCard(
                              appointment: a,
                              showStudent: true,
                              onTap: () => context.go(AppRoutes.counsellorAppointment(a.id)),
                            ),
                            AppSpacing.gapSm,
                          ],
                      ];
                    },
                    orElse: () => const <Widget>[],
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

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: icon, color: color, size: 38),
          AppSpacing.gapSm,
          Text(value, style: context.text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}
