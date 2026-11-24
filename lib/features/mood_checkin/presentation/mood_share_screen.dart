import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mood_repository.dart';
import '../domain/mood.dart';

/// Explicit, revocable consent to share a mood SUMMARY (counts only) with a
/// chosen counsellor. Off by default; notes are never shared.
class MoodShareScreen extends ConsumerWidget {
  const MoodShareScreen({super.key});

  Future<void> _grant(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GrantSheet(),
    );
    if (result == null) return;
    try {
      await ref.read(moodRepositoryProvider).grantConsent(
            counsellorId: result.$1,
            periodDays: result.$2,
          );
      ref.invalidate(moodConsentsProvider);
      if (context.mounted) showAppSnack(context, 'Summary sharing turned on.');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, MoodShareConsent c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Stop sharing?',
      message: 'The counsellor will no longer be able to see your mood summary.',
      confirmLabel: 'Stop sharing',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(moodRepositoryProvider).revokeConsent(c.id);
      ref.invalidate(moodConsentsProvider);
      if (context.mounted) showAppSnack(context, 'Sharing stopped.');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consents = ref.watch(moodConsentsProvider);
    final counsellors = ref.watch(counsellorOptionsProvider).value ?? const [];
    String nameFor(String id) =>
        counsellors.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? 'Counsellor';

    return Scaffold(
      appBar: AppBar(title: const Text('Sharing')),
      body: AsyncValueView<List<MoodShareConsent>>(
        value: consents,
        onRetry: () => ref.invalidate(moodConsentsProvider),
        data: (list) {
          final active = list.where((c) => c.isActive).toList();
          final past = list.where((c) => !c.isActive).toList();
          return PageBody(
            children: [
              const InfoBanner(
                title: 'Private by default',
                icon: Icons.lock_outline_rounded,
                message: 'Your check-ins are visible only to you. If you want, you can let '
                    'one counsellor see a summary of how many times you felt each mood. '
                    'Your notes and reasons are never shared. You can stop at any time.',
              ),
              AppSpacing.gapMd,
              AppButton(
                label: 'Share a summary with a counsellor',
                icon: Icons.add_rounded,
                onPressed: () => _grant(context, ref),
              ),
              const SectionHeader(title: 'Currently sharing'),
              if (active.isEmpty)
                Text('You are not sharing anything.', style: context.text.bodyMedium)
              else
                for (final c in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Row(
                        children: [
                          const IconBubble(icon: Icons.visibility_outlined, color: AppColors.success),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nameFor(c.counsellorId), style: context.text.titleSmall),
                                Text(
                                  'Last ${c.periodDays} days · until ${AppDates.day(c.expiresAt)}',
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(onPressed: () => _revoke(context, ref, c), child: const Text('Stop')),
                        ],
                      ),
                    ),
                  ),
              if (past.isNotEmpty) ...[
                const SectionHeader(title: 'Past sharing'),
                for (final c in past.take(10))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_off_outlined),
                    title: Text(nameFor(c.counsellorId)),
                    subtitle: Text(c.revokedAt != null
                        ? 'Stopped ${AppDates.day(c.revokedAt!)}'
                        : 'Ended ${AppDates.day(c.expiresAt)}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GrantSheet extends ConsumerStatefulWidget {
  const _GrantSheet();

  @override
  ConsumerState<_GrantSheet> createState() => _GrantSheetState();
}

class _GrantSheetState extends ConsumerState<_GrantSheet> {
  String? _counsellorId;
  int _period = 30;

  @override
  Widget build(BuildContext context) {
    final counsellors = ref.watch(counsellorOptionsProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: counsellors.when(
          loading: () => const SizedBox(height: 160, child: LoadingView()),
          error: (e, _) => SizedBox(
            height: 260,
            child: ErrorView(error: e, onRetry: () => ref.invalidate(counsellorOptionsProvider)),
          ),
          data: (list) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Share a summary', style: context.text.titleLarge),
              AppSpacing.gapXs,
              Text('Counts per mood only. Never your notes.', style: context.text.bodySmall),
              AppSpacing.gapMd,
              if (list.isEmpty)
                const InfoBanner(message: 'No counsellors are available right now.')
              else
                DropdownButtonFormField<String>(
                  initialValue: _counsellorId,
                  decoration: const InputDecoration(labelText: 'Counsellor'),
                  items: [
                    for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _counsellorId = v),
                ),
              AppSpacing.gapMd,
              Text('Include check-ins from the last', style: context.text.labelMedium),
              AppSpacing.gapXs,
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 14, label: Text('14 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
              AppSpacing.gapSm,
              Text('Sharing ends automatically after 30 days.', style: context.text.bodySmall),
              AppSpacing.gapLg,
              AppButton(
                label: 'Start sharing',
                onPressed: _counsellorId == null
                    ? null
                    : () => Navigator.of(context).pop((_counsellorId!, _period)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
