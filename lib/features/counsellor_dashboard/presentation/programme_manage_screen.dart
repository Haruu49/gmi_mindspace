import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../wellbeing_activities/data/programme_repository.dart';
import '../../wellbeing_activities/domain/programme.dart';

/// Counsellor view: publish / unpublish, registrations, attendance, feedback.
class ProgrammeManageScreen extends ConsumerStatefulWidget {
  const ProgrammeManageScreen({super.key, required this.programmeId});

  final String programmeId;

  @override
  ConsumerState<ProgrammeManageScreen> createState() => _State();
}

class _State extends ConsumerState<ProgrammeManageScreen> {
  bool _busy = false;

  ProgrammeRepository get _repo => ref.read(programmeRepositoryProvider);

  void _refresh() {
    ref
      ..invalidate(programmeDetailProvider(widget.programmeId))
      ..invalidate(allProgrammesProvider)
      ..invalidate(programmeRegistrationsProvider(widget.programmeId));
  }

  Future<void> _setStatus(ProgrammeStatus status, {String? confirm}) async {
    if (confirm != null) {
      final ok = await showConfirmDialog(context,
          title: 'Are you sure?', message: confirm, confirmLabel: 'Continue', destructive: status == ProgrammeStatus.cancelled);
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await _repo.setStatus(widget.programmeId, status);
      _refresh();
      if (mounted) showAppSnack(context, 'Programme ${status.label.toLowerCase()}.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(context,
        title: 'Delete draft?', message: 'This draft will be permanently removed.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await _repo.deleteDraft(widget.programmeId);
      ref.invalidate(allProgrammesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programme = ref.watch(programmeDetailProvider(widget.programmeId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage programme'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.counsellorProgrammeEdit(widget.programmeId)),
          ),
        ],
      ),
      body: AsyncValueView<Programme>(
        value: programme,
        onRetry: _refresh,
        data: (p) => PageBody(
          children: [
            Row(
              children: [
                Expanded(child: Text(p.title, style: context.text.headlineSmall)),
                StatusChip(label: p.status.label, color: p.status.color),
              ],
            ),
            AppSpacing.gapSm,
            DetailRow(icon: Icons.event_rounded, label: 'When', value: '${AppDates.dayTime(p.startsAt)} – ${AppDates.time(p.endsAt)}'),
            DetailRow(icon: p.mode.icon, label: 'Mode', value: p.mode.label),
            if (p.location != null) DetailRow(icon: Icons.place_outlined, label: 'Venue', value: p.location!),
            if (p.capacity != null) DetailRow(icon: Icons.groups_outlined, label: 'Capacity', value: '${p.capacity}'),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (p.status == ProgrammeStatus.draft) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _setStatus(ProgrammeStatus.published),
                    icon: const Icon(Icons.publish_rounded),
                    label: const Text('Publish'),
                  ),
                  OutlinedButton.icon(onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline), label: const Text('Delete draft')),
                ],
                if (p.status == ProgrammeStatus.published) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _setStatus(ProgrammeStatus.draft, confirm: 'Students will no longer see this programme.'),
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Unpublish'),
                  ),
                  if (p.hasEnded)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _setStatus(ProgrammeStatus.completed),
                      icon: const Icon(Icons.task_alt_rounded),
                      label: const Text('Mark completed'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _setStatus(ProgrammeStatus.cancelled, confirm: 'Registered students will see that it is cancelled.'),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel programme'),
                  ),
                ],
              ],
            ),
            _Registrations(programme: p),
            _Feedback(programmeId: p.id),
          ],
        ),
      ),
    );
  }
}

class _Registrations extends ConsumerWidget {
  const _Registrations({required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regs = ref.watch(programmeRegistrationsProvider(programme.id));
    return regs.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LinearProgressIndicator()),
      error: (e, _) => SizedBox(
        height: 240,
        child: ErrorView(error: e, onRetry: () => ref.invalidate(programmeRegistrationsProvider(programme.id))),
      ),
      data: (list) {
        final active = list.where((r) => r.status != RegistrationStatus.cancelled).toList();
        final attended = list.where((r) => r.status == RegistrationStatus.attended).length;
        final absent = list.where((r) => r.status == RegistrationStatus.absent).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: 'Registrations (${active.length}${programme.capacity == null ? '' : '/${programme.capacity}'})'),
            if (programme.hasStarted)
              Text('Attendance: $attended attended · $absent absent', style: context.text.bodyMedium)
            else
              Text('Attendance can be recorded once the programme starts.', style: context.text.bodySmall),
            AppSpacing.gapSm,
            if (active.isEmpty)
              Text('No registrations yet.', style: context.text.bodyMedium)
            else
              for (final r in active)
                Card(
                  child: ListTile(
                    title: Text(r.studentName ?? 'Student'),
                    subtitle: Text([if (r.studentNumber != null) r.studentNumber!, r.status.label].join(' · ')),
                    trailing: programme.hasStarted
                        ? SegmentedButton<RegistrationStatus>(
                            showSelectedIcon: false,
                            emptySelectionAllowed: true,
                            segments: const [
                              ButtonSegment(value: RegistrationStatus.attended, icon: Icon(Icons.check_rounded), tooltip: 'Attended'),
                              ButtonSegment(value: RegistrationStatus.absent, icon: Icon(Icons.close_rounded), tooltip: 'Absent'),
                            ],
                            selected: {
                              if (r.status == RegistrationStatus.attended || r.status == RegistrationStatus.absent) r.status,
                            },
                            onSelectionChanged: (s) async {
                              if (s.isEmpty) return;
                              try {
                                await ref.read(programmeRepositoryProvider).markAttendance(r.id, s.first);
                                ref.invalidate(programmeRegistrationsProvider(programme.id));
                              } catch (e) {
                                if (context.mounted) showErrorSnack(context, e);
                              }
                            },
                          )
                        : null,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _Feedback extends ConsumerWidget {
  const _Feedback({required this.programmeId});

  final String programmeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fb = ref.watch(programmeFeedbackProvider(programmeId));
    return fb.maybeWhen(
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Feedback (${list.length})'),
          if (list.isEmpty)
            Text('No feedback yet.', style: context.text.bodyMedium)
          else ...[
            Text(
              'Average rating: ${(list.map((f) => f.rating).reduce((a, b) => a + b) / list.length).toStringAsFixed(1)} / 5',
              style: context.text.titleSmall,
            ),
            AppSpacing.gapSm,
            for (final f in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(i <= f.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: AppColors.warning),
                          AppSpacing.gapXs,
                          Expanded(
                            child: Text(f.studentName ?? 'Anonymous',
                                style: context.text.labelSmall, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (f.comment != null) ...[AppSpacing.gapXxs, Text(f.comment!, style: context.text.bodyMedium)],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
