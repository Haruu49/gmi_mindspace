import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/widgets.dart';
import '../data/journal_repository.dart';
import '../domain/journal_entry.dart';

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  JournalQuery _query = const JournalQuery();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = JournalQuery(search: v, gratitudeOnly: _query.gratitudeOnly));
    });
  }

  void _write({String? prompt, bool gratitude = false}) {
    final params = <String, String>{
      'prompt': ?prompt,
      if (gratitude) 'gratitude': '1',
    };
    context.push(Uri(path: AppRoutes.journalNew, queryParameters: params.isEmpty ? null : params).toString());
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalEntriesProvider(_query));
    final todayPrompt = JournalPrompts.forToday();
    return Scaffold(
      appBar: AppBar(title: const Text('My Journal')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('journal_new'),
        onPressed: () => _write(),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New entry'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(journalEntriesProvider(_query).future),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: AppSpacing.page,
              sliver: SliverToBoxAdapter(
                child: ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.primaryContainer,
                            context.colors.secondaryContainer,
                          ],
                        ),
                        onTap: () => _write(prompt: todayPrompt),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Today\'s reflection', style: context.text.labelMedium),
                            AppSpacing.gapXxs,
                            Text(todayPrompt, style: context.text.titleMedium),
                            AppSpacing.gapXs,
                            Text('Tap to write', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      AppSpacing.gapSm,
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.favorite_rounded, size: 18),
                              label: const Text('Gratitude entry'),
                              onPressed: () => _write(prompt: 'What are you grateful for?', gratitude: true),
                            ),
                            for (final p in JournalPrompts.reflection.where((p) => p != todayPrompt))
                              Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.xs),
                                child: ActionChip(label: Text(p), onPressed: () => _write(prompt: p)),
                              ),
                          ],
                        ),
                      ),
                      AppSpacing.gapMd,
                      TextField(
                        key: const Key('journal_search'),
                        controller: _search,
                        onChanged: _onSearch,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search your entries',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    _onSearch('');
                                  },
                                ),
                        ),
                      ),
                      AppSpacing.gapXs,
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Gratitude only'),
                            selected: _query.gratitudeOnly,
                            onSelected: (v) => setState(
                              () => _query = JournalQuery(search: _query.search, gratitudeOnly: v),
                            ),
                          ),
                          AppSpacing.gapXs,
                          const Spacer(),
                          Icon(Icons.lock_outline_rounded, size: 16, color: context.colors.onSurfaceVariant),
                          AppSpacing.gapXxs,
                          Flexible(
                            flex: 3,
                            child: Text('Only you can read these',
                                style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      AppSpacing.gapSm,
                    ],
                  ),
                ),
              ),
            ),
            entries.when(
              loading: () => const SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(error: e, onRetry: () => ref.invalidate(journalEntriesProvider(_query))),
              ),
              data: (list) => list.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        title: _query.search.isEmpty ? 'Your journal is empty' : 'No matching entries',
                        message: _query.search.isEmpty
                            ? 'Write your first entry – it is completely private.'
                            : 'Try a different word.',
                        icon: Icons.menu_book_rounded,
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageGutter, 0, AppSpacing.pageGutter, 96,
                      ),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => AppSpacing.gapSm,
                        itemBuilder: (_, i) => ResponsiveCenter(child: JournalCard(entry: list[i])),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class JournalCard extends StatelessWidget {
  const JournalCard({super.key, required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.journalDetail(entry.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: entry.isGratitude ? context.colors.secondaryContainer : context.colors.primaryContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Column(
              children: [
                Text('${entry.entryDate.day}', style: context.text.titleLarge),
                Text(AppDates.short(entry.entryDate).split(' ').last, style: context.text.labelSmall),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (entry.isGratitude)
                      Icon(Icons.favorite_rounded, size: 16, color: context.colors.secondary),
                  ],
                ),
                AppSpacing.gapXxs,
                Text(
                  entry.content,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
