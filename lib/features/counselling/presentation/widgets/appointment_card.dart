import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/appointment.dart';

/// List card for an appointment. Shows only non-sensitive fields.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.showStudent = false,
  });

  final Appointment appointment;
  final VoidCallback onTap;
  final bool showStudent;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final who = showStudent ? (a.studentName ?? 'Student') : (a.counsellorName ?? 'Counsellor');
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: a.status.color.withValues(alpha: 0.16),
              borderRadius: AppRadius.mdAll,
            ),
            child: Column(
              children: [
                Text('${a.startsAt.toLocal().day}', style: context.text.titleLarge),
                Text(AppDates.short(a.startsAt).split(' ').last, style: context.text.labelSmall),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.type.label, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${AppDates.time(a.startsAt)} · $who', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                AppSpacing.gapXxs,
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    StatusChip(label: a.status.label, color: a.status.color, icon: a.status.icon),
                    if (a.rescheduleRequested && a.status.isLive)
                      const StatusChip(label: 'Reschedule requested', color: AppColors.warning, icon: Icons.update_rounded),
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
