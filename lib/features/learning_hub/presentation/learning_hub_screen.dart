import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/learning_repository.dart';
import '../domain/learning_resource.dart';
import 'widgets/resource_card.dart';

class LearningHubScreen extends ConsumerStatefulWidget {
  const LearningHubScreen({super.key});

  @override
  ConsumerState<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends ConsumerState<LearningHubScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  ResourceQuery _query = const ResourceQuery();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = ResourceQuery(category: _query.category, search: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final resources = ref.watch(publishedResourcesProvider(_query));
    final recent = ref.watch(recentResourcesProvider).value ?? const [];
    final browsing = _query.category == null && _query.search.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Hub'),
        actions: [
          IconButton(
            tooltip: 'Saved resources',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => context.push(AppRoutes.learnBookmarks),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentResourcesProvider);
          final _ = await ref.refresh(publishedResourcesProvider(_query).future);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search articles, videos and FAQs',
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
                  AppSpacing.gapSm,
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('All topics'),
                          selected: _query.category == null,
                          onSelected: (_) => setState(() => _query = ResourceQuery(search: _query.search)),
                        ),
                        for (final c in ResourceCategory.values)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: ChoiceChip(
                              avatar: Icon(c.icon, size: 18),
                              label: Text(c.label),
                              selected: _query.category == c,
                              onSelected: (_) => setState(() => _query = ResourceQuery(category: c, search: _query.search)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (browsing && recent.isNotEmpty) ...[
                    const SectionHeader(title: 'Recently viewed'),
                    SizedBox(
                      height: 210,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recent.length,
                        separatorBuilder: (_, _) => AppSpacing.gapSm,
                        itemBuilder: (_, i) => SizedBox(width: 180, child: ResourceCard(resource: recent[i], compact: true)),
                      ),
                    ),
                  ],
                  if (browsing) ...[
                    const SectionHeader(title: 'Explore topics'),
                    ResponsiveGrid(
                      minTileWidth: 150,
                      children: [
                        for (final c in ResourceCategory.values)
                          FeatureCard(
                            icon: c.icon,
                            title: c.label,
                            tint: c.color.withValues(alpha: 0.14),
                            iconColor: c.color,
                            onTap: () => setState(() => _query = ResourceQuery(category: c)),
                          ),
                      ],
                    ),
                  ],
                  SectionHeader(
                    title: _query.search.isNotEmpty
                        ? 'Results'
                        : (_query.category?.label ?? 'Latest resources'),
                  ),
                  resources.when(
                    loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
                    error: (e, _) => SizedBox(
                      height: 320,
                      child: ErrorView(error: e, onRetry: () => ref.invalidate(publishedResourcesProvider(_query))),
                    ),
                    data: (list) => list.isEmpty
                        ? const SizedBox(
                            height: 260,
                            child: EmptyView(
                              title: 'Nothing here yet',
                              message: 'New resources from the Counselling Unit will appear here.',
                              icon: Icons.auto_stories_outlined,
                            ),
                          )
                        : ResponsiveGrid(
                            minTileWidth: 260,
                            children: [for (final r in list) ResourceCard(resource: r)],
                          ),
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
