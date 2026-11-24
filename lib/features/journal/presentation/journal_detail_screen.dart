import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/journal_repository.dart';
import '../domain/journal_entry.dart';

class JournalDetailScreen extends ConsumerWidget {
  const JournalDetailScreen({super.key, required this.entryId});

  final String entryId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this entry?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(journalRepositoryProvider).delete(entryId);
      ref.invalidate(journalEntriesProvider);
      if (!context.mounted) return;
      showAppSnack(context, 'Entry deleted.');
      context.pop();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(journalEntryProvider(entryId));
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: entry.hasValue ? () => context.push(AppRoutes.journalEdit(entryId)) : null,
          ),
          IconButton(
            key: const Key('journal_delete'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: entry.hasValue ? () => _delete(context, ref) : null,
          ),
        ],
      ),
      body: AsyncValueView<JournalEntry>(
        value: entry,
        onRetry: () => ref.invalidate(journalEntryProvider(entryId)),
        data: (e) => PageBody(
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                StatusChip(label: AppDates.day(e.entryDate), color: context.colors.primary, icon: Icons.calendar_today_rounded),
                if (e.isGratitude)
                  const StatusChip(label: 'Gratitude', color: AppColors.sageDeep, icon: Icons.favorite_rounded),
              ],
            ),
            AppSpacing.gapMd,
            Text(e.title, style: context.text.headlineSmall),
            if (e.prompt != null) ...[
              AppSpacing.gapSm,
              Text('“${e.prompt}”', style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
            AppSpacing.gapMd,
            SelectableText(e.content, style: context.text.bodyLarge),
            AppSpacing.gapLg,
            Text(
              e.wasEdited ? 'Edited ${AppDates.relative(e.updatedAt)}' : 'Written ${AppDates.relative(e.createdAt)}',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
