import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../../counselling/data/counselling_repository.dart';
import '../../counselling/domain/appointment.dart';

/// Counsellor availability. Overlapping slots are rejected by the database.
class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddSlotSheet(),
    );
    if (added == true) ref.invalidate(myAvailabilityProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(myAvailabilityProvider);
    final repo = ref.read(counsellingRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My availability')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add slot'),
      ),
      body: AsyncValueView<List<AvailabilitySlot>>(
        value: slots,
        onRetry: () => ref.invalidate(myAvailabilityProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyView(
          title: 'No upcoming slots',
          message: 'Add times when students can request appointments with you.',
          icon: Icons.schedule_rounded,
          actionLabel: 'Add slot',
          onAction: () => _add(context, ref),
        ),
        data: (list) => ListView.separated(
          padding: AppSpacing.page.copyWith(bottom: 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => AppSpacing.gapSm,
          itemBuilder: (context, i) {
            final s = list[i];
            return ResponsiveCenter(
              child: AppCard(
                child: Row(
                  children: [
                    IconBubble(
                      icon: s.isActive ? Icons.event_available_rounded : Icons.event_busy_rounded,
                      color: s.isActive ? AppColors.success : AppColors.slate,
                    ),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppDates.day(s.startsAt), style: context.text.titleSmall),
                          Text('${AppDates.time(s.startsAt)} – ${AppDates.time(s.endsAt)}'
                              '${s.location == null ? '' : ' · ${s.location}'}', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.isActive,
                      onChanged: (v) async {
                        try {
                          await repo.setAvailabilityActive(s.id, v);
                          ref.invalidate(myAvailabilityProvider);
                        } catch (e) {
                          if (context.mounted) showErrorSnack(context, e);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete slot',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok = await showConfirmDialog(context,
                            title: 'Delete this slot?',
                            message: 'Existing appointments stay in place; the slot will no longer be offered.',
                            confirmLabel: 'Delete',
                            destructive: true);
                        if (!ok) return;
                        try {
                          await repo.deleteAvailability(s.id);
                          ref.invalidate(myAvailabilityProvider);
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
    );
  }
}

class _AddSlotSheet extends ConsumerStatefulWidget {
  const _AddSlotSheet();

  @override
  ConsumerState<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends ConsumerState<_AddSlotSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  int _minutes = 60;
  final _location = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  DateTime get _start => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _save() async {
    if (!_start.isAfter(DateTime.now())) {
      showAppSnack(context, 'Please choose a time in the future.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(counsellingRepositoryProvider).addAvailability(
            startsAt: _start,
            endsAt: _start.add(Duration(minutes: _minutes)),
            location: _location.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New availability slot', style: context.text.titleLarge),
            AppSpacing.gapMd,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(AppDates.short(_date)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 120)),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                AppSpacing.gapSm,
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_time.format(context)),
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _time);
                      if (t != null) setState(() => _time = t);
                    },
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
            Text('Length', style: context.text.labelMedium),
            AppSpacing.gapXs,
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30m')),
                ButtonSegment(value: 45, label: Text('45m')),
                ButtonSegment(value: 60, label: Text('1h')),
                ButtonSegment(value: 90, label: Text('1.5h')),
              ],
              selected: {_minutes},
              onSelectionChanged: (s) => setState(() => _minutes = s.first),
            ),
            AppSpacing.gapMd,
            AppTextField(controller: _location, label: 'Location (optional)', maxLength: 120),
            AppSpacing.gapMd,
            AppButton(label: 'Add slot', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
