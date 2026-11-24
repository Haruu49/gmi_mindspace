import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../counselling/data/counselling_repository.dart';
import '../../counselling/domain/appointment.dart';
import '../../mood_checkin/domain/mood.dart';
import 'counsellor_dashboard_screen.dart' show StatCard;

/// Counsellor view of an assigned appointment. RLS guarantees only the
/// assigned counsellor can open it.
class CounsellorAppointmentDetailScreen extends ConsumerStatefulWidget {
  const CounsellorAppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<CounsellorAppointmentDetailScreen> createState() => _State();
}

class _State extends ConsumerState<CounsellorAppointmentDetailScreen> {
  bool _busy = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  CounsellingRepository get _repo => ref.read(counsellingRepositoryProvider);

  void _refresh() {
    ref.invalidate(appointmentDetailProvider(widget.appointmentId));
    ref.invalidate(counsellorAppointmentsProvider);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (mounted) showAppSnack(context, success);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() => _run(
        () => _repo.setStatus(widget.appointmentId, AppointmentStatus.confirmed),
        'Appointment confirmed. The student has been notified.',
      );

  Future<void> _rejectOrCancel(AppointmentStatus status) async {
    final reason = await showReasonDialog(
      context,
      title: status == AppointmentStatus.rejected ? 'Reject request' : 'Cancel appointment',
      label: 'Explanation for the student',
      confirmLabel: status == AppointmentStatus.rejected ? 'Reject' : 'Cancel appointment',
    );
    if (reason == null) return;
    await _run(() => _repo.setStatus(widget.appointmentId, status, reason: reason),
        status == AppointmentStatus.rejected ? 'Request rejected.' : 'Appointment cancelled.');
  }

  Future<void> _complete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Mark as completed?',
      message: 'Use this after the session has taken place.',
      confirmLabel: 'Mark completed',
    );
    if (ok) await _run(() => _repo.setStatus(widget.appointmentId, AppointmentStatus.completed), 'Marked as completed.');
  }

  Future<void> _reschedule() async {
    final slots = await _repo.fetchMyAvailability();
    final appts = ref.read(counsellorAppointmentsProvider).value ?? const [];
    final taken = appts
        .where((a) => a.status.isLive && a.id != widget.appointmentId)
        .map((a) => a.startsAt.toUtc())
        .toSet();
    final options =
        slots.where((s) => s.isActive && s.startsAt.isAfter(DateTime.now()) && !taken.contains(s.startsAt.toUtc())).toList();
    if (!mounted) return;
    if (options.isEmpty) {
      showAppSnack(context, 'Add a free slot in Availability first.', isError: true);
      return;
    }
    final chosen = await showModalBottomSheet<AvailabilitySlot>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            children: [
              Text('Choose a new time', style: ctx.text.titleLarge),
              AppSpacing.gapSm,
              for (final s in options)
                ListTile(
                  leading: const Icon(Icons.event_available_rounded),
                  title: Text(AppDates.dayTime(s.startsAt)),
                  subtitle: s.location == null ? null : Text(s.location!),
                  onTap: () => Navigator.of(ctx).pop(s),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await _run(() => _repo.reschedule(widget.appointmentId, chosen.id), 'Rescheduled. The student has been notified.');
  }

  Future<void> _addNote() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      await _repo.addNote(widget.appointmentId, text);
      _note.clear();
      ref.invalidate(appointmentNotesProvider(widget.appointmentId));
    }, 'Note saved.');
  }

  @override
  Widget build(BuildContext context) {
    final appt = ref.watch(appointmentDetailProvider(widget.appointmentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: AsyncValueView<Appointment>(
        value: appt,
        onRetry: _refresh,
        data: (a) {
          final future = a.startsAt.isAfter(DateTime.now());
          return PageBody(
            children: [
              Row(
                children: [
                  Expanded(child: Text(a.studentName ?? 'Student', style: context.text.headlineSmall)),
                  StatusChip(label: a.status.label, color: a.status.color, icon: a.status.icon),
                ],
              ),
              AppSpacing.gapSm,
              DetailRow(icon: a.type.icon, label: 'Type', value: a.type.label),
              DetailRow(
                icon: Icons.event_rounded,
                label: 'When',
                value: '${AppDates.day(a.startsAt)}, ${AppDates.time(a.startsAt)} – ${AppDates.time(a.endsAt)}',
              ),
              if (a.studentReason != null)
                DetailRow(icon: Icons.notes_rounded, label: 'Student\'s note', value: a.studentReason!),
              if (a.statusReason != null)
                DetailRow(icon: Icons.chat_bubble_outline, label: 'Explanation given', value: a.statusReason!),
              if (a.rescheduleRequested && a.status.isLive) ...[
                AppSpacing.gapSm,
                InfoBanner(
                  title: 'Student asked to reschedule',
                  message: a.rescheduleNote ?? '',
                  icon: Icons.update_rounded,
                  color: AppColors.warning,
                ),
              ],
              AppSpacing.gapLg,
              if (a.status == AppointmentStatus.pending) ...[
                AppButton(label: 'Confirm', icon: Icons.check_rounded, isLoading: _busy, onPressed: _confirm),
                AppSpacing.gapSm,
                AppButton.outline(label: 'Reject with explanation', onPressed: _busy ? null : () => _rejectOrCancel(AppointmentStatus.rejected)),
              ],
              if (a.status.isLive && future) ...[
                AppSpacing.gapSm,
                AppButton.outline(label: 'Reschedule', icon: Icons.update_rounded, onPressed: _busy ? null : _reschedule),
              ],
              if (a.status == AppointmentStatus.confirmed) ...[
                AppSpacing.gapSm,
                if (!future)
                  AppButton(label: 'Mark completed', icon: Icons.task_alt_rounded, isLoading: _busy, onPressed: _complete),
                AppSpacing.gapSm,
                AppButton.text(
                  label: 'Cancel appointment',
                  expand: true,
                  onPressed: _busy ? null : () => _rejectOrCancel(AppointmentStatus.cancelled),
                ),
              ],
              _SharedSummary(studentId: a.studentId),
              const SectionHeader(title: 'Private session notes'),
              Text('Visible only to you. Never shown to the student or administrators.', style: context.text.bodySmall),
              AppSpacing.gapSm,
              TextField(
                controller: _note,
                maxLines: 4,
                minLines: 2,
                maxLength: 4000,
                decoration: const InputDecoration(hintText: 'Add a note'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton.text(label: 'Save note', onPressed: _busy ? null : _addNote),
              ),
              _NotesList(appointmentId: a.id),
            ],
          );
        },
      ),
    );
  }
}

class _SharedSummary extends ConsumerWidget {
  const _SharedSummary({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sharedMoodSummaryProvider(studentId));
    return summary.maybeWhen(
      data: (s) {
        if (s == null) return const SizedBox.shrink(); // no consent
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: 'Mood summary shared by the student (last ${s.periodDays} days)'),
            Text('Counts only – the student chose to share this and can stop at any time.',
                style: context.text.bodySmall),
            AppSpacing.gapSm,
            ResponsiveGrid(
              minTileWidth: 110,
              children: [
                for (final m in Mood.values)
                  StatCard(label: m.label, value: '${m.emoji} ${s.counts[m.dbValue] ?? 0}', icon: Icons.circle, color: m.color),
              ],
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(appointmentNotesProvider(appointmentId));
    return notes.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Could not load notes.', style: context.text.bodySmall),
      data: (list) => Column(
        children: [
          for (final n in list)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.note, style: context.text.bodyMedium),
                          Text(AppDates.relative(n.createdAt), style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete note',
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () async {
                        final ok = await showConfirmDialog(context,
                            title: 'Delete note?', message: 'This cannot be undone.', confirmLabel: 'Delete', destructive: true);
                        if (!ok) return;
                        try {
                          await ref.read(counsellingRepositoryProvider).deleteNote(n.id);
                          ref.invalidate(appointmentNotesProvider(appointmentId));
                        } catch (e) {
                          if (context.mounted) showErrorSnack(context, e);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
