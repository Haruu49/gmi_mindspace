import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/user_profile.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String? _targetFor(AppNotification n, AppRole role) {
    if (role == AppRole.counsellor) {
      if (n.appointmentId != null) return AppRoutes.counsellorAppointment(n.appointmentId!);
      return null;
    }
    if (n.appointmentId != null) return AppRoutes.bookingDetail(n.appointmentId!);
    if (n.programmeId != null) return AppRoutes.activityDetail(n.programmeId!);
    if (n.resourceId != null) return AppRoutes.learnDetail(n.resourceId!);
    return null;
  }

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    final repo = ref.read(notificationRepositoryProvider);
    if (!n.isRead) {
      try {
        await repo.markRead(n.id);
        ref.invalidate(notificationsProvider);
      } catch (_) {}
    }
    final role = ref.read(currentProfileProvider)?.role ?? AppRole.student;
    final target = _targetFor(n, role);
    // `go` because the target may live in another tab.
    if (target != null && context.mounted) context.go(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);
    final isStudent = ref.watch(currentProfileProvider)?.role == AppRole.student;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(notificationRepositoryProvider).markAllRead();
                  ref.invalidate(notificationsProvider);
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, e);
                }
              },
              child: const Text('Mark all read'),
            ),
          if (isStudent)
            IconButton(
              tooltip: 'Notification settings',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => context.push(AppRoutes.notificationSettings),
            ),
        ],
      ),
      body: AsyncValueView<List<AppNotification>>(
        value: items,
        onRetry: () => ref.invalidate(notificationsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          title: 'All caught up',
          message: 'Updates about appointments, activities and new resources appear here.',
          icon: Icons.notifications_none_rounded,
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: ListView.separated(
            padding: AppSpacing.page,
            itemCount: list.length,
            separatorBuilder: (_, _) => AppSpacing.gapXs,
            itemBuilder: (context, i) {
              final n = list[i];
              return ResponsiveCenter(
                child: AppCard(
                  onTap: () => _open(context, ref, n),
                  color: n.isRead ? null : context.colors.primaryContainer.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      IconBubble(icon: n.kind.icon, size: 40),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: context.text.titleSmall),
                            Text(n.body, style: context.text.bodyMedium),
                            Text(AppDates.relative(n.createdAt), style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove notification',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () async {
                          try {
                            await ref.read(notificationRepositoryProvider).delete(n.id);
                            ref.invalidate(notificationsProvider);
                          } catch (e) {
                            if (context.mounted) showErrorSnack(context, e);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
