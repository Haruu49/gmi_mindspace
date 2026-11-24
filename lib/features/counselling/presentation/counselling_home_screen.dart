import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/counselling_repository.dart';
import '../domain/appointment.dart';
import 'widgets/appointment_card.dart';

/// Booking tab: counselling information + the student's appointments.
class CounsellingHomeScreen extends ConsumerWidget {
  const CounsellingHomeScreen({super.key});

  /// Keep on-device reminders in step with appointment statuses.
  void _syncReminders(List<Appointment> list) {
    final local = LocalNotificationService.instance;
    for (final a in list) {
      if (a.status == AppointmentStatus.confirmed && a.startsAt.isAfter(DateTime.now())) {
        local.scheduleAppointmentReminder(appointmentId: a.id, startsAt: a.startsAt);
      } else {
        local.cancelAppointmentReminder(a.id);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(myAppointmentsProvider, (_, next) => next.whenData(_syncReminders));
    final appts = ref.watch(myAppointmentsProvider);
    final info = ref.watch(counsellingInfoProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Counselling')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('booking_new'),
        onPressed: () => context.push(AppRoutes.bookingNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request appointment'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(counsellingInfoProvider);
          final _ = await ref.refresh(myAppointmentsProvider.future);
        },
        child: ListView(
          padding: AppSpacing.page.copyWith(bottom: 96),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    gradient: LinearGradient(
                      colors: [context.colors.primaryContainer, context.colors.secondaryContainer],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GMI Counselling Unit', style: context.text.titleLarge),
                        AppSpacing.gapXs,
                        Text(
                          'Talking to a counsellor is free, confidential and open to every GMI student.',
                          style: context.text.bodyMedium,
                        ),
                        AppSpacing.gapSm,
                        DetailRow(
                          icon: Icons.schedule_rounded,
                          label: 'Hours',
                          value: info['counselling_hours'] ?? 'Office hours',
                        ),
                        DetailRow(
                          icon: Icons.place_outlined,
                          label: 'Where',
                          value: info['counselling_location'] ?? 'Counselling Unit',
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapSm,
                  const InfoBanner(
                    icon: Icons.lock_outline_rounded,
                    message: 'Only you and your assigned counsellor can see your appointments.',
                  ),
                  appts.when(
                    loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
                    error: (e, _) => SizedBox(
                      height: 320,
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(myAppointmentsProvider)),
                    ),
                    data: (list) {
                      final upcoming = list.where((a) => a.isUpcoming).toList()
                        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                      final past = list.where((a) => !a.isUpcoming).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(title: 'Upcoming'),
                          if (upcoming.isEmpty)
                            AppCard(
                              child: Column(
                                children: [
                                  Text('No upcoming appointments', style: context.text.titleSmall),
                                  AppSpacing.gapXs,
                                  Text(
                                    'Whenever you are ready, request a time that suits you.',
                                    style: context.text.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            for (final a in upcoming) ...[
                              AppointmentCard(
                                appointment: a,
                                onTap: () => context.push(AppRoutes.bookingDetail(a.id)),
                              ),
                              AppSpacing.gapSm,
                            ],
                          if (past.isNotEmpty) ...[
                            const SectionHeader(title: 'History'),
                            for (final a in past) ...[
                              AppointmentCard(
                                appointment: a,
                                onTap: () => context.push(AppRoutes.bookingDetail(a.id)),
                              ),
                              AppSpacing.gapSm,
                            ],
                          ],
                        ],
                      );
                    },
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
