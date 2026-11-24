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
import '../../mood_checkin/data/mood_repository.dart';
import '../../mood_checkin/presentation/widgets/mood_selector.dart';
import '../../notifications/data/notification_repository.dart';
import '../../wellbeing_activities/data/programme_repository.dart';
import '../../wellbeing_activities/domain/programme.dart';
import '../../wellbeing_activities/presentation/activities_screen.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(notificationsProvider)
      ..invalidate(myAppointmentsProvider)
      ..invalidate(myRegistrationsProvider);
    final _ = await ref.refresh(moodEntriesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final unread = ref.watch(unreadCountProvider);
    final today = ref.watch(todayMoodProvider);
    final appts = ref.watch(myAppointmentsProvider);
    final regs = ref.watch(myRegistrationsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: AppSpacing.page,
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- Header ----------
                    Row(
                      children: [
                        const Expanded(child: BrandHeader(logoSize: 34)),
                        IconButton(
                          key: const Key('dashboard_notifications'),
                          tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
                          onPressed: () => context.push(AppRoutes.notifications),
                          icon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text('$unread'),
                            child: const Icon(Icons.notifications_none_rounded),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Open profile',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => context.go(AppRoutes.profile),
                            child: UserAvatar(profile: profile, radius: 20),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,
                    // ---------- Welcome ----------
                    Text(
                      'Hello, ${profile?.firstName ?? 'there'}!',
                      key: const Key('dashboard_greeting'),
                      style: context.text.headlineMedium,
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      'How are you feeling today?',
                      style: context.text.titleMedium?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                    AppSpacing.gapMd,
                    // ---------- Daily mood ----------
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Daily Mood Check-in',
                                  style: context.text.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppSpacing.gapXs,
                              Text(AppDates.short(DateTime.now()), style: context.text.labelSmall),
                            ],
                          ),
                          AppSpacing.gapSm,
                          today.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
                            ),
                            error: (e, _) => Row(
                              children: [
                                Expanded(child: Text('Could not load your check-in.', style: context.text.bodySmall)),
                                TextButton(onPressed: () => ref.invalidate(moodEntriesProvider), child: const Text('Retry')),
                              ],
                            ),
                            data: (entry) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (entry != null) ...[
                                  Text(
                                    'Earlier you felt ${entry.mood.label.toLowerCase()} ${entry.mood.emoji}. '
                                    'How about now?',
                                    style: context.text.bodyMedium,
                                  ),
                                  AppSpacing.gapSm,
                                ],
                                MoodSelector(
                                  selected: entry?.mood,
                                  onSelected: (m) => context.go(
                                    Uri(path: AppRoutes.moodReflect, queryParameters: {'mood': m.dbValue}).toString(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ---------- Quick access ----------
                    const SectionHeader(title: 'Quick access'),
                    ResponsiveGrid(
                      minTileWidth: 150,
                      children: [
                        FeatureCard(
                          key: const Key('quick_journal'),
                          icon: Icons.menu_book_rounded,
                          title: 'My Journal',
                          subtitle: 'Private reflections',
                          tint: AppColors.lavenderSoft,
                          onTap: () => context.push(AppRoutes.journal),
                        ),
                        FeatureCard(
                          key: const Key('quick_selfcare'),
                          icon: Icons.spa_rounded,
                          title: 'Self-care',
                          subtitle: 'Breathe, ground, relax',
                          tint: AppColors.sageSoft,
                          iconColor: AppColors.sageDeep,
                          onTap: () => context.go(AppRoutes.selfCare),
                        ),
                        FeatureCard(
                          key: const Key('quick_counselling'),
                          icon: Icons.event_available_rounded,
                          title: 'Counselling',
                          subtitle: 'Book a session',
                          tint: AppColors.skySoft,
                          iconColor: const Color(0xFF4F7FA8),
                          onTap: () => context.go(AppRoutes.booking),
                        ),
                        FeatureCard(
                          key: const Key('quick_learn'),
                          icon: Icons.auto_stories_rounded,
                          title: 'Learning Hub',
                          subtitle: 'Articles & videos',
                          tint: AppColors.peachSoft,
                          iconColor: const Color(0xFFC07A45),
                          onTap: () => context.push(AppRoutes.learn),
                        ),
                      ],
                    ),
                    AppSpacing.gapSm,
                    AppCard(
                      onTap: () => context.push(AppRoutes.activities),
                      child: Row(
                        children: [
                          const IconBubble(icon: Icons.celebration_outlined, color: AppColors.lavenderDeep),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Well-being Activities', style: context.text.titleSmall),
                                Text('Workshops, webinars and challenges', style: context.text.bodySmall),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
                        ],
                      ),
                    ),
                    // ---------- Next appointment ----------
                    ...appts.maybeWhen(
                      data: (list) {
                        final upcoming = list.where((a) => a.isUpcoming).toList()
                          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                        if (upcoming.isEmpty) return const <Widget>[];
                        return [
                          SectionHeader(
                            title: 'Your next appointment',
                            actionLabel: 'All',
                            onAction: () => context.go(AppRoutes.booking),
                          ),
                          AppointmentCard(
                            appointment: upcoming.first,
                            onTap: () => context.go(AppRoutes.bookingDetail(upcoming.first.id)),
                          ),
                        ];
                      },
                      orElse: () => const <Widget>[],
                    ),
                    // ---------- Next activity ----------
                    ...regs.maybeWhen(
                      data: (list) {
                        final next = list
                            .where((r) =>
                                r.status == RegistrationStatus.registered &&
                                r.programme != null &&
                                !r.programme!.hasEnded)
                            .toList()
                          ..sort((a, b) => a.programme!.startsAt.compareTo(b.programme!.startsAt));
                        if (next.isEmpty) return const <Widget>[];
                        return [
                          const SectionHeader(title: 'Coming up for you'),
                          ProgrammeCard(programme: next.first.programme!, registration: next.first.status),
                        ];
                      },
                      orElse: () => const <Widget>[],
                    ),
                    // ---------- Get help ----------
                    AppSpacing.gapLg,
                    AppCard(
                      key: const Key('dashboard_get_help'),
                      color: context.colors.errorContainer,
                      onTap: () => context.push(AppRoutes.help),
                      child: Row(
                        children: [
                          Icon(Icons.support_rounded, color: context.colors.error, size: 32),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Get Help Now',
                                    style: context.text.titleSmall?.copyWith(color: context.colors.onErrorContainer)),
                                Text(
                                  'Emergency contacts and support lines',
                                  style: context.text.bodySmall?.copyWith(color: context.colors.onErrorContainer),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: context.colors.onErrorContainer),
                        ],
                      ),
                    ),
                    AppSpacing.gapLg,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
