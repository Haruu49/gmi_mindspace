import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/services/local_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/counselling_repository.dart';
import '../domain/appointment.dart';

/// Student view of one appointment.
class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(appointmentDetailProvider(widget.appointmentId));
    ref.invalidate(myAppointmentsProvider);
  }

  Future<void> _cancel() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cancel this appointment?',
      message: 'The time will be released for other students.',
      confirmLabel: 'Cancel appointment',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(counsellingRepositoryProvider).cancelMyAppointment(widget.appointmentId);
      await LocalNotificationService.instance.cancelAppointmentReminder(widget.appointmentId);
      _refresh();
      if (mounted) showAppSnack(context, 'Appointment cancelled.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reschedule() async {
    final note = await showReasonDialog(
      context,
      title: 'Request a new time',
      label: 'Which days or times suit you better?',
      confirmLabel: 'Send request',
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(counsellingRepositoryProvider).requestReschedule(widget.appointmentId, note);
      _refresh();
      if (mounted) showAppSnack(context, 'Reschedule request sent to your counsellor.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = ref.watch(appointmentDetailProvider(widget.appointmentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: AsyncValueView<Appointment>(
        value: appt,
        onRetry: _refresh,
        data: (a) => PageBody(
          children: [
            AppCard(
              color: a.status.color.withValues(alpha: context.isDark ? 0.2 : 0.12),
              child: Row(
                children: [
                  Icon(a.status.icon, color: a.status.color, size: 36),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.status.label, style: context.text.titleLarge),
                        Text(
                          switch (a.status) {
                            AppointmentStatus.pending => 'Waiting for the counsellor to confirm.',
                            AppointmentStatus.confirmed => 'See you then. A reminder will be sent before.',
                            AppointmentStatus.rejected => 'This request could not go ahead.',
                            AppointmentStatus.cancelled => 'This appointment was cancelled.',
                            AppointmentStatus.completed => 'Thank you for coming.',
                          },
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapMd,
            DetailRow(icon: a.type.icon, label: 'Type', value: a.type.label),
            DetailRow(icon: Icons.event_rounded, label: 'Date', value: AppDates.day(a.startsAt)),
            DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: '${AppDates.time(a.startsAt)} – ${AppDates.time(a.endsAt)}',
            ),
            DetailRow(icon: Icons.person_outline_rounded, label: 'Counsellor', value: a.counsellorName ?? 'Counsellor'),
            if (a.studentReason != null)
              DetailRow(icon: Icons.notes_rounded, label: 'Your note (private)', value: a.studentReason!),
            if (a.statusReason != null) ...[
              AppSpacing.gapSm,
              InfoBanner(
                title: 'Message from the Counselling Unit',
                message: a.statusReason!,
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ],
            if (a.rescheduleRequested && a.status.isLive) ...[
              AppSpacing.gapSm,
              InfoBanner(
                title: 'Reschedule requested',
                message: a.rescheduleNote ?? 'Your counsellor will suggest a new time.',
                icon: Icons.update_rounded,
                color: AppColors.warning,
              ),
            ],
            if (a.canStudentChange) ...[
              AppSpacing.gapLg,
              AppButton.outline(
                label: 'Request a different time',
                icon: Icons.update_rounded,
                onPressed: _busy || a.rescheduleRequested ? null : _reschedule,
              ),
              AppSpacing.gapSm,
              AppButton.danger(
                label: 'Cancel appointment',
                icon: Icons.event_busy_rounded,
                isLoading: _busy,
                onPressed: _cancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
