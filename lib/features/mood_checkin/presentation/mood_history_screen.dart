import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/mood_repository.dart';
import '../domain/mood.dart';

class MoodHistoryScreen extends ConsumerWidget {
  const MoodHistoryScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, MoodEntry e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this check-in?',
      message: 'This permanently removes the check-in and its note.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(moodRepositoryProvider).deleteEntry(e.id);
      ref.invalidate(moodEntriesProvider);
      if (context.mounted) showAppSnack(context, 'Check-in deleted.');
    } catch (err) {
      if (context.mounted) showErrorSnack(context, err);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(moodEntriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood history'),
        actions: [
          IconButton(
            tooltip: 'Charts',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push(AppRoutes.moodAnalytics),
          ),
        ],
      ),
      body: AsyncValueView<List<MoodEntry>>(
        value: entries,
        onRetry: () => ref.invalidate(moodEntriesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyView(
          title: 'No check-ins yet',
          message: 'Your mood check-ins from the last 90 days will appear here.',
          icon: Icons.mood_rounded,
          actionLabel: 'Check in now',
          onAction: () => context.go(AppRoutes.mood),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(moodEntriesProvider.future),
          child: ListView.separated(
            padding: AppSpacing.page,
            itemCount: list.length,
            separatorBuilder: (_, _) => AppSpacing.gapSm,
            itemBuilder: (context, i) {
              final e = list[i];
              final showDay = i == 0 ||
                  !AppDates.isSameDay(list[i - 1].createdAt.toLocal(), e.createdAt.toLocal());
              return ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDay)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
                        child: Text(AppDates.day(e.createdAt), style: context.text.labelMedium),
                      ),
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.mood.emoji, style: const TextStyle(fontSize: 32)),
                          AppSpacing.gapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(e.mood.label, style: context.text.titleSmall),
                                    AppSpacing.gapXs,
                                    Text(AppDates.time(e.createdAt), style: context.text.bodySmall),
                                  ],
                                ),
                                if (e.reason != null) ...[
                                  AppSpacing.gapXxs,
                                  StatusChip(label: e.reason!.label, color: e.mood.color, icon: e.reason!.icon),
                                ],
                                if (e.notes != null) ...[
                                  AppSpacing.gapXs,
                                  Text(e.notes!, style: context.text.bodyMedium),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete check-in',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _delete(context, ref, e),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
